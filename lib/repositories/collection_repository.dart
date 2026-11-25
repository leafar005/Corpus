import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/postgrest_utils.dart';
import '../utils/shelf_platforms.dart';

/// Un juego en la estantería con la plataforma concreta de esa "caja".
@immutable
class ShelfItem {
  const ShelfItem({
    required this.game,
    required this.platformName,
  });

  final Game game;
  final String platformName;
}

/// Juego de biblioteca disponible para añadir a la estantería.
@immutable
class LibraryGameOption {
  const LibraryGameOption({
    required this.game,
    this.ownedPlatforms = const [],
    this.suggestedPlatforms = const [],
    this.steamOwned = false,
  });

  final Game game;
  final List<String> ownedPlatforms;
  final List<String> suggestedPlatforms;
  final bool steamOwned;
}

class CollectionRepository {
  CollectionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, Future<void>> _platformWriteLocks = {};

  Future<T> _runSerialized<T>(String key, Future<T> Function() action) {
    final previous = _platformWriteLocks[key] ?? Future<void>.value();
    final completer = Completer<void>();
    final nextChain = previous.catchError((_) {}).then((_) => completer.future);
    _platformWriteLocks[key] = nextChain;

    return previous.catchError((_) {}).then((_) async {
      try {
        return await action();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (identical(_platformWriteLocks[key], nextChain)) {
          _platformWriteLocks.remove(key);
        }
      }
    });
  }

  /// Devuelve una caja por cada (juego, plataforma) del usuario.
  Future<List<ShelfItem>> fetchShelfGames(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return [];

    final rows = await _client
        .from('user_game_platforms')
        .select('platform_name, games($kGameCardColumns)')
        .eq('user_id', trimmedUserId)
        .order('created_at', ascending: false)
        .limit(5000);

    final items = <ShelfItem>[];
    for (final row in (rows as List).whereType<Map>()) {
      final gameData = row['games'];
      if (gameData is! Map) continue;
      items.add(
        ShelfItem(
          game: Game.fromMap(Map<String, dynamic>.from(gameData)),
          platformName: row['platform_name'] as String? ?? '',
        ),
      );
    }
    return items;
  }

  Future<List<String>> fetchOwnedPlatforms(String userId, int gameId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty || gameId <= 0) return [];

    final rows = await _client
        .from('user_game_platforms')
        .select('platform_name')
        .eq('user_id', trimmedUserId)
        .eq('game_id', gameId)
        .limit(200);

    return (rows as List)
        .whereType<Map>()
        .map((r) => r['platform_name']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Consulta puntual para sugerir plataformas de un solo juego sin descargar toda la biblioteca.
  Future<({List<String> igdbPlatforms, List<String> suggestedPlatforms})>
      fetchPlatformSuggestionsForGame({
    required String userId,
    required int gameId,
    required List<String> alreadyOwned,
    List<String> knownGamePlatforms = const [],
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty || gameId <= 0) {
      return (igdbPlatforms: knownGamePlatforms, suggestedPlatforms: const <String>[]);
    }

    final results = await Future.wait<dynamic>([
      if (knownGamePlatforms.isEmpty)
        _client
            .from('games')
            .select('platforms')
            .eq('igdb_id', gameId)
            .maybeSingle()
      else
        Future<Map<String, dynamic>?>.value(null),
      _client
          .from('user_games')
          .select('steam_owned')
          .eq('user_id', trimmedUserId)
          .eq('game_id', gameId)
          .maybeSingle(),
      _client
          .from('reviews')
          .select('platform')
          .eq('user_id', trimmedUserId)
          .eq('game_id', gameId)
          .not('platform', 'is', null)
          .order('created_at', ascending: false)
          .limit(20),
    ]);

    var igdbPlatforms = knownGamePlatforms;
    final gameRow = results[0];
    if (igdbPlatforms.isEmpty && gameRow is Map && gameRow['platforms'] != null) {
      igdbPlatforms = Game.fromMap({
        'igdb_id': gameId,
        'title': '',
        'platforms': gameRow['platforms'],
      }).platforms;
    }

    final ugRow = results[1];
    final steamOwned = ugRow is Map && ugRow['steam_owned'] == true;

    String? reviewPlatform;
    final revRows = results[2];
    if (revRows is List && revRows.isNotEmpty && revRows.first is Map) {
      reviewPlatform = (revRows.first as Map)['platform']?.toString();
    }

    final suggested = ShelfPlatforms.suggest(
      reviewPlatform: reviewPlatform,
      steamOwned: steamOwned,
      alreadyOwned: ShelfPlatforms.normalizeIds(alreadyOwned),
    );
    return (igdbPlatforms: igdbPlatforms, suggestedPlatforms: suggested);
  }

  Future<void> addPlatform({
    required String userId,
    required int gameId,
    required String platformName,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedPlatform = platformName.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Usuario no válido');
    }
    if (gameId <= 0) {
      throw ArgumentError.value(gameId, 'gameId', 'Juego no válido');
    }
    if (trimmedPlatform.isEmpty) {
      throw ArgumentError.value(
        platformName,
        'platformName',
        'La plataforma no puede estar vacía',
      );
    }
    requireAuthenticatedUserId(_client, expectedUserId: trimmedUserId);

    await _client.from('user_game_platforms').upsert({
      'user_id': trimmedUserId,
      'game_id': gameId,
      'platform_name': trimmedPlatform,
    });
  }

  Future<void> removePlatform({
    required String userId,
    required int gameId,
    required String platformName,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedPlatform = platformName.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Usuario no válido');
    }
    if (gameId <= 0) {
      throw ArgumentError.value(gameId, 'gameId', 'Juego no válido');
    }
    if (trimmedPlatform.isEmpty) {
      throw ArgumentError.value(
        platformName,
        'platformName',
        'La plataforma no puede estar vacía',
      );
    }
    requireAuthenticatedUserId(_client, expectedUserId: trimmedUserId);

    await _client
        .from('user_game_platforms')
        .delete()
        .eq('user_id', trimmedUserId)
        .eq('game_id', gameId)
        .eq('platform_name', trimmedPlatform);
  }

  /// Sincroniza las plataformas seleccionadas: añade las nuevas y elimina las desmarcadas
  /// en lote (con exclusión mutua por `(userId, gameId)`).
  Future<void> setPlatformsForGame({
    required String userId,
    required int gameId,
    required List<String> selectedPlatforms,
    List<String>? currentOwnedPlatforms,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Usuario no válido');
    }
    if (gameId <= 0) {
      throw ArgumentError.value(gameId, 'gameId', 'Juego no válido');
    }
    final normalizedSelected = <String>{};
    for (final raw in selectedPlatforms) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError.value(
          selectedPlatforms,
          'selectedPlatforms',
          'Las plataformas no pueden estar vacías',
        );
      }
      normalizedSelected.add(trimmed);
    }
    requireAuthenticatedUserId(_client, expectedUserId: trimmedUserId);

