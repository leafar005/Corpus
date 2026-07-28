import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/storage_utils.dart';
import '../utils/igdb_constants.dart';

/// Resultado de una operación de guardado de reseña.
/// Separa los datos puros del manejo de UI en el screen.
class SaveReviewResult {
  /// IDs de logros recién desbloqueados (vacío si ninguno).
  final Set<String> newlyUnlockedAchievementIds;

  /// Detalles completos de los logros recién desbloqueados.
  final List<Map<String, dynamic>> newAchievementDetails;

  const SaveReviewResult({
    required this.newlyUnlockedAchievementIds,
    required this.newAchievementDetails,
  });
}

class StashStatsResult {
  final Map<String, dynamic>? stats;
  final bool needsFetch;
  StashStatsResult({required this.stats, required this.needsFetch});
}

/// Acceso a datos para reseñas y biblioteca del usuario.
///
/// Extrae toda la lógica Supabase de [GameDetailsScreen] para que
/// el widget solo gestione estado de UI y no sepa nada de la BD.
///
/// Uso:
/// ```dart
/// final repo = ReviewRepository();
/// final result = await repo.saveReview(userId: ..., gameData: ..., ...);
/// ```
class ReviewRepository {
  final SupabaseClient _client;

  ReviewRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Acceso al cliente para operaciones de auth (currentUser, etc.)
  SupabaseClient get client => _client;

  // ──────────────────────────────────────────────────────────────────
  // Lectura
  // ──────────────────────────────────────────────────────────────────

  /// Devuelve la entrada de `user_games` (con datos de usuario) para
  /// el juego indicado, o `null` si no está en la biblioteca.
  Future<Map<String, dynamic>?> fetchUserGame({
    required String userId,
    required dynamic gameId,
  }) async {
    return await _client
        .from('user_games')
        .select('*, users!user_games_user_id_fkey(*)')
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .maybeSingle();
  }

