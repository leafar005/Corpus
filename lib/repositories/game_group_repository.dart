import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class GameGroupRepository {
  GameGroupRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Lista grupos del usuario con hasta 4 juegos de vista previa.
  Future<List<GameGroup>> fetchGroups(String userId) async {
    final res = await _client
        .from('game_groups')
        .select(
          '*, game_group_items(id, group_id, game_id, sort_order, games(*))',
        )
        .eq('user_id', userId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (res as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final rawItems = (map['game_group_items'] as List? ?? [])
        ..sort(
          (a, b) => ((a as Map)['sort_order'] as num? ?? 0).compareTo(
            (b as Map)['sort_order'] as num? ?? 0,
          ),
        );
      final totalCount = rawItems.length;
      map['game_group_items'] = rawItems.take(4).toList();
      map['game_count'] = totalCount;
      return GameGroup.fromMap(map);
    }).toList();
  }

  /// Detalle de un grupo con todos los juegos y estado de biblioteca.
  Future<GameGroup?> fetchGroupDetail(String groupId, String userId) async {
    final groupRes = await _client
        .from('game_groups')
        .select()
        .eq('id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (groupRes == null) return null;

    final itemsRes = await _client
        .from('game_group_items')
        .select('*, games(*)')
        .eq('group_id', groupId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final items = (itemsRes as List)
        .map((e) => GameGroupItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final statuses = await _fetchLibraryStatuses(
      userId,
      items.map((i) => i.gameId).toList(),
    );

    final enrichedItems = items
        .map(
          (item) => item.copyWith(libraryStatus: statuses[item.gameId]),
        )
        .toList();

    final map = Map<String, dynamic>.from(groupRes as Map);
    return GameGroup(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverGameId: (map['cover_game_id'] as num?)?.toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
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
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final gameId = (m['game_id'] as num).toInt();
      map[gameId] = GameStatus.fromStringOrDefault(m['status'] as String?);
    }
    return map;
  }

  Future<GameGroup> createGroup({
    required String userId,
    required String name,
    String? description,
  }) async {
    final maxSort = await _nextGroupSortOrder(userId);
    final inserted = await _client
        .from('game_groups')
        .insert({
          'user_id': userId,
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'sort_order': maxSort,
        })
        .select()
        .single();

    return GameGroup.fromMap(Map<String, dynamic>.from(inserted as Map));
  }

  Future<int> _nextGroupSortOrder(String userId) async {
    final res = await _client
        .from('game_groups')
        .select('sort_order')
        .eq('user_id', userId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return 0;
    final sort = (res as Map)['sort_order'] as num?;
    return (sort?.toInt() ?? 0) + 1;
  }

  Future<GameGroup> updateGroup({
    required String groupId,
    String? name,
    String? description,
    int? coverGameId,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (description != null) updates['description'] = description.trim();
    if (coverGameId != null) updates['cover_game_id'] = coverGameId;

    final res = await _client
        .from('game_groups')
        .update(updates)
        .eq('id', groupId)
        .select()
        .single();

    return GameGroup.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('game_groups').delete().eq('id', groupId);
  }

  Future<void> reorderGroups(List<String> orderedGroupIds) async {
    for (var i = 0; i < orderedGroupIds.length; i++) {
      await _client
          .from('game_groups')
          .update({'sort_order': i})
          .eq('id', orderedGroupIds[i]);
    }
  }

  /// Asegura que el juego exista en catálogo antes de añadirlo al grupo.
  Future<void> ensureGameInCatalog(Game game) async {
    try {
      await _client.from('games').upsert({
        'igdb_id': game.igdbId,
        'title': game.title,
        if (game.coverUrl != null) 'cover_url': game.coverUrl,
        if (game.releaseDate != null) 'release_date': game.releaseDate,
      });
    } catch (e) {
      debugPrint('[GameGroupRepository] ensureGameInCatalog: $e');
    }
  }

  Future<GameGroupItem> addGameToGroup({
    required String groupId,
    required Game game,
    String? note,
  }) async {
    await ensureGameInCatalog(game);

    final nextSort = await _nextItemSortOrder(groupId);

    try {
      final inserted = await _client
          .from('game_group_items')
          .insert({
            'group_id': groupId,
            'game_id': game.igdbId,
            'sort_order': nextSort,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .select('*, games(*)')
          .single();

      return GameGroupItem.fromMap(
        Map<String, dynamic>.from(inserted as Map),
      );
    } catch (e) {
      debugPrint('[GameGroupRepository] addGameToGroup: $e');
      rethrow;
    }
  }

  Future<int> _nextItemSortOrder(String groupId) async {
    final res = await _client
        .from('game_group_items')
        .select('sort_order')
        .eq('group_id', groupId)
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return 0;
    final sort = (res as Map)['sort_order'] as num?;
    return (sort?.toInt() ?? 0) + 1;
  }

  Future<void> removeGameFromGroup(String itemId) async {
    await _client.from('game_group_items').delete().eq('id', itemId);
  }

  Future<void> reorderItems(String groupId, List<String> orderedItemIds) async {
    for (var i = 0; i < orderedItemIds.length; i++) {
      await _client
          .from('game_group_items')
          .update({'sort_order': i})
          .eq('id', orderedItemIds[i])
          .eq('group_id', groupId);
    }
  }

  Future<void> updateItemNote(String itemId, String? note) async {
    await _client
        .from('game_group_items')
        .update({'note': note?.trim().isEmpty == true ? null : note?.trim()})
        .eq('id', itemId);
  }
}