    await _runSerialized('$trimmedUserId:$gameId', () async {
      final current =
          currentOwnedPlatforms ?? await fetchOwnedPlatforms(trimmedUserId, gameId);
      final currentSet = current.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

      final toAdd = normalizedSelected.difference(currentSet);
      final toRemove = currentSet.difference(normalizedSelected);
      if (toAdd.isEmpty && toRemove.isEmpty) return;

      await Future.wait([
        if (toAdd.isNotEmpty)
          _client.from('user_game_platforms').upsert([
            for (final platform in toAdd)
              {
                'user_id': trimmedUserId,
                'game_id': gameId,
                'platform_name': platform,
              },
          ]),
        if (toRemove.isNotEmpty)
          _client
              .from('user_game_platforms')
              .delete()
              .eq('user_id', trimmedUserId)
              .eq('game_id', gameId)
              .inFilter('platform_name', toRemove.toList()),
      ]);
    });
  }

  /// Añade la misma plataforma a varios juegos en una sola petición.
  Future<int> bulkAddPlatform({
    required String userId,
    required String platformName,
    required Iterable<int> gameIds,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedPlatform = platformName.trim();
    if (trimmedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Usuario no válido');
    }
    if (trimmedPlatform.isEmpty) {
      throw ArgumentError.value(
        platformName,
        'platformName',
        'La plataforma no puede estar vacía',
      );
    }
    final ids = gameIds.toSet().toList();
    if (ids.any((id) => id <= 0)) {
      throw ArgumentError.value(
        gameIds,
        'gameIds',
        'Todos los IDs de juego deben ser válidos',
      );
    }
    requireAuthenticatedUserId(_client, expectedUserId: trimmedUserId);
    if (ids.isEmpty) return 0;

    final rows = ids
        .map(
          (gameId) => {
            'user_id': trimmedUserId,
            'game_id': gameId,
            'platform_name': trimmedPlatform,
          },
        )
        .toList();

    await _client.from('user_game_platforms').upsert(rows);
    return ids.length;
  }

  /// Juegos terminados de la biblioteca del usuario, con plataformas ya asignadas y sugerencias.
  Future<List<LibraryGameOption>> fetchLibraryForShelf(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return [];

    final results = await Future.wait([
      _client
          .from('user_games')
          .select('status, steam_owned, games($kGameCardColumns)')
          .eq('user_id', trimmedUserId)
          .inFilter('status', ['beaten', 'completed'])
          .order('updated_at', ascending: false)
          .limit(5000),
      _client
          .from('user_game_platforms')
          .select('game_id, platform_name')
          .eq('user_id', trimmedUserId)
          .limit(10000),
      _client
          .from('reviews')
          .select('game_id, platform')
          .eq('user_id', trimmedUserId)
          .not('platform', 'is', null)
          .order('created_at', ascending: false)
          .limit(5000),
    ]);

    final rows = results[0] as List;
    final platformRows = results[1] as List;
    final reviewRows = results[2] as List;

    final ownedByGame = <int, List<String>>{};
    for (final row in platformRows.whereType<Map>()) {
      final gameId = (row['game_id'] as num?)?.toInt();
      final platformName = row['platform_name']?.toString();
      if (gameId != null && platformName != null && platformName.isNotEmpty) {
        ownedByGame.putIfAbsent(gameId, () => []).add(platformName);
      }
    }

    final reviewPlatformByGame = <int, String>{};
    for (final row in reviewRows.whereType<Map>()) {
      final gameId = (row['game_id'] as num?)?.toInt();
      if (gameId != null) {
        reviewPlatformByGame.putIfAbsent(
          gameId,
          () => row['platform'] as String? ?? '',
        );
      }
    }

    final options = <LibraryGameOption>[];
    for (final row in rows.whereType<Map>()) {
      final gameData = row['games'];
      if (gameData is! Map) continue;

      final game = Game.fromMap(Map<String, dynamic>.from(gameData));
      final steamOwned = row['steam_owned'] as bool? ?? false;
      final owned = ShelfPlatforms.normalizeIds(ownedByGame[game.igdbId] ?? []);
      final suggested = ShelfPlatforms.suggest(
        reviewPlatform: reviewPlatformByGame[game.igdbId],
        steamOwned: steamOwned,
        alreadyOwned: owned,
      );

      options.add(
        LibraryGameOption(
          game: game,
          ownedPlatforms: owned,
          suggestedPlatforms: suggested,
          steamOwned: steamOwned,
        ),
      );
    }

    return options;
  }
}