  /// Devuelve el perfil del usuario (solo columnas de `users`).
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    return await _client.from('users').select().eq('id', userId).maybeSingle();
  }

  /// Devuelve las reseñas del usuario para un juego, ordenadas por fecha.
  Future<List<Map<String, dynamic>>> fetchReviews({
    required String userId,
    required dynamic gameId,
  }) async {
    final response = await _client
        .from('reviews')
        .select('*, review_likes(user_id), review_comments(id)')
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ──────────────────────────────────────────────────────────────────
  // Escritura
  // ──────────────────────────────────────────────────────────────────

  /// Sanitiza los datos de reseña, forzando a null notas y comentarios cuando status == 'wishlist'.
  static Map<String, dynamic> sanitizeReviewData({
    required String userId,
    required dynamic igdbId,
    required String status,
    required double rating,
    required double ratingGameplay,
    required double ratingNarrative,
    required double ratingSoundtrack,
    required double ratingVisuals,
    required String comment,
    required String completionType,
    required bool isReplay,
    required int? replayNumber,
    required String? platform,
    required double? playTimeHours,
    required DateTime? playedFrom,
    required DateTime? playedUntil,
    required int? progressPercent,
    required List<String> imageUrls,
  }) {
    final isWishlist = status == 'wishlist';
    return <String, dynamic>{
      'user_id': userId,
      'game_id': igdbId,
      'rating': isWishlist ? null : (rating >= 1 ? rating : null),
      'rating_gameplay': isWishlist ? null : (ratingGameplay >= 1 ? ratingGameplay : null),
      'rating_narrative': isWishlist ? null : (ratingNarrative >= 1 ? ratingNarrative : null),
      'rating_soundtrack': isWishlist ? null : (ratingSoundtrack >= 1 ? ratingSoundtrack : null),
      'rating_visuals': isWishlist ? null : (ratingVisuals >= 1 ? ratingVisuals : null),
      'comment': isWishlist ? null : (comment.trim().isNotEmpty ? comment.trim() : null),
      'status': status,
      'completion_type': isWishlist ? 'none' : completionType,
      'is_replay': isWishlist ? false : isReplay,
      'replay_number': isWishlist ? null : (isReplay ? replayNumber : null),
      'platform': isWishlist ? null : platform,
      'play_time_hours': isWishlist ? null : (playTimeHours != null && playTimeHours > 0 ? playTimeHours : null),
      'played_from': isWishlist ? null : playedFrom?.toIso8601String().split('T')[0],
      'played_until': isWishlist ? null : playedUntil?.toIso8601String().split('T')[0],
      'progress_percent': isWishlist ? null : progressPercent,
      'image_urls': isWishlist ? <String>[] : imageUrls,
    };
  }

  /// Calcula los IDs de logros recién desbloqueados comparando el antes y el después.
  static Set<String> computeUnlockedAchievements(
    Set<String> beforeAchievements,
    Set<String> afterAchievements,
  ) {
    return afterAchievements.difference(beforeAchievements);
  }

  /// Persiste el catálogo de juego en Supabase (upsert por igdb_id).
  /// No lanza si hay error — registra y continúa.
  Future<void> upsertGame({
    required dynamic igdbId,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> enrichedData,
  }) async {
    try {
      await _client.from('games').upsert({
        'igdb_id': igdbId,
        'title': gameData['title'],
        'cover_url': gameData['cover_url'],
        'release_date': gameData['release_date']?.toString().split('T')[0],
        'genres': gameData['genres'] ?? enrichedData['genres'],
        'category': () {
          final dynamic rawCat = gameData['category'] ??
              gameData['game_type'] ??
              enrichedData['category'] ??
              enrichedData['game_type'];
          final int? catId = (rawCat is num)
              ? rawCat.toInt()
              : int.tryParse(rawCat?.toString() ?? '');
          final String title = gameData['title'] ?? 'Desconocido';
          final bool hasParent = gameData['parent_game'] != null ||
              enrichedData['parent_game'] != null ||
              gameData['version_parent'] != null ||
              enrichedData['version_parent'] != null ||
              gameData['remake_of'] != null ||
              enrichedData['remake_of'] != null ||
              gameData['remaster_of'] != null ||
              enrichedData['remaster_of'] != null;
          return IgdbConstants.resolveCategory(catId, title,
                  hasParentGame: hasParent,
                  summary: gameData['summary']?.toString() ??
                      enrichedData['summary']?.toString()) ??
              0;
        }(),
        'parent_game': () {
          final pg = gameData['parent_game'] ??
              enrichedData['parent_game'] ??
              gameData['version_parent'] ??
              enrichedData['version_parent'] ??
              gameData['remake_of'] ??
              enrichedData['remake_of'] ??
              gameData['remaster_of'] ??
              enrichedData['remaster_of'];
          if (pg is Map) return pg['id'] ?? pg['igdb_id'];
          return pg;
        }(),
        'themes': gameData['themes'] ?? enrichedData['themes'],
        'game_modes': gameData['game_modes'] ?? enrichedData['game_modes'],
        'player_perspectives': gameData['player_perspectives'] ?? enrichedData['player_perspectives'],
        'platforms': gameData['platforms'] ?? enrichedData['platforms'],
        'summary': gameData['summary'] ?? enrichedData['summary'],
        'developer': () {
          final dev = gameData['developer'];
          if (dev != null && dev != 'Desconocido' && dev != 'Desarrollador desconocido') return dev;
          return enrichedData['developer'];
        }(),
        'collection': () {
          final col = gameData['collection'] ?? enrichedData['collection'];
          if (col is Map && col['id'] != null) return col;
          if (col is String && col != 'null' && col.isNotEmpty) return {'name': col};
          return null;
        }(),
        'franchises': () {
          final frs = gameData['franchises'] ?? enrichedData['franchises'];
          if (frs is List && frs.isNotEmpty) {
            return frs
                .map((f) => f is Map
                    ? {'id': f['id'], 'name': f['name']}
                    : {'name': f.toString()})
                .toList();
          }
          return [];
        }(),
        'game_engines': gameData['game_engines'] ?? enrichedData['game_engines'],
      }, onConflict: 'igdb_id', ignoreDuplicates: false);
    } catch (e) {
      debugPrint('[ReviewRepository] Game catalog upsert error: $e');
    }
  }

  /// Sube las imágenes nuevas a Supabase Storage y devuelve sus URLs públicas.
  Future<List<String>> uploadImages({
    required String userId,
    required List<XFile> files,
  }) async {
    final List<String> urls = [];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.$ext';
        final path = '$userId/$fileName';

        await _client.storage.from('user_uploads').uploadBinary(path, bytes);
        urls.add(_client.storage.from('user_uploads').getPublicUrl(path));
      } catch (e) {
        debugPrint('[ReviewRepository] Error uploading image: $e');
      }
    }
    return urls;
  }

  /// Guarda o actualiza una reseña y sincroniza `user_games`.
  /// Devuelve [SaveReviewResult] con los logros recién desbloqueados.
  Future<SaveReviewResult> saveReview({
    required String userId,
    required dynamic igdbId,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> enrichedData,
    String? reviewId,
    required double rating,
    required double ratingGameplay,
    required double ratingNarrative,
    required double ratingSoundtrack,
    required double ratingVisuals,
    required String comment,
    required String status,
    required String completionType,
    required bool isReplay,
    required int? replayNumber,
    required String? platform,
    required double? playTimeHours,
    required DateTime? playedFrom,
    required DateTime? playedUntil,
    required int? progressPercent,
    required List<XFile> newImages,
    required List<String> existingImages,
  }) async {
    // Snapshot de logros antes de la operación
    Set<String> beforeAchievements = {};
    try {
      final beforeRes = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      beforeAchievements =
          beforeRes.map((e) => e['achievement_id'] as String).toSet();
    } catch (_) {}

    // Upsert del juego en el catálogo
    await upsertGame(
      igdbId: igdbId,
      gameData: gameData,
      enrichedData: enrichedData,
    );

    final isWishlist = status == 'wishlist';

    // Subir imágenes nuevas
    final List<String> finalImageUrls =
        isWishlist ? [] : List<String>.from(existingImages);
    if (!isWishlist && newImages.isNotEmpty) {
      final uploaded = await uploadImages(userId: userId, files: newImages);
      finalImageUrls.addAll(uploaded);
    }

    // Construir payload de reseña mediante método sanitizador estático
    final reviewData = sanitizeReviewData(
      userId: userId,
      igdbId: igdbId,
      status: status,
      rating: rating,
      ratingGameplay: ratingGameplay,
      ratingNarrative: ratingNarrative,
      ratingSoundtrack: ratingSoundtrack,
      ratingVisuals: ratingVisuals,
      comment: comment,
      completionType: completionType,
      isReplay: isReplay,
      replayNumber: replayNumber,
      platform: platform,
      playTimeHours: playTimeHours,
      playedFrom: playedFrom,
      playedUntil: playedUntil,
      progressPercent: progressPercent,
      imageUrls: finalImageUrls,
    );

    // Insert o update según si ya existe la reseña
    if (reviewId != null) {
      try {
        final oldReview = await _client
            .from('reviews')
            .select('image_urls')
            .eq('id', reviewId)
            .maybeSingle();
        if (oldReview != null && oldReview['image_urls'] != null) {
          final List<String> oldUrls = (oldReview['image_urls'] as List)
              .map((e) => e.toString())
              .toList();
          final List<String> removedUrls = oldUrls
              .where((url) => !finalImageUrls.contains(url))
              .toList();
          if (removedUrls.isNotEmpty) {
            await StorageUtils.deleteImagesFromUrls(removedUrls);
            debugPrint('[ReviewRepository] Eliminadas ${removedUrls.length} imágenes quitadas en la edición de la reseña.');
          }
        }
      } catch (e) {
        debugPrint('[ReviewRepository] Error al limpiar imágenes en edición: $e');
      }

      await _client.from('reviews').update(reviewData).eq('id', reviewId);
    } else {
      await _client.from('reviews').insert(reviewData);
    }

    // Sincronizar user_games
    await _client.from('user_games').upsert({
      'user_id': userId,
      'game_id': igdbId,
      'status': status,
      'rating': isWishlist ? null : (rating >= 1 ? rating : null),
      'rating_gameplay': isWishlist ? null : (ratingGameplay >= 1 ? ratingGameplay : null),
      'rating_narrative': isWishlist ? null : (ratingNarrative >= 1 ? ratingNarrative : null),
      'rating_soundtrack': isWishlist ? null : (ratingSoundtrack >= 1 ? ratingSoundtrack : null),
      'rating_visuals': isWishlist ? null : (ratingVisuals >= 1 ? ratingVisuals : null),
      'comment': isWishlist ? null : (comment.trim().isNotEmpty ? comment.trim() : null),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id, game_id');

    // Detectar logros recién desbloqueados
    Set<String> newlyUnlocked = {};
    List<Map<String, dynamic>> achievementDetails = [];
    try {
      final afterRes = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      final afterAchievements =
          afterRes.map((e) => e['achievement_id'] as String).toSet();
      newlyUnlocked = computeUnlockedAchievements(beforeAchievements, afterAchievements);

      if (newlyUnlocked.isNotEmpty) {
        final detailsRes = await _client
            .from('achievements')
            .select('*')
            .inFilter('id', newlyUnlocked.toList());
        achievementDetails = List<Map<String, dynamic>>.from(detailsRes);
      }
    } catch (e) {
      debugPrint('[ReviewRepository] Error checking achievements: $e');
    }

    return SaveReviewResult(
      newlyUnlockedAchievementIds: newlyUnlocked,
      newAchievementDetails: achievementDetails,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Borrado
  // ──────────────────────────────────────────────────────────────────

  /// Elimina el juego de la biblioteca del usuario (user_games + reviews + imágenes).
  Future<void> deleteFromLibrary({
    required String userId,
    required dynamic gameId,
  }) async {
    // 1. Borrar entry de user_games
    await _client
        .from('user_games')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId);

    // 2. Recopilar URLs de imágenes (reseñas + comentarios)
    final reviewsResponse = await _client
        .from('reviews')
        .select('id, image_urls')
        .eq('user_id', userId)
        .eq('game_id', gameId);

    final List<String> reviewIds = [];
    final List<String> allImageUrls = [];

    for (var r in reviewsResponse) {
      reviewIds.add(r['id']);
      if (r['image_urls'] != null) {
        allImageUrls.addAll((r['image_urls'] as List).map((e) => e.toString()));
      }
    }

    if (reviewIds.isNotEmpty) {
      final commentsResponse = await _client
          .from('review_comments')
          .select('image_url')
          .inFilter('review_id', reviewIds);
      for (var c in commentsResponse) {
        if (c['image_url'] != null) allImageUrls.add(c['image_url']);
      }
    }

    // 3. Borrar imágenes del storage
    if (allImageUrls.isNotEmpty) {
      await StorageUtils.deleteImagesFromUrls(allImageUrls);
    }

    // 4. Borrar reseñas
    await _client
        .from('reviews')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId);
  }

  /// Elimina una reseña individual y sus imágenes.
  /// Devuelve `true` si el usuario ya no tiene más reseñas para ese juego
  /// (para que el screen pueda actualizar `_inLibrary`).
  Future<bool> deleteReview({
    required String reviewId,
    required Map<String, dynamic> reviewData,
    required dynamic gameId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    // Recopilar URLs de imágenes desde BD para garantizar la limpieza total en Storage
    final List<String> urlsToDelete = [];
    try {
      final dbReview = await _client
          .from('reviews')
          .select('image_urls')
          .eq('id', reviewId)
          .maybeSingle();
      if (dbReview != null && dbReview['image_urls'] != null) {
        urlsToDelete.addAll((dbReview['image_urls'] as List).map((e) => e.toString()));
      }
    } catch (_) {}

    final reviewImageUrls = reviewData['image_urls'] as List<dynamic>?;
    if (reviewImageUrls != null) {
      for (var url in reviewImageUrls) {
        if (!urlsToDelete.contains(url.toString())) {
          urlsToDelete.add(url.toString());
        }
      }
    }

    final commentsResponse = await _client
        .from('review_comments')
        .select('image_url')
        .eq('review_id', reviewId);
    for (var c in commentsResponse) {
      if (c['image_url'] != null && !urlsToDelete.contains(c['image_url'])) {
        urlsToDelete.add(c['image_url']);
      }
    }

    if (urlsToDelete.isNotEmpty) {
      await StorageUtils.deleteImagesFromUrls(urlsToDelete);
      debugPrint('[ReviewRepository] Eliminadas ${urlsToDelete.length} imágenes al borrar la reseña.');
    }

    await _client.from('reviews').delete().eq('id', reviewId);

    // ¿Quedan más reseñas para este juego?
    if (gameId != null) {
      final remaining = await _client
          .from('reviews')
          .select('id')
          .eq('game_id', gameId)
          .eq('user_id', userId);

      if (remaining.isEmpty) {
        await _client
            .from('user_games')
            .delete()
            .eq('game_id', gameId)
            .eq('user_id', userId);
        return true; // ya no está en biblioteca
      }
    }
    return false;
  }

  // ──────────────────────────────────────────────────────────────────
  // Amigos & actividad social
  // ──────────────────────────────────────────────────────────────────

  /// Devuelve los amigos del usuario que tienen este juego en su biblioteca.
  ///
  /// Consolida 3 queries en un solo método:
  /// 1. Amistades enviadas por el usuario
  /// 2. Amistades recibidas por el usuario
  /// 3. `user_games` filtrado por esos amigos y el `gameId`
  /// Devuelve los amigos del usuario que tienen este juego en su biblioteca.
  ///
  /// Usa la vista [v_friend_pairs] (Fase 3) para obtener todos los friend_ids
  /// en **2 queries** en vez de las 3 originales:
  ///   1. `v_friend_pairs` WHERE user_id = myId  → lista de friend_ids
  ///   2. `user_games` WHERE game_id = X AND user_id IN (friend_ids)
  ///
  /// Si la vista aún no existe en la BD (migración no aplicada), cae en el
  /// método legacy con 3 queries para no romper la app.
  Future<List<Map<String, dynamic>>> fetchFriendsWithGame({
    required String myId,
    required dynamic gameId,
  }) async {
    final int parsedGameId =
        gameId is int ? gameId : int.parse(gameId.toString());

    List<String> friendIds;

    try {
      // Query optimizada usando la vista v_friend_pairs (Fase 3 DB)
      final pairsResult = await _client
          .from('v_friend_pairs')
          .select('friend_id')
          .eq('user_id', myId);

      friendIds = List<Map<String, dynamic>>.from(pairsResult)
          .map((r) => r['friend_id'] as String)
          .toList();
    } catch (_) {
      // Fallback: vista no aplicada todavía — usa el método original con 3 queries
      final sentFriends = await _client
          .from('friendships')
          .select('addressee_id')
          .eq('requester_id', myId)
          .eq('status', 'accepted');
      final receivedFriends = await _client
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', myId)
          .eq('status', 'accepted');
      friendIds = <String>[
        ...List<Map<String, dynamic>>.from(sentFriends)
            .map((f) => f['addressee_id'] as String),
        ...List<Map<String, dynamic>>.from(receivedFriends)
            .map((f) => f['requester_id'] as String),
      ];
    }

    if (friendIds.isEmpty) return [];

    final result = await _client
        .from('user_games')
        .select(
            'status, users!user_games_user_id_fkey(id, username, display_name, avatar_url)')
        .eq('game_id', parsedGameId)
        .inFilter('user_id', friendIds);

    return List<Map<String, dynamic>>.from(result);
  }

  /// Devuelve la actividad del feed de un amigo para un juego concreto,
  /// incluyendo la reseña completa si existe.
  Future<({List<Map<String, dynamic>> activities, Map<String, dynamic>? review})>
      fetchFriendActivityForGame({
    required String userId,
    required dynamic gameId,
  }) async {
    final int parsedGameId =
        gameId is int ? gameId : int.parse(gameId.toString());

    final rawActivities = await _client
        .from('activity_feed')
        .select('*, users!activity_feed_user_id_fkey(*), games(*)')
        .eq('user_id', userId)
        .eq('game_id', parsedGameId)
        .order('created_at', ascending: false)
        .limit(10);

    final activities = List<Map<String, dynamic>>.from(rawActivities);

    Map<String, dynamic>? bestActivity;
    if (activities.isNotEmpty) {
      bestActivity = activities.firstWhere(
        (act) =>
            act['action_type'] == 'reviewed' ||
            act['rating'] != null ||
            (act['content'] != null &&
                act['content'].toString().isNotEmpty),
        orElse: () => activities.first,
      );
    }

    Map<String, dynamic>? review;
    if (bestActivity != null) {
      final metadata =
          bestActivity['metadata'] as Map<String, dynamic>? ?? {};
      final reviewId = metadata['review_id'];
      if (reviewId != null) {
        try {
          final reviewResponse = await _client
              .from('reviews')
              .select('*, review_likes(user_id), review_comments(id)')
              .eq('id', reviewId)
              .maybeSingle();
          review = reviewResponse;
        } catch (_) {}
      }
    }

    return (activities: activities, review: review);
  }

  // ──────────────────────────────────────────────────────────────────
  // Reseñas de Stash (comunidad externa)
  // ──────────────────────────────────────────────────────────────────

  /// Resultado de la carga de reseñas de Stash.
  /// [reviews] = reseñas locales; [needsFetch] = se lanzó Edge Function.
  static const int _stashTtlDays = 7;

  /// Devuelve las reseñas locales de Stash y si se necesita refrescar.
  Future<({List<Map<String, dynamic>> reviews, bool needsFetch})>
      fetchStashReviewsLocal(dynamic gameId) async {
    final localResp = await _client
        .from('stash_community_reviews')
        .select()
        .eq('game_id', gameId)
        .order('stash_created_at', ascending: false)
        .limit(20);

    final localReviews = List<Map<String, dynamic>>.from(localResp);

    final metaResponse = await _client
        .from('stash_sync_metadata')
        .select('last_checked_at')
        .eq('game_id', gameId)
        .maybeSingle();

    bool needsFetch = true;
    if (metaResponse != null && metaResponse['last_checked_at'] != null) {
      final lastChecked = DateTime.parse(metaResponse['last_checked_at']);
      if (DateTime.now().difference(lastChecked).inDays <= _stashTtlDays) {
        needsFetch = false;
      }
    }

    return (reviews: localReviews, needsFetch: needsFetch);
  }

  /// Llama a la Edge Function `fetch-stash-reviews` y retorna las reseñas
  /// actualizadas. Devuelve `null` si la función falla.
  Future<List<Map<String, dynamic>>?> refreshStashReviews(dynamic gameId) async {
    final functionResponse = await _client.functions.invoke(
      'fetch-stash-reviews',
      body: {'igdb_id': gameId},
    );

    if (functionResponse.status != 200) return null;

    final newResponse = await _client
        .from('stash_community_reviews')
        .select()
        .eq('game_id', gameId)
        .order('stash_created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(newResponse);
  }

  static const Duration _statsMaxAge = Duration(hours: 6);

  Future<StashStatsResult> fetchStashStatsLocal(dynamic igdbId) async {
    final row = await _client
        .from('stash_game_stats')
        .select()
        .eq('game_id', igdbId)
        .maybeSingle();

    if (row == null) {
      return StashStatsResult(stats: null, needsFetch: true);
    }

    final checkedAtRaw = row['last_stats_checked_at'] as String?;
    final checkedAt = checkedAtRaw != null ? DateTime.tryParse(checkedAtRaw) : null;
    final isStale = checkedAt == null || DateTime.now().toUtc().difference(checkedAt.toUtc()) > _statsMaxAge;

    return StashStatsResult(stats: row, needsFetch: isStale);
  }

  Future<Map<String, dynamic>?> refreshStashStats(dynamic igdbId) async {
    try {
      await _client.functions.invoke('fetch-stash-game-stats', body: {'igdb_id': igdbId});
    } catch (e) {
      debugPrint('[CORPUS] Error invocando fetch-stash-game-stats: $e');
      return null;
    }
    // Releer de local tras la sincronización
    final row = await _client
        .from('stash_game_stats')
        .select()
        .eq('game_id', igdbId)
        .maybeSingle();
    return row;
  }
}
