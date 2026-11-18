import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/storage_utils.dart';
import '../utils/igdb_constants.dart';
import '../utils/image_compressor.dart';
import '../models/models.dart';

dynamic _firstOf(dynamic list) {
  if (list is List && list.isNotEmpty && list.first is Map) return list.first;
  return null;
}

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

typedef ImageUrlsDeleter = Future<void> Function(List<String> urls);

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
  final ImageUrlsDeleter _deleteImagesFromUrls;

  ReviewRepository({
    SupabaseClient? client,
    ImageUrlsDeleter? deleteImagesFromUrls,
  }) : _client = client ?? Supabase.instance.client,
       _deleteImagesFromUrls =
           deleteImagesFromUrls ?? StorageUtils.deleteImagesFromUrls;

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
    final result = await _client
        .from('user_games')
        .select('*, users!user_games_user_id_fkey(*)')
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .maybeSingle();

    if (result != null) {
      await injectPartners([result]);
    }
    return result;
  }

  /// Injecta la información del perfil en la propiedad `partners` dado un arreglo `partner_ids`
  Future<void> injectPartners(List<Map<String, dynamic>> items) async {
    final Set<String> allIds = {};
    for (final item in items) {
      final ids = item['partner_ids'];
      if (ids is List) {
        allIds.addAll(ids.map((e) => e.toString()));
      }
    }
    if (allIds.isEmpty) return;

    final users = await _client
        .from('users')
        .select('id, username, avatar_url, display_name')
        .inFilter('id', allIds.toList());

    final Map<String, Map<String, dynamic>> userMap = {
      for (final u in users) u['id'] as String: u,
    };

    for (final item in items) {
      final ids = item['partner_ids'];
      if (ids is List) {
        item['partners'] = ids
            .map((id) => userMap[id.toString()])
            .where((u) => u != null)
            .toList();
      }
    }
  }

  /// Devuelve el perfil del usuario (solo columnas de `users`).
  Future<UserProfile?> fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  /// Devuelve las reseñas del usuario para un juego, ordenadas por fecha.
  Future<List<Review>> fetchReviews({
    required String userId,
    required dynamic gameId,
  }) async {
    final response = await _client
        .from('reviews')
        .select('*')
        .eq('user_id', userId)
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    final items = List<Map<String, dynamic>>.from(response);
    await injectPartners(items);

    return items.map(Review.fromMap).toList();
  }

  // ──────────────────────────────────────────────────────────────────
  // Escritura
  // ──────────────────────────────────────────────────────────────────

  /// Sanitiza los datos de reseña, forzando a null notas y comentarios cuando status == 'wishlist' o 'to_play'.
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
    required List<String> partnerIds,
    DateTime? reviewDate,
  }) {
    final isWishlist = status == 'wishlist' || status == 'to_play';
    return <String, dynamic>{
      'user_id': userId,
      'game_id': igdbId,
      'rating': isWishlist ? null : (rating >= 1 ? rating : null),
      'rating_gameplay': isWishlist
          ? null
          : (ratingGameplay >= 1 ? ratingGameplay : null),
      'rating_narrative': isWishlist
          ? null
          : (ratingNarrative >= 1 ? ratingNarrative : null),
      'rating_soundtrack': isWishlist
          ? null
          : (ratingSoundtrack >= 1 ? ratingSoundtrack : null),
      'rating_visuals': isWishlist
          ? null
          : (ratingVisuals >= 1 ? ratingVisuals : null),
      'comment': isWishlist
          ? null
          : (comment.trim().isNotEmpty ? comment.trim() : null),
      'status': status,
      'completion_type': isWishlist ? 'none' : completionType,
      'is_replay': !isWishlist && isReplay,
      'replay_number': isWishlist ? null : (isReplay ? replayNumber : null),
      'platform': isWishlist ? null : platform,
      'play_time_hours': isWishlist
          ? null
          : (playTimeHours != null && playTimeHours > 0 ? playTimeHours : null),
      'played_from': isWishlist
          ? null
          : playedFrom?.toIso8601String().split('T')[0],
      'played_until': isWishlist
          ? null
          : playedUntil?.toIso8601String().split('T')[0],
      'progress_percent': isWishlist ? null : progressPercent,
      'image_urls': isWishlist ? <String>[] : imageUrls,
      'partner_ids': isWishlist ? [] : partnerIds,
      // Fecha de finalización: solo se incluye cuando el usuario la elige o al
      // marcar como terminado (el trigger sincroniza last_played_at desde aquí).
      if (reviewDate != null) ...{
        'created_at': reviewDate.toUtc().toIso8601String(),
        'updated_at': reviewDate.toUtc().toIso8601String(),
      },
    };
  }

  /// Calcula los IDs de logros recién desbloqueados comparando el antes y el después.
  static Set<String> computeUnlockedAchievements(
    Set<String> beforeAchievements,
    Set<String> afterAchievements,
  ) {
    return afterAchievements.difference(beforeAchievements);
  }

  static String? _nonEmptyString(dynamic value) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty || str == 'null') return null;
    return str;
  }

  static bool _isValidDeveloper(dynamic value) {
    final str = _nonEmptyString(value);
    return str != null &&
        str != 'Desconocido' &&
        str != 'Desarrollador desconocido';
  }

  static List<dynamic>? _nonEmptyList(dynamic value) {
    if (value is List && value.isNotEmpty) return value;
    return null;
  }

  static int? _resolveCatalogCategory(
    Map<String, dynamic> primary,
    Map<String, dynamic> secondary, {
    int? fallback = 0,
  }) {
    final dynamic rawCat =
        primary['game_type'] ??
        primary['category'] ??
        secondary['game_type'] ??
        secondary['category'];
    final int? catId = (rawCat is num)
        ? rawCat.toInt()
        : int.tryParse(rawCat?.toString() ?? '');
    if (rawCat == null &&
        primary['parent_game'] == null &&
        secondary['parent_game'] == null &&
        primary['version_parent'] == null &&
        secondary['version_parent'] == null) {
      return fallback;
    }
    final String title =
        _nonEmptyString(primary['title']) ??
        _nonEmptyString(secondary['title']) ??
        'Desconocido';
    final bool hasParent =
        primary['parent_game'] != null || secondary['parent_game'] != null;
    final bool hasVersion =
        primary['version_parent'] != null ||
        secondary['version_parent'] != null;
    return IgdbConstants.resolveCategory(
          catId,
          title,
          hasParentGame: hasParent,
          hasVersionParent: hasVersion,
          summary:
              _nonEmptyString(primary['summary']) ??
              _nonEmptyString(secondary['summary']),
        ) ??
        fallback;
  }

  /// Persiste el catálogo de juego en Supabase (upsert por igdb_id).
  /// Si ya existía una fila esqueleto sin portada/metadatos, lanza también el
  /// backfill via `igdb-proxy` (`service_role`).
  /// No lanza si hay error — registra y continúa.
  Future<void> upsertGame({
    required dynamic igdbId,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> enrichedData,
  }) async {
    try {
      final resolvedCover =
          _nonEmptyString(gameData['cover_url']) ??
          _nonEmptyString(enrichedData['cover_url']);
      final resolvedReleaseDate =
          (_nonEmptyString(gameData['release_date']) ??
                  _nonEmptyString(enrichedData['release_date']))
              ?.split('T')[0];
      final resolvedDeveloper = _isValidDeveloper(gameData['developer'])
          ? gameData['developer']
          : (_isValidDeveloper(enrichedData['developer'])
                ? enrichedData['developer']
                : null);
      final resolvedSummary =
          _nonEmptyString(gameData['summary']) ??
          _nonEmptyString(enrichedData['summary']);
      final resolvedGenres =
          _nonEmptyList(gameData['genres']) ??
          _nonEmptyList(enrichedData['genres']);
      final resolvedPlatforms =
          _nonEmptyList(gameData['platforms']) ??
          _nonEmptyList(enrichedData['platforms']);
      final resolvedThemes =
          _nonEmptyList(gameData['themes']) ??
          _nonEmptyList(enrichedData['themes']);
      final resolvedGameModes =
          _nonEmptyList(gameData['game_modes']) ??
          _nonEmptyList(enrichedData['game_modes']);
      final resolvedPerspectives =
          _nonEmptyList(gameData['player_perspectives']) ??
          _nonEmptyList(enrichedData['player_perspectives']);
      final resolvedCategory = _resolveCatalogCategory(gameData, enrichedData);

      await _client
          .from('games')
          .upsert(
            {
              'igdb_id': igdbId,
              'title':
                  _nonEmptyString(gameData['title']) ??
                  _nonEmptyString(gameData['name']) ??
                  _nonEmptyString(enrichedData['title']) ??
                  _nonEmptyString(enrichedData['name']) ??
                  'Desconocido',
              'cover_url': resolvedCover,
              'release_date': resolvedReleaseDate,
              'genres': resolvedGenres,
              'category': resolvedCategory,
              'parent_game': () {
                final pg =
                    gameData['parent_game'] ?? enrichedData['parent_game'];
                if (pg is Map) return pg['id'] ?? pg['igdb_id'];
                return pg;
              }(),
              'version_parent': () {
                final vp =
                    gameData['version_parent'] ??
                    enrichedData['version_parent'];
                if (vp is Map) return vp['id'] ?? vp['igdb_id'];
                return vp;
              }(),
              'themes': resolvedThemes,
              'game_modes': resolvedGameModes,
              'player_perspectives': resolvedPerspectives,
              'platforms': resolvedPlatforms,
              'summary': resolvedSummary,
              'developer': resolvedDeveloper,
              'collection': () {
                dynamic col =
                    gameData['collection'] ?? enrichedData['collection'];
                // Fallback al sistema nuevo de IGDB (collections, plural) si
                // el campo legacy 'collection' viene vacío.
                col ??=
                    _firstOf(gameData['collections']) ??
                    _firstOf(enrichedData['collections']);
                if (col is Map && col['id'] != null) return col;
                if (col is String && col != 'null' && col.isNotEmpty) {
                  return {'name': col};
                }
                return null;
              }(),
              'franchises': () {
                final frs =
                    gameData['franchises'] ?? enrichedData['franchises'];
                if (frs is List && frs.isNotEmpty) {
                  return frs
                      .map(
                        (f) => f is Map
                            ? {'id': f['id'], 'name': f['name']}
                            : {'name': f.toString()},
                      )
                      .toList();
                }
                return [];
              }(),
              'game_engines':
                  gameData['game_engines'] ?? enrichedData['game_engines'],
            },
            onConflict: 'igdb_id',
            ignoreDuplicates: true,
          );

      final int? parsedIgdbId = igdbId is int
          ? igdbId
          : int.tryParse(igdbId.toString());
      if (parsedIgdbId != null && resolvedCover != null) {
        await backfillCoverUrl(
          igdbId: parsedIgdbId,
          enrichedData: {
            'cover_url': resolvedCover,
            'release_date': ?resolvedReleaseDate,
            'summary': ?resolvedSummary,
            'developer': ?resolvedDeveloper,
            'platforms': ?resolvedPlatforms,
            'genres': ?resolvedGenres,
            'themes': ?resolvedThemes,
            'game_modes': ?resolvedGameModes,
            'player_perspectives': ?resolvedPerspectives,
            'category': ?resolvedCategory,
          },
          currentCoverUrl: null,
        );
      }
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
        final bytes = await ImageCompressor.compressImage(file);
        if (bytes == null) continue;
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
    required List<String> partnerIds,
    DateTime? reviewDate,
  }) async {
    // Snapshot de logros antes de la operación
    Set<String> beforeAchievements = {};
    try {
      final beforeRes = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      beforeAchievements = beforeRes
          .map((e) => e['achievement_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint(
        '[ReviewRepository] Error obteniendo snapshot de logros previos: $e',
      );
    }

    // Upsert del juego en el catálogo
    await upsertGame(
      igdbId: igdbId,
      gameData: gameData,
      enrichedData: enrichedData,
    );

    final isWishlist = status == 'wishlist' || status == 'to_play';

    // Subir imágenes nuevas
    final List<String> finalImageUrls = isWishlist
        ? []
        : List<String>.from(existingImages);
    if (!isWishlist && newImages.isNotEmpty) {
      final uploaded = await uploadImages(userId: userId, files: newImages);
      finalImageUrls.addAll(uploaded);
    }

    DateTime? effectiveReviewDate = reviewDate;

    // Insert o update según si ya existe la reseña
    if (reviewId != null) {
      try {
        final oldReview = await _client
            .from('reviews')
            .select('status, image_urls')
            .eq('id', reviewId)
            .maybeSingle();
        if (oldReview != null) {
          final oldStatus = oldReview['status'] as String?;
          final wasNotFinished =
              oldStatus != 'beaten' && oldStatus != 'completed';
          final isNowFinished = status == 'beaten' || status == 'completed';
          if (wasNotFinished && isNowFinished && effectiveReviewDate == null) {
            effectiveReviewDate = DateTime.now();
          }

          if (oldReview['image_urls'] != null) {
            final List<String> oldUrls = (oldReview['image_urls'] as List)
                .map((e) => e.toString())
                .toList();
            final List<String> removedUrls = oldUrls
                .where((url) => !finalImageUrls.contains(url))
                .toList();
            if (removedUrls.isNotEmpty) {
              await StorageUtils.deleteImagesFromUrls(removedUrls);
              debugPrint(
                '[ReviewRepository] Eliminadas ${removedUrls.length} imágenes quitadas en la edición de la reseña.',
              );
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[ReviewRepository] Error al limpiar imágenes en edición: $e',
        );
      }

      await _client
          .from('reviews')
          .update(
            sanitizeReviewData(
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
              partnerIds: partnerIds,
              reviewDate: effectiveReviewDate,
            ),
          )
          .eq('id', reviewId);
    } else {
      if ((status == 'beaten' || status == 'completed') &&
          effectiveReviewDate == null) {
        effectiveReviewDate = DateTime.now();
      }
      await _client
          .from('reviews')
          .insert(
            sanitizeReviewData(
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
              partnerIds: partnerIds,
              reviewDate: effectiveReviewDate,
            ),
          );
    }

    // El trigger sync_user_games_rating_from_review se encarga automáticamente
    // de insertar/actualizar user_games cuando se modifica la reseña en la tabla reviews.

    // Detectar logros recién desbloqueados
    Set<String> newlyUnlocked = {};
    List<Map<String, dynamic>> achievementDetails = [];
    try {
      final afterRes = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);
      final afterAchievements = afterRes
          .map((e) => e['achievement_id'] as String)
          .toSet();
      newlyUnlocked = computeUnlockedAchievements(
        beforeAchievements,
        afterAchievements,
      );

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

  Future<T?> _safeQuery<T>(Future<T> Function() query, String label) async {
    try {
      return await query();
    } catch (e) {
      debugPrint('[ReviewRepository] Error en $label: $e');
      return null;
    }
  }

  void _addNonEmptyUrls(Set<String> target, Iterable<dynamic> values) {
    for (final v in values) {
      final url = v?.toString();
      if (url != null && url.isNotEmpty) {
        target.add(url);
      }
    }
  }

  bool _willActivityRowBeDeleted(
    Map<String, dynamic> row, {
    required Set<String> deletedReviewIds,
    required String userId,
    required dynamic gameId,
    required bool deletesUserGame,
    String? fallbackReviewId,
    String? fallbackUserId,
    dynamic fallbackGameId,
  }) {
    final actionType = row['action_type'] as String?;
    final rowReviewId = row['review_id']?.toString() ?? fallbackReviewId;

    if (rowReviewId != null &&
        deletedReviewIds.contains(rowReviewId) &&
        (actionType == 'reviewed' || actionType == null)) {
      return true;
    }

    if (deletesUserGame && gameId != null) {
      final rowUserId = row['user_id']?.toString() ?? fallbackUserId;
      final rowGameId = row['game_id'] ?? fallbackGameId;
      if (rowUserId == userId && rowGameId?.toString() == gameId.toString()) {
        return actionType == 'status_change' ||
            actionType == 'reviewed' ||
            actionType == null;
      }
    }

    return false;
  }

  Future<Set<String>> _collectOrphanedCommentImageUrls({
    required Set<String> deletedReviewIds,
    required String userId,
    required dynamic gameId,
    required bool deletesUserGame,
    List<Map<String, dynamic>>? preloadedActivityByGame,
  }) async {
    final urls = <String>{};

    final singleReviewId = deletedReviewIds.length == 1
        ? deletedReviewIds.first
        : null;
    final reviewIdList = deletedReviewIds.toList();

    final activityByReviewsFuture = deletedReviewIds.isEmpty
        ? Future<List<Map<String, dynamic>>?>.value(const [])
        : _safeQuery<List<Map<String, dynamic>>>(() async {
            final base = _client
                .from('activity_feed')
                .select('post_id, action_type, user_id, game_id, review_id');
            return singleReviewId != null
                ? await base.eq('review_id', singleReviewId)
                : await base.inFilter('review_id', reviewIdList);
          }, 'activity_feed por review_id');

    final activityByGameFuture =
        (!deletesUserGame || gameId == null || preloadedActivityByGame != null)
        ? Future<List<Map<String, dynamic>>?>.value(
            preloadedActivityByGame ?? const [],
          )
        : _safeQuery<List<Map<String, dynamic>>>(
            () async => await _client
                .from('activity_feed')
                .select('post_id, action_type, user_id, game_id, review_id')
                .eq('user_id', userId)
                .eq('game_id', gameId),
            'activity_feed por user_id/game_id',
          );

    final implicitPostsFuture = deletedReviewIds.isEmpty
        ? Future<List<Map<String, dynamic>>?>.value(const [])
        : _safeQuery<List<Map<String, dynamic>>>(() async {
            final base = _client.from('feed_posts').select('id');
            return singleReviewId != null
                ? await base.eq('review_id', singleReviewId)
                : await base.inFilter('review_id', reviewIdList);
          }, 'feed_posts implícitos');

    final commentsByReviewsFuture = deletedReviewIds.isEmpty
        ? Future<List<Map<String, dynamic>>?>.value(const [])
        : _safeQuery<List<Map<String, dynamic>>>(() async {
            final base = _client.from('review_comments').select('image_url');
            return singleReviewId != null
                ? await base.eq('review_id', singleReviewId)
                : await base.inFilter('review_id', reviewIdList);
          }, 'review_comments por review_id');

    final batchResults = await Future.wait<List<Map<String, dynamic>>?>([
      activityByReviewsFuture,
      activityByGameFuture,
      implicitPostsFuture,
      commentsByReviewsFuture,
    ]);

    final activityByReviews = batchResults[0] ?? const [];
    final activityByGame = batchResults[1] ?? const [];
    final implicitPosts = batchResults[2] ?? const [];
    final commentsByReviews = batchResults[3] ?? const [];

    _addNonEmptyUrls(urls, commentsByReviews.map((c) => c['image_url']));

    final candidatePostIds = <String>{};
    for (final row in activityByReviews) {
      final pid = row['post_id'] as String?;
      if (pid != null &&
          pid.isNotEmpty &&
          _willActivityRowBeDeleted(
            row,
            deletedReviewIds: deletedReviewIds,
            userId: userId,
            gameId: gameId,
            deletesUserGame: deletesUserGame,
            fallbackReviewId: singleReviewId,
          )) {
        candidatePostIds.add(pid);
      }
    }

    if (deletesUserGame && gameId != null) {
      for (final row in activityByGame) {
        final pid = row['post_id'] as String?;
        if (pid != null &&
            pid.isNotEmpty &&
            _willActivityRowBeDeleted(
              row,
              deletedReviewIds: deletedReviewIds,
              userId: userId,
              gameId: gameId,
              deletesUserGame: true,
              fallbackUserId: userId,
              fallbackGameId: gameId,
            )) {
          candidatePostIds.add(pid);
        }
      }
    }

    final implicitPostIds = <String>{};
    for (final row in implicitPosts) {
      final pid = row['id'] as String?;
      if (pid != null && pid.isNotEmpty) {
        implicitPostIds.add(pid);
      }
    }

    // Only clean comment images for post_ids that have NO remaining events
    // in activity_feed outside the deleted review(s)/game. On query error,
    // fail safe and treat none as orphaned to preserve grouped post images.
    final orphanedPostIds = <String>{};
    if (candidatePostIds.isNotEmpty) {
      final sharedCheck = await _safeQuery<List<Map<String, dynamic>>>(
        () async => await _client
            .from('activity_feed')
            .select('post_id, action_type, user_id, game_id, review_id')
            .inFilter('post_id', candidatePostIds.toList()),
        'activity_feed compartidos por post_id',
      );

      if (sharedCheck != null) {
        final nonOrphanPostIds = <String>{};
        for (final row in sharedCheck) {
          final pid = row['post_id'] as String?;
          if (pid == null || pid.isEmpty) continue;
          if (!_willActivityRowBeDeleted(
            row,
            deletedReviewIds: deletedReviewIds,
            userId: userId,
            gameId: gameId,
            deletesUserGame: deletesUserGame,
          )) {
            nonOrphanPostIds.add(pid);
          }
        }
        orphanedPostIds.addAll(candidatePostIds.difference(nonOrphanPostIds));
      }
    }

    final postIdsToClean = <String>{...orphanedPostIds, ...implicitPostIds};
    if (postIdsToClean.isNotEmpty) {
      final commentsByPost = await _safeQuery<List<Map<String, dynamic>>>(
        () async => await _client
            .from('review_comments')
            .select('image_url')
            .inFilter('post_id', postIdsToClean.toList()),
        'review_comments por post_id',
      );
      if (commentsByPost != null) {
        _addNonEmptyUrls(urls, commentsByPost.map((c) => c['image_url']));
      }
    }

    return urls;
  }

  /// Elimina el juego de la biblioteca del usuario (user_games + reviews + imágenes).
  Future<void> deleteFromLibrary({
    required String userId,
    required dynamic gameId,
  }) async {
    // 1. Recopilar reseñas y eventos del juego en paralelo ANTES de borrar
    // `user_games` o `reviews`, evitando que los triggers cascading eliminen
    // `feed_posts` / `review_comments` antes de leer sus `image_url`.
    final initialResults = await Future.wait<List<Map<String, dynamic>>>([
      _client
          .from('reviews')
          .select('id, image_urls')
          .eq('user_id', userId)
          .eq('game_id', gameId),
      _safeQuery<List<Map<String, dynamic>>>(
        () async => await _client
            .from('activity_feed')
            .select('post_id, action_type, user_id, game_id, review_id')
            .eq('user_id', userId)
            .eq('game_id', gameId),
        'activity_feed por user_id/game_id',
      ).then((rows) => rows ?? const []),
    ]);

    final reviewsResponse = initialResults[0];
    final activityByGame = initialResults[1];

    final reviewIds = <String>{};
    final urlsToDelete = <String>{};

    for (final r in reviewsResponse) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) {
        reviewIds.add(id);
      }
      if (r['image_urls'] is List) {
        _addNonEmptyUrls(urlsToDelete, r['image_urls'] as List);
      }
    }

    final commentUrls = await _collectOrphanedCommentImageUrls(
      deletedReviewIds: reviewIds,
      userId: userId,
      gameId: gameId,
      deletesUserGame: true,
      preloadedActivityByGame: activityByGame,
    );
    urlsToDelete.addAll(commentUrls);

    // 2. Borrar imágenes de Storage antes de eliminar registros en BD
    if (urlsToDelete.isNotEmpty) {
      await _deleteImagesFromUrls(urlsToDelete.toList());
    }

    // 3. Borrar reseñas y finalmente user_games
    await _client
        .from('reviews')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId);

    await _client
        .from('user_games')
        .delete()
        .eq('user_id', userId)
        .eq('game_id', gameId);
  }

  /// Elimina una reseña y sus imágenes de Storage para un [userId] concreto.
  ///
  /// Protege las imágenes de comentarios de posts agrupados que sigan teniendo
  /// otros eventos en `activity_feed`. Devuelve `true` si ya no quedan más
  /// reseñas del usuario para ese juego y también se eliminó `user_games`.
  Future<bool> deleteReviewForUser({
    required String reviewId,
    required dynamic gameId,
    required String userId,
    List<String> currentImageUrls = const [],
  }) async {
    final urlsToDelete = <String>{};
    _addNonEmptyUrls(urlsToDelete, currentImageUrls);

    // Leer en paralelo las image_urls actuales y si esta reseña es la última
    // del juego para determinar si también caerá `user_games`.
    final metadataResults = await Future.wait<dynamic>([
      _safeQuery<Map<String, dynamic>?>(
        () async => await _client
            .from('reviews')
            .select('image_urls')
            .eq('id', reviewId)
            .maybeSingle(),
        'image_urls de la reseña al borrar',
      ),
      if (gameId != null)
        _safeQuery<List<Map<String, dynamic>>>(
          () async => await _client
              .from('reviews')
              .select('id')
              .eq('game_id', gameId)
              .eq('user_id', userId),
          'otras reseñas del juego al borrar',
        )
      else
        Future<List<Map<String, dynamic>>?>.value(null),
    ]);

    final dbReview = metadataResults[0] as Map<String, dynamic>?;
    if (dbReview != null && dbReview['image_urls'] is List) {
      _addNonEmptyUrls(urlsToDelete, dbReview['image_urls'] as List);
    }

    final otherReviews = metadataResults[1] as List<Map<String, dynamic>>?;
    final deletesUserGame =
        gameId != null &&
        otherReviews != null &&
        !otherReviews.any((r) => r['id']?.toString() != reviewId);

    final commentUrls = await _collectOrphanedCommentImageUrls(
      deletedReviewIds: {reviewId},
      userId: userId,
      gameId: gameId,
      deletesUserGame: deletesUserGame,
    );
    urlsToDelete.addAll(commentUrls);

    if (urlsToDelete.isNotEmpty) {
      await _deleteImagesFromUrls(urlsToDelete.toList());
      debugPrint(
        '[ReviewRepository] Eliminadas ${urlsToDelete.length} imágenes al borrar la reseña.',
      );
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

  /// Elimina una reseña individual y sus imágenes.
  /// Devuelve `true` si el usuario ya no tiene más reseñas para ese juego
  /// (para que el screen pueda actualizar `_inLibrary`).
  Future<bool> deleteReview({
    required String reviewId,
    required Review reviewData,
    required dynamic gameId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    return deleteReviewForUser(
      reviewId: reviewId,
      gameId: gameId,
      userId: userId,
      currentImageUrls: reviewData.imageUrls.map((e) => e.toString()).toList(),
    );
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
    final int parsedGameId = gameId is int
        ? gameId
        : int.parse(gameId.toString());

    List<String> friendIds;

    try {
      // Query optimizada usando la vista v_friend_pairs (Fase 3 DB)
      final pairsResult = await _client
          .from('v_friend_pairs')
          .select('friend_id')
          .eq('user_id', myId);

      friendIds = List<Map<String, dynamic>>.from(
        pairsResult,
      ).map((r) => r['friend_id'] as String).toList();
    } catch (e) {
      // Fallback: vista v_friend_pairs no aplicada todavía — usa el método original con 3 queries
      debugPrint(
        '[ReviewRepository] v_friend_pairs no disponible, usando fallback de friendships: $e',
      );
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
        ...List<Map<String, dynamic>>.from(
          sentFriends,
        ).map((f) => f['addressee_id'] as String),
        ...List<Map<String, dynamic>>.from(
          receivedFriends,
        ).map((f) => f['requester_id'] as String),
      ];
    }

    if (friendIds.isEmpty) return [];

    final result = await _client
        .from('user_games')
        .select(
          'status, rating, users!user_games_user_id_fkey(id, username, display_name, avatar_url)',
        )
        .eq('game_id', parsedGameId)
        .inFilter('user_id', friendIds);

    return List<Map<String, dynamic>>.from(result);
  }

  /// Devuelve la actividad del feed de un amigo para un juego concreto,
  /// incluyendo la reseña completa si existe.
  Future<
    ({List<Map<String, dynamic>> activities, Map<String, dynamic>? review})
  >
  fetchFriendActivityForGame({
    required String userId,
    required dynamic gameId,
  }) async {
    final int parsedGameId = gameId is int
        ? gameId
        : int.parse(gameId.toString());

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
            (act['content'] != null && act['content'].toString().isNotEmpty),
        orElse: () => activities.first,
      );
    }

    Map<String, dynamic>? review;
    if (bestActivity != null) {
      // IMPORTANTE: desde la migración
      // 20260814000000_fix_activity_feed_review_sync.sql, `review_id` es una
      // COLUMNA real de `activity_feed` (no solo un campo dentro de
      // `metadata`). El trigger `on_user_game_status_change` rellena esa
      // columna con la última reseña del usuario para ese juego, pero NO
      // añade `review_id` dentro de `metadata` (el metadata de un
      // 'status_change' solo contiene `{'status': ...}`). Por eso, leer
      // únicamente `metadata['review_id']` da siempre `null` para las
      // entradas 'status_change', que son justo las que se muestran en
      // "¿Quién lo tiene?". Hay que leer primero la columna directa; se deja
      // metadata como fallback solo por si hay filas antiguas donde solo
      // exista ahí (p. ej. entradas 'reviewed' muy viejas).
      final metadata = bestActivity['metadata'] as Map<String, dynamic>? ?? {};
      final reviewId = bestActivity['review_id'] ?? metadata['review_id'];
      try {
        final query = _client.from('reviews').select('*');

        final reviewResponse = await (reviewId != null
            ? query.eq('id', reviewId).maybeSingle()
            : query
                  .eq('user_id', userId)
                  .eq('game_id', parsedGameId)
                  .maybeSingle());

        if (reviewResponse != null) {
          final revMap = Map<String, dynamic>.from(reviewResponse);
          await _injectReviewPostStats([revMap]);
          review = revMap;
        }
      } catch (e) {
        debugPrint('[ReviewRepository] Error cargando reseña existente: $e');
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
  Future<List<Map<String, dynamic>>?> refreshStashReviews(
    dynamic gameId,
  ) async {
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
    final checkedAt = checkedAtRaw != null
        ? DateTime.tryParse(checkedAtRaw)
        : null;
    final isStale =
        checkedAt == null ||
        DateTime.now().toUtc().difference(checkedAt.toUtc()) > _statsMaxAge;

    return StashStatsResult(stats: row, needsFetch: isStale);
  }

  Future<Map<String, dynamic>?> refreshStashStats(dynamic igdbId) async {
    try {
      await _client.functions.invoke(
        'fetch-stash-game-stats',
        body: {'igdb_id': igdbId},
      );
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

  // ──────────────────────────────────────────────────────────────────
  // Social / Amigos
  // ──────────────────────────────────────────────────────────────────

  /// Devuelve la lista de amigos del usuario actual (id, username, avatar_url)
  /// para el selector de co-op en el modal de reseña.
  ///
  /// Usa [v_friend_pairs] como fuente principal. Si la vista no está disponible,
  /// hace fallback leyendo directamente de [friendships].
  ///
  /// Devuelve [List&lt;UserProfile&gt;] tipado — ya no Map&lt;String, dynamic&gt;.
  Future<List<UserProfile>> fetchFriendsForCoopPicker() async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return [];

      List<String> friendIds = [];

      try {
        // v_friend_pairs es una vista simétrica: devuelve ambos lados de la amistad.
        final pairs = await _client
            .from('v_friend_pairs')
            .select('friend_id')
            .eq('user_id', myId);
        friendIds = List<Map<String, dynamic>>.from(
          pairs,
        ).map((r) => r['friend_id'] as String).toList();
      } catch (e) {
        // Fallback: leer friendships directamente (bidireccional).
        debugPrint(
          '[ReviewRepository] v_friend_pairs no disponible en fetchFriendActivity, usando fallback: $e',
        );
        try {
          final sent = await _client
              .from('friendships')
              .select('addressee_id')
              .eq('requester_id', myId)
              .eq('status', 'accepted');
          final received = await _client
              .from('friendships')
              .select('requester_id')
              .eq('addressee_id', myId)
              .eq('status', 'accepted');
          friendIds = [
            ...List<Map<String, dynamic>>.from(
              sent,
            ).map((f) => f['addressee_id'] as String),
            ...List<Map<String, dynamic>>.from(
              received,
            ).map((f) => f['requester_id'] as String),
          ];
        } catch (e) {
          debugPrint('[ReviewRepository] Error en fallback de friendships: $e');
          return [];
        }
      }

      if (friendIds.isEmpty) return [];

      final users = await _client
          .from('users')
          .select('id, username, avatar_url, display_name')
          .inFilter('id', friendIds);

      return List<Map<String, dynamic>>.from(
        users,
      ).map(UserProfile.fromMap).toList();
    } catch (e) {
      debugPrint('[ReviewRepository] fetchFriendsForCoopPicker error: $e');
      return [];
    }
  }

  // ── Backfill ──────────────────────────────────────────────────────────────

  /// Persiste campos enriquecidos (cover_url, release_date, summary, developer,
  /// platforms, etc.) en la tabla `games` a través de `igdb-proxy`
  /// (`service_role`), evitando el bloqueo RLS de `UPDATE` en `public.games`.
  Future<void> backfillCoverUrl({
    required int igdbId,
    required Map<String, dynamic> enrichedData,
    required String? currentCoverUrl,
  }) async {
    if (_client.auth.currentUser == null) return;

    final missingCover = currentCoverUrl == null || currentCoverUrl.isEmpty;
    final enrichedPlatforms = _nonEmptyList(enrichedData['platforms']);
    final hasPlatforms = enrichedPlatforms != null;
    if ((!missingCover || _nonEmptyString(enrichedData['cover_url']) == null) &&
        !hasPlatforms) {
      return;
    }

    final coverUrl =
        _nonEmptyString(enrichedData['cover_url']) ??
        (!missingCover ? currentCoverUrl : null);
    final releaseDate = _nonEmptyString(
      enrichedData['release_date'],
    )?.split('T')[0];
    final summary = _nonEmptyString(enrichedData['summary']);
    final developer = _isValidDeveloper(enrichedData['developer'])
        ? enrichedData['developer']
        : null;
    final genres = _nonEmptyList(enrichedData['genres']);
    final themes = _nonEmptyList(enrichedData['themes']);
    final gameModes = _nonEmptyList(enrichedData['game_modes']);
    final perspectives = _nonEmptyList(enrichedData['player_perspectives']);
    final category = _resolveCatalogCategory(
      enrichedData,
      const {},
      fallback: null,
    );

    final payload = <String, dynamic>{
      'igdb_id': igdbId,
      'cover_url': ?coverUrl,
      'release_date': ?releaseDate,
      'summary': ?summary,
      'developer': ?developer,
      'platforms': ?enrichedPlatforms,
      'genres': ?genres,
      'themes': ?themes,
      'game_modes': ?gameModes,
      'player_perspectives': ?perspectives,
      'category': ?category,
    };
    if (payload.length <= 1) return;

    try {
      await _client.functions.invoke(
        'igdb-proxy',
        body: {'endpoint': 'backfill_game', 'game': payload},
      );
    } catch (e) {
      debugPrint('[ReviewRepository] Error en backfill de cover_url: $e');
    }
  }

  // ── Profile tab queries ────────────────────────────────────────────────────

  Future<void> _injectReviewPostStats(
    List<Map<String, dynamic>> reviews,
  ) async {
    final reviewIds = reviews
        .map((r) => r['id'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (reviewIds.isEmpty) return;

    try {
      final rows =
          await _client.rpc(
                'get_review_post_stats',
                params: {'p_review_ids': reviewIds},
              )
              as List;
      final statsByReviewId = {
        for (final r in rows.cast<Map<String, dynamic>>())
          if ((r['post_id'] as String?)?.isNotEmpty == true)
            r['review_id'] as String: PostStats.fromMap(r),
      };
      for (final r in reviews) {
        final id = r['id'] as String?;
        if (id != null && statsByReviewId.containsKey(id)) {
          r['_post'] = statsByReviewId[id];
        }
      }
    } catch (e) {
      debugPrint('[ReviewRepository] Error cargando stats de posts: $e');
    }
  }

  /// Fetches a page of reviews with written comments for the profile Reviews tab.
  /// Returns reviews that have a non-empty comment, ordered by created_at desc.
  Future<List<Map<String, dynamic>>> fetchProfileReviewsPage({
    required String userId,
    required int from,
    required int to,
    String searchQuery = '',
  }) async {
    var query = _client
        .from('reviews')
        .select('*, games!inner(*)')
        .eq('user_id', userId)
        .not('comment', 'is', null)
        .neq('comment', '');

    if (searchQuery.isNotEmpty) {
      query = query.ilike('games.title', '%$searchQuery%');
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(from, to);

    final list = List<Map<String, dynamic>>.from(
      res,
    ).where((r) => r['games'] != null).toList();
    await _injectReviewPostStats(list);
    return list;
  }

  /// Fetches a page of journal entries (playing/beaten/completed) for the Journal tab.
  Future<List<Map<String, dynamic>>> fetchJournalPage({
    required String userId,
    required String orderColumn,
    required int from,
    required int to,
    String searchQuery = '',
    int? year,
  }) async {
    var query = _client
        .from('reviews')
        .select('*, games!inner(*)')
        .eq('user_id', userId)
        .inFilter('status', ['playing', 'beaten', 'completed']);

    if (searchQuery.isNotEmpty) {
      query = query.ilike('games.title', '%$searchQuery%');
    }

    if (year != null) {
      query = query
          .gte(orderColumn, '$year-01-01T00:00:00.000Z')
          .lte(orderColumn, '$year-12-31T23:59:59.999Z');
    }

    final res = await query
        .order(orderColumn, ascending: false, nullsFirst: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(
      res,
    ).where((r) => r['games'] != null).toList();
  }

  /// Fetches available years from journal entries for the year filter.
  Future<List<int>> fetchJournalYears({
    required String userId,
    required String orderColumn,
  }) async {
    final res = await _client
        .from('reviews')
        .select(orderColumn)
        .eq('user_id', userId)
        .inFilter('status', ['playing', 'beaten', 'completed'])
        .not(orderColumn, 'is', null);

    final Set<int> years = {};
    for (final r in res) {
      final dateStr = r[orderColumn];
      if (dateStr != null) {
        try {
          final date = DateTime.parse(dateStr.toString());
          years.add(date.year);
        } catch (_) {}
      }
    }

    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }
}
