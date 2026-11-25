import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../utils/postgrest_utils.dart';

class GameGroupRepository {
  GameGroupRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, Future<void>> _sortOrderLocks = {};

  Future<T> _runSerialized<T>(String key, Future<T> Function() action) {
    final previous = _sortOrderLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    final nextChain = previous.catchError((_) {}).then((_) => completer.future);
    _sortOrderLocks[key] = nextChain;

    return previous.catchError((_) {}).then((_) async {
      try {
        return await action();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (identical(_sortOrderLocks[key], nextChain)) {
          _sortOrderLocks.remove(key);
        }
      }
    });
  }

  /// Lista grupos del usuario con hasta 4 juegos de vista previa.
  Future<List<GameGroup>> fetchGroups(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return [];

    final res = await _client
        .from('game_groups')
        .select(
          '$kGameGroupColumns, '
          'game_group_items(id, group_id, game_id, sort_order)',
        )
        .eq('user_id', trimmedUserId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true)
        .limit(200);

    final rawGroups = <Map<String, dynamic>>[];
    final previewGameIds = <int>{};

    for (final row in (res as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final rawItems = (map['game_group_items'] is List
              ? (map['game_group_items'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[])
        ..sort(
          (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
            (b['sort_order'] as num?) ?? 0,
          ),
        );

      final totalCount = rawItems.length;
      final preview = rawItems.take(4).toList();
      for (final item in preview) {
        final gid = (item['game_id'] as num?)?.toInt();
        if (gid != null) previewGameIds.add(gid);
      }
      final coverGid = (map['cover_game_id'] as num?)?.toInt();
      if (coverGid != null) previewGameIds.add(coverGid);

      map['game_group_items'] = preview;
      map['game_count'] = totalCount;
      rawGroups.add(map);
    }

    final gamesById = <int, Map<String, dynamic>>{};
    if (previewGameIds.isNotEmpty) {
      final gamesRes = await _client
          .from('games')
          .select('igdb_id, title, cover_url')
          .inFilter('igdb_id', previewGameIds.toList());
      for (final g in (gamesRes as List).whereType<Map>()) {
        final gid = (g['igdb_id'] as num?)?.toInt();
        if (gid != null) {
          gamesById[gid] = Map<String, dynamic>.from(g);
        }
      }
    }

    return rawGroups.map((map) {
      final previewItems = map['game_group_items'] as List<Map<String, dynamic>>;
      for (final item in previewItems) {
        final gid = (item['game_id'] as num?)?.toInt();
        if (gid != null && gamesById.containsKey(gid)) {
          item['games'] = gamesById[gid];
        }
      }
      return GameGroup.fromMap(map);
    }).toList();
  }

  /// Detalle de un grupo con todos los juegos y estado de biblioteca.
  Future<GameGroup?> fetchGroupDetail(String groupId, String userId) async {
    final trimmedGroupId = groupId.trim();
    final trimmedUserId = userId.trim();
    if (trimmedGroupId.isEmpty || trimmedUserId.isEmpty) return null;

    final results = await Future.wait<dynamic>([
      _client
          .from('game_groups')
          .select(kGameGroupColumns)
          .eq('id', trimmedGroupId)
          .eq('user_id', trimmedUserId)
          .maybeSingle(),
      _client
          .from('game_group_items')
          .select('$kGameGroupItemColumns, games($kGameCardColumns)')
          .eq('group_id', trimmedGroupId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true)
          .limit(500),
    ]);

    final groupRes = results[0];
    if (groupRes == null || groupRes is! Map) return null;

    final itemsRes = results[1] as List;
    final items = itemsRes
        .whereType<Map>()
        .map((e) => GameGroupItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final statuses = await _fetchLibraryStatuses(
      trimmedUserId,
      items.map((i) => i.gameId).toList(),
    );

    final enrichedItems = items
        .map(
          (item) => item.copyWith(libraryStatus: statuses[item.gameId]),
        )
        .toList();

    final map = Map<String, dynamic>.from(groupRes);
    return GameGroup.fromMap(map).copyWith(
      items: enrichedItems,
      gameCount: enrichedItems.length,
    );
  }

  Future<Map<int, GameStatus>> _fetchLibraryStatuses(
    String userId,
    List<int> gameIds,
  ) async {
    if (gameIds.isEmpty) return {};

    final res = await _client
        .from('user_games')
        .select('game_id, status')
        .eq('user_id', userId)
        .inFilter('game_id', gameIds);

    final map = <int, GameStatus>{};
    for (final row in (res as List).whereType<Map>()) {
      final gameId = (row['game_id'] as num?)?.toInt();
      if (gameId != null) {
        map[gameId] = GameStatus.fromStringOrDefault(row['status'] as String?);
      }
    }
    return map;
  }

  Future<GameGroup> createGroup({
    required String userId,
    required String name,
    String? description,
    bool isRanked = false,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Usuario no válido');
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'El nombre de la colección no puede estar vacío',
      );
    }
    if (trimmedName.length > 100) {
      throw ArgumentError.value(
        name,
        'name',
        'El nombre de la colección no puede superar los 100 caracteres',
      );
    }
    requireAuthenticatedUserId(_client, expectedUserId: trimmedUserId);

    return _runSerialized('group:$trimmedUserId', () async {
      final maxSort = await _nextGroupSortOrder(trimmedUserId);

      final payload = <String, dynamic>{
        'user_id': trimmedUserId,
        'name': trimmedName,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'sort_order': maxSort,
        'is_ranked': isRanked,
      };

      try {
        final inserted = await _client
            .from('game_groups')
            .insert(payload)
            .select(kGameGroupColumns)
            .single();
        return GameGroup.fromMap(Map<String, dynamic>.from(inserted as Map));
      } catch (e) {
        // Si la columna is_ranked aún no existe en la BD, codificamos el estado en description.
        if (e.toString().contains('is_ranked')) {
          payload.remove('is_ranked');
          final encodedDesc = GameGroup.encodeRankedDescription(
            description,
            isRanked,
          );
          if (encodedDesc != null) {
            payload['description'] = encodedDesc;
          } else {
            payload.remove('description');
          }
          final inserted = await _client
              .from('game_groups')
              .insert(payload)
              .select()
              .single();
          return GameGroup.fromMap(Map<String, dynamic>.from(inserted as Map));
        }
        rethrow;
      }
    });
  }

  Future<int> _nextGroupSortOrder(String userId) async {
    final res = await _client
        .from('game_groups')
        .select('sort_order')
        .eq('user_id', userId)
        .order('sort_order', ascending: false, nullsFirst: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return 0;
    final sort = (res as Map)['sort_order'] as num?;
    return sort == null ? 0 : sort.toInt() + 1;
  }

  Future<GameGroup> updateGroup({
    required String groupId,
    String? name,
    String? description,
    int? coverGameId,
    bool clearCover = false,
    bool? isRanked,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Colección no válida');
    }
    requireAuthenticatedUserId(_client);

    final updates = <String, dynamic>{};
    if (name != null) {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw ArgumentError.value(
          name,
          'name',
          'El nombre de la colección no puede estar vacío',
        );
      }
      if (trimmedName.length > 100) {
        throw ArgumentError.value(
          name,
          'name',
          'El nombre de la colección no puede superar los 100 caracteres',
        );
      }
      updates['name'] = trimmedName;
    }
    if (description != null) {
      final trimmed = description.trim();
      updates['description'] = trimmed.isEmpty ? null : trimmed;
    }
    if (clearCover) {
      updates['cover_game_id'] = null;
    } else if (coverGameId != null) {
      updates['cover_game_id'] = coverGameId;
    }
    if (isRanked != null) updates['is_ranked'] = isRanked;

    if (updates.isEmpty) {
      final existing = await _client
          .from('game_groups')
          .select(kGameGroupColumns)
          .eq('id', trimmedGroupId)
          .single();
      return GameGroup.fromMap(Map<String, dynamic>.from(existing as Map));
    }

    try {
      final res = await _client
          .from('game_groups')
          .update(updates)
          .eq('id', trimmedGroupId)
          .select(kGameGroupColumns)
          .single();

      return GameGroup.fromMap(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      if (e.toString().contains('is_ranked') && updates.containsKey('is_ranked')) {
        updates.remove('is_ranked');
        if (isRanked != null) {
          String? baseDescription = description;
          if (baseDescription == null) {
            final current = await _client
                .from('game_groups')
                .select('description')
                .eq('id', trimmedGroupId)
                .maybeSingle();
            if (current != null) {
              baseDescription = GameGroup.decodeRankedDescription(
                (current as Map)['description']?.toString(),
              ).description;
            }
          }
          updates['description'] = GameGroup.encodeRankedDescription(
            baseDescription,
            isRanked,
          );
        }
        final res = await _client
            .from('game_groups')
            .update(updates)
            .eq('id', trimmedGroupId)
            .select()
            .single();
        return GameGroup.fromMap(Map<String, dynamic>.from(res as Map));
      }
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    requireAuthenticatedUserId(_client);
    await _client.from('game_groups').delete().eq('id', groupId);
  }

  Future<void> reorderGroups(List<String> orderedGroupIds) async {
    requireAuthenticatedUserId(_client);
    const batchSize = 10;
    for (var start = 0; start < orderedGroupIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, orderedGroupIds.length);
      await Future.wait([
        for (var i = start; i < end; i++)
          _client
              .from('game_groups')
              .update({'sort_order': i})
              .eq('id', orderedGroupIds[i]),
      ]);
    }
  }

  /// Asegura que el juego exista en catálogo antes de añadirlo al grupo.
  Future<void> ensureGameInCatalog(Game game) async {
    try {
      await _client.from('games').upsert(
        {
          'igdb_id': game.igdbId,
          'title': game.title,
          if (game.coverUrl != null) 'cover_url': game.coverUrl,
          if (game.releaseDate != null) 'release_date': game.releaseDate,
        },
        onConflict: 'igdb_id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('[GameGroupRepository] ensureGameInCatalog: $e');
      rethrow;
    }
  }

  Future<GameGroupItem> addGameToGroup({
    required String groupId,
    required Game game,
    String? note,
  }) async {
    final trimmedGroupId = groupId.trim();
    if (trimmedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Colección no válida');
    }
    if (game.igdbId <= 0) {
      throw ArgumentError.value(game.igdbId, 'game.igdbId', 'Juego no válido');
    }
    requireAuthenticatedUserId(_client);
    final trimmedNote = note?.trim();

    await ensureGameInCatalog(game);

    return _runSerialized('item:$trimmedGroupId', () async {
      final nextSort = await _nextItemSortOrder(trimmedGroupId);

      try {
        final inserted = await _client
            .from('game_group_items')
            .insert({
              'group_id': trimmedGroupId,
              'game_id': game.igdbId,
              'sort_order': nextSort,
              if (trimmedNote != null && trimmedNote.isNotEmpty)
                'note': trimmedNote,
            })
            .select('$kGameGroupItemColumns, games($kGameCardColumns)')
            .single();

        return GameGroupItem.fromMap(
          Map<String, dynamic>.from(inserted as Map),
        );
      } catch (e) {
        debugPrint('[GameGroupRepository] addGameToGroup: $e');
        rethrow;
      }
    });
  }

  Future<int> _nextItemSortOrder(String groupId) async {
    final res = await _client
        .from('game_group_items')
        .select('sort_order')
        .eq('group_id', groupId)
        .order('sort_order', ascending: false, nullsFirst: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return 0;
    final sort = (res as Map)['sort_order'] as num?;
    return sort == null ? 0 : sort.toInt() + 1;
  }

  Future<void> removeGameFromGroup(String itemId) async {
    requireAuthenticatedUserId(_client);
    await _client.from('game_group_items').delete().eq('id', itemId);
  }

  Future<void> reorderItems(String groupId, List<String> orderedItemIds) async {
    requireAuthenticatedUserId(_client);
    const batchSize = 10;
    for (var start = 0; start < orderedItemIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, orderedItemIds.length);
      await Future.wait([
        for (var i = start; i < end; i++)
          _client
              .from('game_group_items')
              .update({'sort_order': i})
              .eq('id', orderedItemIds[i])
              .eq('group_id', groupId),
      ]);
    }
  }

  Future<void> updateItemNote(String itemId, String? note) async {
    requireAuthenticatedUserId(_client);
    final trimmedId = itemId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'Elemento no válido');
    }
    final trimmedNote = note?.trim();
    await _client
        .from('game_group_items')
        .update({
          'note': (trimmedNote == null || trimmedNote.isEmpty)
              ? null
              : trimmedNote,
        })
        .eq('id', trimmedId);
  }
}
