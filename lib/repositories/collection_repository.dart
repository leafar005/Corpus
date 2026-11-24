import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
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

  /// Devuelve una caja por cada (juego, plataforma) del usuario.
  Future<List<ShelfItem>> fetchShelfGames(String userId) async {
    final rows = await _client
        .from('user_game_platforms')
        .select('platform_name, games(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final items = <ShelfItem>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final gameData = map['games'];
      if (gameData == null) continue;
      items.add(
        ShelfItem(
          game: Game.fromMap(Map<String, dynamic>.from(gameData as Map)),
          platformName: map['platform_name'] as String? ?? '',
        ),
      );
    }
    return items;
  }

  Future<List<String>> fetchOwnedPlatforms(String userId, int gameId) async {
    final rows = await _client
        .from('user_game_platforms')
        .select('platform_name')
        .eq('user_id', userId)
        .eq('game_id', gameId);

    return (rows as List)
        .map((r) => (r as Map)['platform_name'] as String)
        .toList();
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

    await _client
        .from('user_game_platforms')
        .delete()
        .eq('user_id', trimmedUserId)
        .eq('game_id', gameId)
        .eq('platform_name', trimmedPlatform);
  }

  /// Sincroniza las plataformas seleccionadas: añade las nuevas y elimina las desmarcadas.
  Future<void> setPlatformsForGame({
    required String userId,
    required int gameId,
    required List<String> selectedPlatforms,
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

    final current = await fetchOwnedPlatforms(trimmedUserId, gameId);
    final currentSet = current.toSet();

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
      for (final platform in toRemove)
        removePlatform(
          userId: trimmedUserId,
          gameId: gameId,
          platformName: platform,
        ),
    ]);
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
    final results = await Future.wait([
      _client
          .from('user_games')
          .select('status, steam_owned, games(*)')
          .eq('user_id', userId)
          .inFilter('status', ['beaten', 'completed'])
          .order('updated_at', ascending: false),
      _client
          .from('user_game_platforms')
          .select('game_id, platform_name')
          .eq('user_id', userId),
      _client
          .from('reviews')
          .select('game_id, platform')
          .eq('user_id', userId)
          .not('platform', 'is', null)
          .order('created_at', ascending: false),
    ]);

    final rows = results[0] as List;
    final platformRows = results[1] as List;
    final reviewRows = results[2] as List;

    final ownedByGame = <int, List<String>>{};
    for (final row in platformRows) {
      final map = row as Map;
      final gameId = (map['game_id'] as num).toInt();
      ownedByGame.putIfAbsent(gameId, () => []).add(
            map['platform_name'] as String,
          );
    }

    final reviewPlatformByGame = <int, String>{};
    for (final row in reviewRows) {
      final map = row as Map;
      final gameId = (map['game_id'] as num).toInt();
      reviewPlatformByGame.putIfAbsent(
        gameId,
        () => map['platform'] as String? ?? '',
      );
    }

    final options = <LibraryGameOption>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final gameData = map['games'];
      if (gameData == null) continue;

      final game = Game.fromMap(Map<String, dynamic>.from(gameData as Map));
      final steamOwned = map['steam_owned'] as bool? ?? false;
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
