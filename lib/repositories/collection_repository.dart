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
    await _client.from('user_game_platforms').upsert({
      'user_id': userId,
      'game_id': gameId,
      'platform_name': platformName,
    });
  }

  Future<void> removePlatform({
    required String userId,
    required int gameId,
    required String platformName,
  }) async {
    await _client
        .from('user_game_platforms')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .eq('platform_name', platformName);
  }

  /// Sincroniza las plataformas seleccionadas: añade las nuevas y elimina las desmarcadas.
  Future<void> setPlatformsForGame({
    required String userId,
    required int gameId,
    required List<String> selectedPlatforms,
  }) async {
    final current = await fetchOwnedPlatforms(userId, gameId);
    final selected = selectedPlatforms.toSet();
    final currentSet = current.toSet();

    for (final platform in selected.difference(currentSet)) {
      await addPlatform(
        userId: userId,
        gameId: gameId,
        platformName: platform,
      );
    }
    for (final platform in currentSet.difference(selected)) {
      await removePlatform(
        userId: userId,
        gameId: gameId,
        platformName: platform,
      );
    }
  }

  /// Añade la misma plataforma a varios juegos en una sola petición.
  Future<int> bulkAddPlatform({
    required String userId,
    required String platformName,
    required Iterable<int> gameIds,
  }) async {
    final ids = gameIds.toSet().toList();
    if (ids.isEmpty) return 0;

    final rows = ids
        .map(
          (gameId) => {
            'user_id': userId,
            'game_id': gameId,
            'platform_name': platformName,
          },
        )
        .toList();

    await _client.from('user_game_platforms').upsert(rows);
    return ids.length;
  }

  /// Juegos terminados de la biblioteca del usuario, con plataformas ya asignadas y sugerencias.
  Future<List<LibraryGameOption>> fetchLibraryForShelf(String userId) async {
    final rows = await _client
        .from('user_games')
        .select('status, steam_owned, games(*)')
        .eq('user_id', userId)
        .eq('status', 'beaten')
        .order('updated_at', ascending: false);

    final platformRows = await _client
        .from('user_game_platforms')
        .select('game_id, platform_name')
        .eq('user_id', userId);

    final ownedByGame = <int, List<String>>{};
    for (final row in platformRows as List) {
      final map = row as Map;
      final gameId = (map['game_id'] as num).toInt();
      ownedByGame.putIfAbsent(gameId, () => []).add(
            map['platform_name'] as String,
          );
    }

    final reviewRows = await _client
        .from('reviews')
        .select('game_id, platform')
        .eq('user_id', userId)
        .not('platform', 'is', null)
        .order('created_at', ascending: false);

    final reviewPlatformByGame = <int, String>{};
    for (final row in reviewRows as List) {
      final map = row as Map;
      final gameId = (map['game_id'] as num).toInt();
      reviewPlatformByGame.putIfAbsent(
        gameId,
        () => map['platform'] as String? ?? '',
      );
    }

    final options = <LibraryGameOption>[];
    for (final row in rows as List) {
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
