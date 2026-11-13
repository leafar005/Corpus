// lib/repositories/activity_repository.dart
//
// Acceso a datos para el feed de actividad y el detalle de reseñas.
//
// Centraliza todas las queries de Supabase que estaban inline en:
//   - ActivityScreen (_fetchActivity, _fetchFriendsStrip)
//   - ReviewDetailsScreen (_fetchInteractions, _toggleLike,
//     _submitComment, _deleteComment, _deleteReview, _fetchUpdatedReview, _fetchPartner)

import 'dart:math';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_stats.dart';
import '../utils/storage_utils.dart';
import '../utils/image_compressor.dart';
import 'review_repository.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Constantes de agrupación del feed
// ──────────────────────────────────────────────────────────────────────────────

/// Número máximo de tarjetas que se muestran en la tira horizontal de un
/// grupo antes de mostrar la tarjeta final "+N".
const int kMaxGroupedFeedCards = 8;

// ──────────────────────────────────────────────────────────────────────────────
// Value objects de retorno
// ──────────────────────────────────────────────────────────────────────────────

/// Resultado de cargar el feed de actividad paginado.
class ActivityFeedResult {
  const ActivityFeedResult({
    required this.mergedActivities,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<Map<String, dynamic>> mergedActivities;
  final bool hasMore;
  final int nextOffset;
}

/// Resultado de cargar la franja de amigos + solicitudes pendientes.
class FriendsStripResult {
  const FriendsStripResult({required this.friends, required this.pendingCount});

  final List<Map<String, dynamic>> friends;
  final int pendingCount;
}

/// Resultado de cargar likes + comentarios de una reseña.
class ReviewInteractionsResult {
  const ReviewInteractionsResult({
    required this.comments,
    required this.likesCount,
    required this.hasLiked,
  });

  final List<Map<String, dynamic>> comments;
  final int likesCount;
  final bool hasLiked;
}

// ──────────────────────────────────────────────────────────────────────────────
// Repositorio
// ──────────────────────────────────────────────────────────────────────────────

/// Acceso a datos para el feed de actividad y el detalle de reseñas.
class ActivityRepository {
  ActivityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ═══════════════════════════════════════════════════════════════════════════
  // Feed de actividad (ActivityScreen)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Carga una página del feed de actividad con paginación por offset.
  ///
  /// Orquesta tres queries:
  /// 1. Feed principal con join de usuarios y juegos.
  /// 2. Batch de reseñas referenciadas en el feed.
  /// 3. Batch de partners (user_games) para el indicador de cooperativo.
  ///
  /// La lógica de merge/agrupamiento de eventos (dentro de 24 h) se aplica
  /// sobre los resultados antes de devolverlos.
  Future<ActivityFeedResult> fetchActivityPage(
    int offset, {
    int limit = 30,
  }) async {
    final from = offset;
    final to = offset + limit - 1;

    // 1. Feed principal
    final response = await _client
        .from('activity_feed')
        .select('''
            *,
            users!activity_feed_user_id_fkey(id, username, display_name, avatar_url),
            games!activity_feed_game_id_fkey(igdb_id, title, cover_url)
          ''')
        .order('created_at', ascending: false)
        .range(from, to);

    final feedItems = List<Map<String, dynamic>>.from(response);

    final reviewIds = feedItems
        .map(
          (item) =>
              (item['review_id'] as String?) ??
              (item['metadata'] as Map?)?['review_id'] as String?,
        )
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> reviewsById = {};
    if (reviewIds.isNotEmpty) {
      try {
        final reviewsResp = await _client
            .from('reviews')
            .select('*')
            .inFilter('id', reviewIds);
        final reviewsList = List<Map<String, dynamic>>.from(reviewsResp);
        await ReviewRepository(client: _client).injectPartners(reviewsList);
        for (final r in reviewsList) {
          reviewsById[r['id'] as String] = r;
        }
      } catch (e) {
        debugPrint(
          '[ActivityRepository] Error enriqueciendo reviews del feed: $e',
        );
      }
    }

    // 2b. Estadísticas de posts y post vigente por review_id — batch paralelo
    await _enrichPostStatsAndCurrentPostIds(feedItems, reviewsById);

    // 3. Partners (user_games) — batch único
    final Map<String, List<dynamic>> partnersByUserGame = {};
    final userIds = feedItems
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final gameIds = feedItems
        .map((e) => e['game_id'])
        .where((e) => e != null)
        .toSet()
        .toList();

    if (userIds.isNotEmpty && gameIds.isNotEmpty) {
      try {
        final ugResp = await _client
            .from('user_games')
            .select('user_id, game_id, partner_ids')
            .inFilter('user_id', userIds)
            .inFilter('game_id', gameIds);

        final items = List<Map<String, dynamic>>.from(ugResp);
        final Set<String> allPartnerIds = {};
        for (var ug in items) {
          final ids = ug['partner_ids'];
          if (ids is List) allPartnerIds.addAll(ids.map((e) => e.toString()));
        }

        final usersData = allPartnerIds.isNotEmpty
            ? await _client
                  .from('users')
                  .select('id, username, avatar_url')
                  .inFilter('id', allPartnerIds.toList())
            : <dynamic>[];
        final userMap = {for (var u in usersData) u['id'] as String: u};

        for (final ug in items) {
          final ids = ug['partner_ids'];
          if (ids is List && ids.isNotEmpty) {
            partnersByUserGame['${ug['user_id']}_${ug['game_id']}'] = ids
                .map((id) => userMap[id.toString()])
                .where((u) => u != null)
                .toList();
          }
        }
      } catch (e) {
        debugPrint('[ActivityRepository] Error cargando partners del feed: $e');
      }
    }

    // 4. Enriquecer + merge (24h usuario+juego) + agrupación (60m usuario+estado)
    final mergedByGame = _mergeActivityItems(
      feedItems: feedItems,
      reviewsById: reviewsById,
      partnersByUserGame: partnersByUserGame,
    );
    final mergedActivities = _groupActivityItems(mergedByGame);

    return ActivityFeedResult(
      mergedActivities: mergedActivities,
      hasMore: feedItems.length == limit,
      nextOffset: offset + limit,
    );
  }

  /// Carga la franja de amigos (avatar strip) y el contador de solicitudes pendientes.
  Future<FriendsStripResult> fetchFriendsStrip(String userId) async {
    final results = await Future.wait([
      _client
          .from('friendships')
          .select(
            'friend:addressee_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name, xp)',
          )
          .eq('requester_id', userId)
          .eq('status', 'accepted'),
      _client
          .from('friendships')
          .select(
            'friend:requester_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name, xp)',
          )
          .eq('addressee_id', userId)
          .eq('status', 'accepted'),
      _client
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', userId)
          .eq('status', 'pending'),
    ]);

    final asSender = List<Map<String, dynamic>>.from(results[0]);
    final asReceiver = List<Map<String, dynamic>>.from(results[1]);
    final pending = results[2] as List;

    final friends = <Map<String, dynamic>>[
      ...asSender.map((e) => e['friend'] as Map<String, dynamic>),
      ...asReceiver.map((e) => e['friend'] as Map<String, dynamic>),
    ];

    return FriendsStripResult(friends: friends, pendingCount: pending.length);
  }

  /// Actividad reciente agrupada por usuario (para "historias" automáticas).
  ///
  /// Devuelve un mapa `userId → actividades` de los últimos [maxAge] días,
  /// ordenadas de más reciente a más antigua, con un máximo de [maxPerUser]
  /// entradas por usuario.
  Future<Map<String, List<Map<String, dynamic>>>> fetchRecentStoriesForUsers(
    List<String> userIds, {
    Duration maxAge = const Duration(days: 7),
    int maxPerUser = 15,
  }) async {
    if (userIds.isEmpty) return {};

    final since = DateTime.now().subtract(maxAge).toUtc().toIso8601String();

    final response = await _client
        .from('activity_feed')
        .select('''
            *,
            users!activity_feed_user_id_fkey(id, username, display_name, avatar_url),
            games!activity_feed_game_id_fkey(igdb_id, title, cover_url)
          ''')
        .inFilter('user_id', userIds)
        .gte('created_at', since)
        .order('created_at', ascending: false);

    final feedItems = List<Map<String, dynamic>>.from(response);

    final reviewIds = feedItems
        .map(
          (item) =>
              (item['review_id'] as String?) ??
              (item['metadata'] as Map?)?['review_id'] as String?,
        )
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> reviewsById = {};
    if (reviewIds.isNotEmpty) {
      try {
        final reviewsResp = await _client
            .from('reviews')
            .select('*')
            .inFilter('id', reviewIds);
        final reviewsList = List<Map<String, dynamic>>.from(reviewsResp);
        await ReviewRepository(client: _client).injectPartners(reviewsList);
        for (final r in reviewsList) {
          reviewsById[r['id'] as String] = r;
        }
      } catch (e) {
        debugPrint(
          '[ActivityRepository] Error enriqueciendo reviews de stories: $e',
        );
      }
    }

    await _enrichPostStatsAndCurrentPostIds(feedItems, reviewsById);

    // Partners (misma lógica que fetchActivityPage)
    final Map<String, List<dynamic>> partnersByUserGame = {};
    final storyUserIds = feedItems
        .map((e) => e['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final storyGameIds = feedItems
        .map((e) => e['game_id'])
        .where((e) => e != null)
        .toSet()
        .toList();

    if (storyUserIds.isNotEmpty && storyGameIds.isNotEmpty) {
      try {
        final ugResp = await _client
            .from('user_games')
            .select('user_id, game_id, partner_ids')
            .inFilter('user_id', storyUserIds)
            .inFilter('game_id', storyGameIds);

        final items = List<Map<String, dynamic>>.from(ugResp);
        final Set<String> allPartnerIds = {};
        for (var ug in items) {
          final ids = ug['partner_ids'];
          if (ids is List) allPartnerIds.addAll(ids.map((e) => e.toString()));
        }

        final usersData = allPartnerIds.isNotEmpty
            ? await _client
                  .from('users')
                  .select('id, username, avatar_url')
                  .inFilter('id', allPartnerIds.toList())
            : <dynamic>[];
        final userMap = {for (var u in usersData) u['id'] as String: u};

        for (final ug in items) {
          final ids = ug['partner_ids'];
          if (ids is List && ids.isNotEmpty) {
            partnersByUserGame['${ug['user_id']}_${ug['game_id']}'] = ids
                .map((id) => userMap[id.toString()])
                .where((u) => u != null)
                .toList();
          }
        }
      } catch (e) {
        debugPrint(
          '[ActivityRepository] Error cargando partners de stories: $e',
        );
      }
    }

    return groupAndMergeByUser(
      feedItems: feedItems,
      reviewsById: reviewsById,
      partnersByUserGame: partnersByUserGame,
      maxPerUser: maxPerUser,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Posts e interacciones (ReviewDetailsScreen y GroupedPostDetailsScreen)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enriquece [feedItems] con sus estadísticas `_post` y anota en cada entrada
  /// de [reviewsById] el `_current_post_id` vigente en servidor para evitar que
  /// un evento histórico (`status_change`) herede datos de una reseña posterior.
  Future<void> _enrichPostStatsAndCurrentPostIds(
    List<Map<String, dynamic>> feedItems,
    Map<String, Map<String, dynamic>> reviewsById,
  ) async {
    final postIds = feedItems
        .map((item) => item['post_id'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final reviewIds = reviewsById.keys.toList();

    final results = await Future.wait([
      fetchPostStats(postIds),
      fetchReviewPostStats(reviewIds),
    ]);
    final postStatsById = results[0];
    final reviewPostStatsById = results[1];

    for (final item in feedItems) {
      final pid = item['post_id'] as String?;
      if (pid != null && pid.isNotEmpty) {
        item['_post'] = postStatsById[pid] ?? PostStats(postId: pid);
      }
    }

    for (final entry in reviewPostStatsById.entries) {
      final rev = reviewsById[entry.key];
      if (rev != null) {
        rev['_current_post_id'] = entry.value.postId;
        rev['_post'] ??= entry.value;
      }
    }
  }

  /// Obtiene en batch las estadísticas de un conjunto de posts (`post_id`).
  Future<Map<String, PostStats>> fetchPostStats(List<String> postIds) async {
    final distinctIds = postIds.where((id) => id.isNotEmpty).toSet().toList();
    if (distinctIds.isEmpty) return {};
    try {
      final rows =
          await _client.rpc(
                'get_post_stats',
                params: {'p_post_ids': distinctIds},
              )
              as List;
      return {
        for (final r in rows.cast<Map<String, dynamic>>())
          r['post_id'] as String: PostStats.fromMap(r),
      };
    } catch (e) {
      debugPrint('[ActivityRepository] fetchPostStats error: $e');
      return {};
    }
  }

  /// Obtiene en batch las estadísticas del post vigente de cada reseña (`review_id`).
  Future<Map<String, PostStats>> fetchReviewPostStats(
    List<String> reviewIds,
  ) async {
    final distinctIds = reviewIds.where((id) => id.isNotEmpty).toSet().toList();
    if (distinctIds.isEmpty) return {};
    try {
      final rows =
          await _client.rpc(
                'get_review_post_stats',
                params: {'p_review_ids': distinctIds},
              )
              as List;
      return {
        for (final r in rows.cast<Map<String, dynamic>>())
          if ((r['post_id'] as String?)?.isNotEmpty == true)
            r['review_id'] as String: PostStats.fromMap(r),
      };
    } catch (e) {
      debugPrint('[ActivityRepository] fetchReviewPostStats error: $e');
      return {};
    }
  }

  /// Resuelve el `post_id` vigente para una reseña.
  /// Si [create] es `true`, crea un post implícito cuando la reseña aún no tiene post.
  Future<String?> resolvePostIdForReview(
    String reviewId, {
    bool create = false,
  }) async {
    final fn = create ? 'ensure_review_post' : 'current_post_for_review';
    final res = await _client.rpc(fn, params: {'p_review_id': reviewId});
    return res as String?;
  }

  /// Carga los ítems (`status_change`) de un post del feed, con datos de usuario y juego.
  Future<List<Map<String, dynamic>>> fetchPostItems(String postId) async {
    final response = await _client
        .from('activity_feed')
        .select('''
            *,
            users!activity_feed_user_id_fkey(id, username, display_name, avatar_url),
            games!activity_feed_game_id_fkey(igdb_id, title, cover_url)
          ''')
        .eq('post_id', postId)
        .eq('action_type', 'status_change')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Carga en paralelo los likes y comentarios de un post (`postId`).
  Future<ReviewInteractionsResult> fetchInteractions(
    String postId,
    String currentUserId,
  ) async {
    final results = await Future.wait([
      _client.from('review_likes').select('user_id').eq('post_id', postId),
      _client
          .from('review_comments')
          .select('*, users(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true),
    ]);

    final likes = results[0] as List;
    final comments = List<Map<String, dynamic>>.from(results[1]);

    return ReviewInteractionsResult(
      comments: comments,
      likesCount: likes.length,
      hasLiked: likes.any((like) => like['user_id'] == currentUserId),
    );
  }

  /// Añade o elimina un like del usuario en el post indicado (`postId`).
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _client
          .from('review_likes')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } else {
      await _client.from('review_likes').insert({
        'user_id': userId,
        'post_id': postId,
      });
    }
  }

  /// Inserta un comentario en un post (`postId`), subiendo la imagen si se proporciona.
  Future<void> submitComment({
    required String postId,
    required String userId,
    required String? content,
    required XFile? commentImage,
    required Map<String, dynamic>? attachedGame,
    String? parentCommentId,
  }) async {
    String? imageUrl;

    if (commentImage != null) {
      final bytes = await ImageCompressor.compressImage(commentImage);
      if (bytes == null) throw Exception('Image compression failed');
      final ext = commentImage.name.split('.').last;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.$ext';
      final path = '$userId/$fileName';

      await _client.storage.from('user_uploads').uploadBinary(path, bytes);
      imageUrl = _client.storage.from('user_uploads').getPublicUrl(path);
    }

    await _client.from('review_comments').insert({
      'user_id': userId,
      'post_id': postId,
      'content': content?.isNotEmpty == true ? content : null,
      'image_url': imageUrl,
      'attached_game': attachedGame,
      'parent_comment_id': ?parentCommentId,
    });
  }

  /// Elimina un comentario, borrando también su imagen de Storage si la tiene.
  Future<void> deleteComment({
    required String commentId,
    required String? imageUrl,
  }) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await StorageUtils.deleteImagesFromUrls([imageUrl]);
    }
    await _client.from('review_comments').delete().eq('id', commentId);
  }

  /// Elimina una reseña y sus imágenes de Storage.
  /// Si era la última reseña del usuario para ese juego, también elimina
  /// la entrada de `user_games`.
  Future<void> deleteReview({
    required String reviewId,
    required int gameId,
    required String userId,
    required List<String> currentImageUrls,
  }) async {
    // Recoger todas las URLs de imágenes (reseña + comentarios)
    final urlsToDelete = <String>{...currentImageUrls};

    try {
      final dbReview = await _client
          .from('reviews')
          .select('image_urls')
          .eq('id', reviewId)
          .maybeSingle();
      if (dbReview != null && dbReview['image_urls'] != null) {
        urlsToDelete.addAll(
          (dbReview['image_urls'] as List).map((e) => e.toString()),
        );
      }
    } catch (e) {
      debugPrint(
        '[ActivityRepository] Error recogiendo image_urls de la reseña al borrar: $e',
      );
    }

    try {
      final postIdsForReview = <String>{};
      final feedPostsResp = await _client
          .from('activity_feed')
          .select('post_id')
          .eq('review_id', reviewId);
      for (final r in feedPostsResp) {
        final pid = r['post_id'] as String?;
        if (pid != null && pid.isNotEmpty) postIdsForReview.add(pid);
      }
      final implicitPostsResp = await _client
          .from('feed_posts')
          .select('id')
          .eq('review_id', reviewId);
      for (final r in implicitPostsResp) {
        final pid = r['id'] as String?;
        if (pid != null && pid.isNotEmpty) postIdsForReview.add(pid);
      }

      if (postIdsForReview.isNotEmpty) {
        final commentsByPost = await _client
            .from('review_comments')
            .select('image_url')
            .inFilter('post_id', postIdsForReview.toList());
        for (final c in commentsByPost) {
          if (c['image_url'] != null)
            urlsToDelete.add(c['image_url'] as String);
        }
      }

      final commentsResp = await _client
          .from('review_comments')
          .select('image_url')
          .eq('review_id', reviewId);
      for (final c in commentsResp) {
        if (c['image_url'] != null) urlsToDelete.add(c['image_url'] as String);
      }
    } catch (e) {
      debugPrint(
        '[ActivityRepository] Error recogiendo imágenes de comentarios al borrar reseña: $e',
      );
    }

    if (urlsToDelete.isNotEmpty) {
      await StorageUtils.deleteImagesFromUrls(urlsToDelete.toList());
    }

    await _client.from('reviews').delete().eq('id', reviewId);

    // Si era la última reseña del usuario para este juego → eliminar user_game
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
    }
  }

  /// Recarga la reseña actualizada después de editarla, preservando el JOIN de usuario.
  Future<Map<String, dynamic>?> fetchUpdatedReview(
    String reviewId, {
    Map<String, dynamic>? fallbackUserData,
  }) async {
    final updated = await _client
        .from('reviews')
        .select('*, users!reviews_user_id_users_fkey(*)')
        .eq('id', reviewId)
        .maybeSingle();

    if (updated == null) return null;

    final result = Map<String, dynamic>.from(updated);
    // Preservar datos del usuario si el JOIN no devuelve nada
    if (result['users'] == null && fallbackUserData != null) {
      result['users'] = fallbackUserData;
    }
    await ReviewRepository(client: _client).injectPartners([result]);
    return result;
  }

  /// Obtiene los copilotes (partners) de una partida en `user_games`.
  Future<List<Map<String, dynamic>>> fetchPartners({
    required String userId,
    required int gameId,
  }) async {
    try {
      final row = await _client
          .from('user_games')
          .select('partner_ids')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .maybeSingle();

      if (row == null) return [];
      final ids = row['partner_ids'];
      if (ids is! List || ids.isEmpty) return [];

      final usersData = await _client
          .from('users')
          .select('id, username, avatar_url')
          .inFilter('id', ids.map((e) => e.toString()).toList());

      return List<Map<String, dynamic>>.from(usersData);
    } catch (e) {
      debugPrint('[ActivityRepository] fetchPartners error: $e');
      return [];
    }
  }

  /// Obtiene la reseña más reciente de un usuario para un juego concreto.
  /// Útil para la navegación desde eventos de "status_change" antiguos en el feed.
  Future<Map<String, dynamic>?> fetchLatestReviewForUserAndGame(
    String userId,
    int gameId,
  ) async {
    try {
      final resp = await _client
          .from('reviews')
          .select('*')
          .eq('user_id', userId)
          .eq('game_id', gameId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (resp != null) {
        final reviewsList = [Map<String, dynamic>.from(resp)];
        await ReviewRepository(client: _client).injectPartners(reviewsList);
        final rev = reviewsList.first;
        final revId = rev['id'] as String?;
        if (revId != null) {
          final stats = await fetchReviewPostStats([revId]);
          if (stats.containsKey(revId)) {
            rev['_post'] = stats[revId];
          }
        }
        return rev;
      }
    } catch (e) {
      debugPrint(
        '[ActivityRepository] fetchLatestReviewForUserAndGame error: $e',
      );
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers de lógica pura (testeables sin Supabase)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enriquece el feed con datos de reseñas y partners, y agrupa eventos
  /// del mismo usuario + juego dentro de una ventana de 24 horas.
  ///
  /// Conserva el `post_id` y `_post` del evento más reciente (`prev`) y guarda
  /// en `_merged_post_ids` / `_merged_posts` los posts anteriores absorbidos.
  ///
  /// Esta lógica es puramente de presentación — no hace queries.
  static List<Map<String, dynamic>> mergeActivityItems({
    required List<Map<String, dynamic>> feedItems,
    required Map<String, Map<String, dynamic>> reviewsById,
    required Map<String, List<dynamic>> partnersByUserGame,
  }) => _mergeActivityItems(
    feedItems: feedItems,
    reviewsById: reviewsById,
    partnersByUserGame: partnersByUserGame,
  );

  static void _recordMergedOlderPost(
    Map<String, dynamic> target,
    Map<String, dynamic> olderItem,
  ) {
    final olderPostId = olderItem['post_id'] as String?;
    if (olderPostId == null ||
        olderPostId.isEmpty ||
        olderPostId == target['post_id']) {
      return;
    }
    final mergedIds = List<String>.from(
      (target['_merged_post_ids'] as List?)?.whereType<String>() ?? const [],
    );
    if (!mergedIds.contains(olderPostId)) {
      mergedIds.add(olderPostId);
      target['_merged_post_ids'] = mergedIds;
    }

    final olderStats = PostStats.fromDynamic(
      olderItem['_post'],
      fallbackPostId: olderPostId,
    );
    if (olderStats != null) {
      final mergedPosts = List<PostStats>.from(
        (target['_merged_posts'] as List?)?.whereType<PostStats>() ?? const [],
      );
      if (!mergedPosts.any((p) => p.postId == olderPostId)) {
        mergedPosts.add(olderStats);
        target['_merged_posts'] = mergedPosts;
      }
    }
  }

  /// Determina si un evento `status_change` pertenece a un post histórico que
  /// ya fue superado por otro estado o reseña posterior de la misma `review_id`.
  static bool _isSupersededStatusPost(
    Map<String, dynamic> item,
    Map<String, dynamic> review,
  ) {
    if (item['action_type'] != 'status_change') return false;

    final itemPostId = item['post_id'] as String?;
    final currentReviewPostId =
        (review['_current_post_id'] as String?) ??
        PostStats.fromDynamic(review['_post'])?.postId;
    if (itemPostId != null &&
        itemPostId.isNotEmpty &&
        currentReviewPostId != null &&
        currentReviewPostId.isNotEmpty &&
        itemPostId != currentReviewPostId) {
      return true;
    }

    final itemStatus = (item['metadata'] as Map?)?['status'] as String?;
    final reviewStatus = review['status'] as String?;
    if (itemStatus != null &&
        itemStatus.isNotEmpty &&
        reviewStatus != null &&
        reviewStatus.isNotEmpty &&
        itemStatus != reviewStatus) {
      return true;
    }

    return false;
  }

  static List<Map<String, dynamic>> _mergeActivityItems({
    required List<Map<String, dynamic>> feedItems,
    required Map<String, Map<String, dynamic>> reviewsById,
    required Map<String, List<dynamic>> partnersByUserGame,
  }) {
    final merged = <Map<String, dynamic>>[];

    for (var rawItem in feedItems) {
      var item = Map<String, dynamic>.from(rawItem);

      // Resolver reseña referenciada y descartarla en status_change históricos
      // que pertenecen a un post/estado anterior ya superado.
      final reviewId =
          (item['review_id'] as String?) ??
          (item['metadata'] as Map?)?['review_id'] as String?;
      final reviewMap = reviewId != null ? reviewsById[reviewId] : null;
      final isSuperseded =
          reviewMap != null && _isSupersededStatusPost(item, reviewMap);

      // Inyectar partners (no en posts históricos ya superados)
      final uId = item['user_id'];
      final gId = item['game_id'];
      if (!isSuperseded && uId != null && gId != null) {
        item['_partners'] = partnersByUserGame['${uId}_$gId'];
      }

      // Inyectar datos de reseña si siguen correspondiendo a este post
      if (reviewMap != null && !isSuperseded) {
        item['_review'] = reviewMap;
      }

      // Intentar fusionar con un evento reciente del mismo usuario y juego
      final userId = item['user_id'];
      final gameId = item['game_id'];
      final type = item['action_type'];
      final dateStr = item['created_at'];

      bool wasMerged = false;
      if (userId != null && gameId != null && dateStr != null) {
        final date = DateTime.parse(dateStr as String);
        for (int i = merged.length - 1; i >= 0 && i >= merged.length - 4; i--) {
          final prev = merged[i];
          if (prev['user_id'] == userId && prev['game_id'] == gameId) {
            final prevDate = DateTime.parse(prev['created_at'] as String);
            if (date.difference(prevDate).abs().inHours < 24) {
              if (type == 'status_change' &&
                  prev['action_type'] == 'reviewed') {
                // Solo adoptar el status_change si comparten post_id (o si prev no tenía post_id)
                // y el status_change no pertenece a un estado anterior ya superado.
                final prevPostId = prev['post_id'] as String?;
                final itemPostId = item['post_id'] as String?;
                final prevReview = prev['_review'] as Map<String, dynamic>?;
                final itemSuperseded =
                    prevReview != null &&
                    _isSupersededStatusPost(item, prevReview);
                if (!itemSuperseded &&
                    (prevPostId == null ||
                        itemPostId == null ||
                        prevPostId == itemPostId)) {
                  prev['action_type'] = 'status_change';
                  final prevMeta = Map<String, dynamic>.from(
                    prev['metadata'] as Map? ?? const {},
                  );
                  prevMeta['status'] =
                      (item['metadata'] as Map? ?? {})['status'];
                  prev['metadata'] = prevMeta;
                  prev['post_id'] ??= itemPostId;
                  prev['_post'] ??= item['_post'];
                } else {
                  _recordMergedOlderPost(prev, item);
                }
                wasMerged = true;
                break;
              } else if (type == 'reviewed' &&
                  prev['action_type'] == 'status_change') {
                final prevPostId = prev['post_id'] as String?;
                final itemPostId = item['post_id'] as String?;
                final itemReview = item['_review'] as Map<String, dynamic>?;
                final prevSuperseded =
                    itemReview != null &&
                    _isSupersededStatusPost(prev, itemReview);
                if (!prevSuperseded &&
                    (prevPostId == null ||
                        itemPostId == null ||
                        prevPostId == itemPostId)) {
                  prev['_review'] = item['_review'];
                  prev['post_id'] ??= itemPostId;
                  prev['_post'] ??= item['_post'];
                } else {
                  _recordMergedOlderPost(prev, item);
                }
                wasMerged = true;
                break;
              } else if (type == 'status_change' &&
                  prev['action_type'] == 'status_change') {
                // prev es el evento más reciente: conserva su post_id y _post.
                // Guardamos el post anterior en _merged_post_ids / _merged_posts.
                _recordMergedOlderPost(prev, item);
                wasMerged = true;
                break;
              }
            }
          }
        }
      }

      if (!wasMerged) merged.add(item);
    }

    return merged;
  }

  /// Devuelve `true` si la actividad representa una publicación agrupada
  /// de 2 o más juegos con el mismo `post_id`.
  static bool isGroupedActivity(Map<String, dynamic> activity) {
    final grouped = activity['_grouped_items'];
    return activity['_is_group'] == true &&
        grouped is List &&
        grouped.length > 1;
  }

  /// Extrae todos los IDs de `activity_feed` asociados a una entrada
  /// (1 ID para entradas individuales, N IDs para publicaciones agrupadas).
  static List<String> activityIdsOf(Map<String, dynamic> activity) {
    final ids = activity['_activity_ids'];
    if (ids is List && ids.isNotEmpty) {
      return ids.whereType<String>().toList();
    }
    final grouped = activity['_grouped_items'];
    if (grouped is List && grouped.isNotEmpty) {
      return grouped
          .whereType<Map<String, dynamic>>()
          .map((e) => e['id'] as String?)
          .whereType<String>()
          .toList();
    }
    final singleId = activity['id'] as String?;
    return singleId != null ? [singleId] : const [];
  }

  /// Agrupa entradas `status_change` que compartan el mismo `post_id` asignado
  /// por la base de datos.
  ///
  /// Se ejecuta DESPUÉS de `_mergeActivityItems`. Si recibe elementos que ya
  /// fueron agrupados previamente (p. ej. al paginar o al incorporar eventos
  /// Realtime sobre la lista acumulada), los expande primero para no partir
  /// grupos en límites de página.
  static List<Map<String, dynamic>> groupActivityItems(
    List<Map<String, dynamic>> items,
  ) => _groupActivityItems(items);

  static List<Map<String, dynamic>> _groupActivityItems(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return [];

    // 1. Desarmar grupos previos (para paginación / Realtime sobre lista acumulada)
    //    y deduplicar por id de actividad.
    final flattened = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final item in items) {
      if (item['_is_group'] == true && item['_grouped_items'] is List) {
        final parentPost = item['_post'];
        for (final sub in (item['_grouped_items'] as List)) {
          if (sub is Map<String, dynamic>) {
            final id = sub['id'] as String?;
            if (id != null && !seenIds.add(id)) continue;
            if (parentPost != null && sub['_post'] == null) {
              final copy = Map<String, dynamic>.from(sub);
              copy['_post'] = parentPost;
              flattened.add(copy);
            } else {
              flattened.add(sub);
            }
          }
        }
      } else {
        final id = item['id'] as String?;
        if (id != null && !seenIds.add(id)) continue;
        flattened.add(item);
      }
    }

    // 2. Ordenar siempre por created_at descendente (más reciente primero),
    //    preservando el orden relativo en caso de empate.
    final indexed =
        List<({int index, Map<String, dynamic> item, DateTime? date})>.generate(
          flattened.length,
          (i) {
            final rawDate = flattened[i]['created_at'] as String?;
            final parsed = rawDate != null ? DateTime.tryParse(rawDate) : null;
            return (index: i, item: flattened[i], date: parsed);
          },
        );

    indexed.sort((a, b) {
      if (a.date != null && b.date != null) {
        final cmp = b.date!.compareTo(a.date!);
        if (cmp != 0) return cmp;
      } else if (a.date != null) {
        return -1;
      } else if (b.date != null) {
        return 1;
      }
      return a.index.compareTo(b.index);
    });

    // 3. Agrupar por post_id compartido en eventos status_change.
    final slots = <_ActivityFeedSlot>[];
    final byPostId = <String, _ActivityGroupBuilder>{};

    for (final entry in indexed) {
      final item = entry.item;
      final postId = item['post_id'] as String?;
      if (item['action_type'] != 'status_change' ||
          postId == null ||
          postId.isEmpty) {
        slots.add(_ActivityFeedSlot.single(item));
        continue;
      }

      final existing = byPostId[postId];
      if (existing != null) {
        existing.add(item);
      } else {
        final group = _ActivityGroupBuilder(postId: postId, firstItem: item);
        byPostId[postId] = group;
        slots.add(_ActivityFeedSlot.group(group));
      }
    }

    // 4. Materializar lista final: posts con 1 juego quedan como tarjeta simple;
    //    posts con >= 2 juegos producen una tarjeta agrupada con su post_id y _post.
    return slots.map((slot) => slot.build()).toList();
  }

  /// IDs de activity_feed que el usuario ya ha visto, limitado a [activityIds]
  /// para no traer todo el historial de vistas.
  Future<Set<String>> fetchViewedStoryIds({
    required String userId,
    required List<String> activityIds,
  }) async {
    if (activityIds.isEmpty) return {};

    final response = await _client
        .from('story_views')
        .select('activity_id')
        .eq('user_id', userId)
        .inFilter('activity_id', activityIds);

    return (response as List)
        .map((row) => row['activity_id'] as String)
        .toSet();
  }

  /// Marca un slide de historia como visto (idempotente).
  Future<void> markStoryViewed({
    required String userId,
    required String activityId,
  }) async {
    await markStoriesViewed(userId: userId, activityIds: [activityId]);
  }

  /// Marca uno o varios activity IDs de un slide (individual o agrupado)
  /// como vistos en `story_views` (idempotente).
  Future<void> markStoriesViewed({
    required String userId,
    required List<String> activityIds,
  }) async {
    if (activityIds.isEmpty) return;
    final rows = activityIds
        .map((id) => {'user_id': userId, 'activity_id': id})
        .toList();
    await _client
        .from('story_views')
        .upsert(rows, onConflict: 'user_id,activity_id');
  }

  // ── Helpers puros (testeables) ──────────────────────────────

  /// Devuelve `true` si todos los activity IDs del slide [activity] están en
  /// [viewedIds]. Para un grupo, requiere que todos sus IDs hayan sido vistos.
  static bool isActivitySeen(
    Map<String, dynamic> activity,
    Set<String> viewedIds,
  ) {
    final ids = activityIdsOf(activity);
    if (ids.isEmpty) return viewedIds.contains(activity['id']);
    return ids.every(viewedIds.contains);
  }

  /// Índice del primer slide no visto dentro de una lista de actividades
  /// ordenada de más antigua a más reciente. 0 si todas están vistas.
  static int firstUnseenIndex(
    List<Map<String, dynamic>> activities,
    Set<String> viewedIds,
  ) {
    final idx = activities.indexWhere((a) => !isActivitySeen(a, viewedIds));
    return idx == -1 ? 0 : idx;
  }

  /// true si el grupo tiene algún slide sin ver.
  static bool groupHasUnseenStory(
    List<Map<String, dynamic>> activities,
    Set<String> viewedIds,
  ) => activities.any((a) => !isActivitySeen(a, viewedIds));

  /// Ordena la franja de amigos para el "story bar" (estilo Instagram).
  ///
  /// Orden de prioridad (de mayor a menor):
  ///   1. Amigos con historia SIN ver
  ///   2. Amigos con historia YA vista
  ///   3. Amigos jugando ahora mismo (sin historia)
  ///   4. Amigos online (sin historia)
  ///   5. Resto
  ///
  /// Los empates dentro de un mismo nivel se resuelven por XP descendente y,
  /// si persiste el empate, alfabéticamente por display_name/username.
  static List<Map<String, dynamic>> sortFriendsStrip({
    required List<Map<String, dynamic>> friends,
    required Map<String, List<Map<String, dynamic>>> userStories,
    required Set<String> onlineUserIds,
    required Set<String> viewedStoryIds,
  }) {
    int scoreFor(Map<String, dynamic> f) {
      final id = f['id'] as String?;
      final stories = id != null ? userStories[id] : null;
      final hasStory = stories != null && stories.isNotEmpty;
      final hasUnseenStory =
          hasStory && groupHasUnseenStory(stories, viewedStoryIds);
      final isPlaying =
          f['currently_playing_appid'] != null &&
          f['currently_playing_name'] != null;
      final isOnline = id != null && onlineUserIds.contains(id);

      final storyScore = hasUnseenStory ? 8 : (hasStory ? 4 : 0);
      return storyScore + (isPlaying ? 2 : 0) + (isOnline ? 1 : 0);
    }

    final sorted = List<Map<String, dynamic>>.from(friends);
    sorted.sort((a, b) {
      final aScore = scoreFor(a);
      final bScore = scoreFor(b);
      if (aScore != bScore) return bScore.compareTo(aScore);

      final aXp = (a['xp'] as num?)?.toInt() ?? 0;
      final bXp = (b['xp'] as num?)?.toInt() ?? 0;
      if (aXp != bXp) return bXp.compareTo(aXp);

      final aName =
          (a['display_name'] as String? ?? a['username'] as String? ?? '')
              .toLowerCase();
      final bName =
          (b['display_name'] as String? ?? b['username'] as String? ?? '')
              .toLowerCase();
      return aName.compareTo(bName);
    });

    return sorted;
  }

  /// Agrupa por usuario y fusiona duplicados dentro de cada grupo — lógica
  /// pura usada por `fetchRecentStoriesForUsers` (testeable sin Supabase).
  static Map<String, List<Map<String, dynamic>>> groupAndMergeByUser({
    required List<Map<String, dynamic>> feedItems,
    required Map<String, Map<String, dynamic>> reviewsById,
    required Map<String, List<dynamic>> partnersByUserGame,
    required int maxPerUser,
  }) {
    final Map<String, List<Map<String, dynamic>>> byUser = {};
    for (final item in feedItems) {
      final userId = item['user_id'] as String?;
      if (userId == null) continue;
      byUser.putIfAbsent(userId, () => []).add(item);
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in byUser.entries) {
      final mergedByGame = _mergeActivityItems(
        feedItems: entry.value,
        reviewsById: reviewsById,
        partnersByUserGame: partnersByUserGame,
      );
      final mergedForUser = _groupActivityItems(mergedByGame);
      grouped[entry.key] = mergedForUser
          .take(maxPerUser)
          .toList()
          .reversed
          .toList();
    }
    return grouped;
  }
}

class _ActivityFeedSlot {
  _ActivityFeedSlot.single(Map<String, dynamic> this.singleItem)
    : groupBuilder = null;

  _ActivityFeedSlot.group(_ActivityGroupBuilder this.groupBuilder)
    : singleItem = null;

  final Map<String, dynamic>? singleItem;
  final _ActivityGroupBuilder? groupBuilder;

  Map<String, dynamic> build() {
    if (singleItem != null) return singleItem!;
    return groupBuilder!.build();
  }
}

class _ActivityGroupBuilder {
  _ActivityGroupBuilder({
    required this.postId,
    required Map<String, dynamic> firstItem,
  }) : items = [firstItem];

  final String postId;
  final List<Map<String, dynamic>> items;

  void add(Map<String, dynamic> item) {
    items.add(item);
  }

  Map<String, dynamic> build() {
    if (items.length < 2) return items.first;

    final first = items.first;
    final userId = first['user_id'] as String?;
    final firstMeta = first['metadata'] as Map?;
    final status = firstMeta?['status'] as String?;
    final activityIds = <String>[];
    final games = <Map<String, dynamic>>[];
    final seenGameIds = <dynamic>{};

    for (final it in items) {
      final id = it['id'] as String?;
      if (id != null) activityIds.add(id);

      final rawGameMap = it['games'] as Map<String, dynamic>?;
      final gId = it['game_id'] ?? rawGameMap?['igdb_id'] ?? rawGameMap?['id'];
      if (gId != null && !seenGameIds.add(gId)) {
        continue;
      }

      final gameMap = <String, dynamic>{
        if (gId != null) 'igdb_id': gId,
        'title': 'Juego desconocido',
        'review_id': it['review_id'] ?? (it['metadata'] as Map?)?['review_id'],
        ...?rawGameMap,
      };
      games.add(gameMap);
    }

    if (games.length < 2) return first;

    return <String, dynamic>{
      'id': first['id'],
      'post_id': postId,
      '_post': first['_post'],
      'user_id': userId,
      'action_type': 'status_change',
      'created_at': first['created_at'],
      'users': first['users'],
      'games': first['games'],
      'game_id': first['game_id'],
      'metadata': <String, dynamic>{
        if (firstMeta != null) ...Map<String, dynamic>.from(firstMeta),
        if (status != null) 'status': status,
      },
      '_is_group': true,
      '_grouped_items': List<Map<String, dynamic>>.unmodifiable(items),
      '_activity_ids': List<String>.unmodifiable(activityIds),
      '_games': List<Map<String, dynamic>>.unmodifiable(games),
    };
  }
}
