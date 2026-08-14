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
import '../utils/storage_utils.dart';
import '../utils/image_compressor.dart';
import 'review_repository.dart';

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
  Future<ActivityFeedResult> fetchActivityPage(int offset, {int limit = 30}) async {
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

    // 2. Reseñas referenciadas — batch único
    final reviewIds = feedItems
        .where((item) => item['action_type'] == 'reviewed')
        .map((item) => (item['metadata'] as Map?)?['review_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> reviewsById = {};
    if (reviewIds.isNotEmpty) {
      try {
        final reviewsResp = await _client
            .from('reviews')
            .select('*, review_likes(user_id), review_comments(id)')
            .inFilter('id', reviewIds);
        final reviewsList = List<Map<String, dynamic>>.from(reviewsResp);
        await ReviewRepository(client: _client).injectPartners(reviewsList);
        for (final r in reviewsList) {
          reviewsById[r['id'] as String] = r;
        }
      } catch (_) {}
    }

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
      } catch (_) {}
    }

    // 4. Enriquecer + merge — lógica de presentación pura (sin queries)
    final mergedActivities = _mergeActivityItems(
      feedItems: feedItems,
      reviewsById: reviewsById,
      partnersByUserGame: partnersByUserGame,
    );

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
            'friend:addressee_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name)',
          )
          .eq('requester_id', userId)
          .eq('status', 'accepted'),
      _client
          .from('friendships')
          .select(
            'friend:requester_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name)',
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

    // Enriquecer reseñas referenciadas
    final reviewIds = feedItems
        .where((item) => item['action_type'] == 'reviewed')
        .map((item) => (item['metadata'] as Map?)?['review_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> reviewsById = {};
    if (reviewIds.isNotEmpty) {
      try {
        final reviewsResp = await _client
            .from('reviews')
            .select(
              '*, review_likes(user_id), '
              'review_comments(id, content, created_at, '
              'users(id, username, display_name, avatar_url))',
            )
            .inFilter('id', reviewIds);
        final reviewsList = List<Map<String, dynamic>>.from(reviewsResp);
        await ReviewRepository(client: _client).injectPartners(reviewsList);
        for (final r in reviewsList) {
          reviewsById[r['id'] as String] = r;
        }
      } catch (_) {}
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in feedItems) {
      final userId = item['user_id'] as String?;
      if (userId == null) continue;

      final list = grouped.putIfAbsent(userId, () => []);
      if (list.length >= maxPerUser) continue;

      final enriched = Map<String, dynamic>.from(item);
      if (item['action_type'] == 'reviewed') {
        final reviewId =
            (item['metadata'] as Map?)?['review_id'] as String?;
        if (reviewId != null && reviewsById.containsKey(reviewId)) {
          enriched['_review'] = reviewsById[reviewId];
        }
      }
      list.add(enriched);
    }

    return grouped;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Detalle de reseña (ReviewDetailsScreen)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Carga en paralelo los likes y comentarios de una reseña.
  Future<ReviewInteractionsResult> fetchInteractions(
    String reviewId,
    String currentUserId,
  ) async {
    final results = await Future.wait([
      _client.from('review_likes').select('user_id').eq('review_id', reviewId),
      _client
          .from('review_comments')
          .select('*, users(*)')
          .eq('review_id', reviewId)
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

  /// Añade o elimina un like del usuario en la reseña indicada.
  Future<void> toggleLike({
    required String reviewId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _client
          .from('review_likes')
          .delete()
          .eq('user_id', userId)
          .eq('review_id', reviewId);
    } else {
      await _client.from('review_likes').insert({
        'user_id': userId,
        'review_id': reviewId,
      });
    }
  }

  /// Inserta un comentario en una reseña, subiendo la imagen si se proporciona.
  /// Devuelve el `image_url` generado (o null si no había imagen).
  Future<void> submitComment({
    required String reviewId,
    required String userId,
    required String? content,
    required XFile? commentImage,
    required Map<String, dynamic>? attachedGame,
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
      'review_id': reviewId,
      'content': content?.isNotEmpty == true ? content : null,
      'image_url': imageUrl,
      'attached_game': attachedGame,
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
    } catch (_) {}

    try {
      final commentsResp = await _client
          .from('review_comments')
          .select('image_url')
          .eq('review_id', reviewId);
      for (final c in commentsResp) {
        if (c['image_url'] != null) urlsToDelete.add(c['image_url'] as String);
      }
    } catch (_) {}

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers de lógica pura (testeables sin Supabase)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enriquece el feed con datos de reseñas y partners, y agrupa eventos
  /// del mismo usuario + juego dentro de una ventana de 24 horas.
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

  static List<Map<String, dynamic>> _mergeActivityItems({
    required List<Map<String, dynamic>> feedItems,
    required Map<String, Map<String, dynamic>> reviewsById,
    required Map<String, List<dynamic>> partnersByUserGame,
  }) {
    final merged = <Map<String, dynamic>>[];

    for (var item in feedItems) {
      // Inyectar partners
      final uId = item['user_id'];
      final gId = item['game_id'];
      if (uId != null && gId != null) {
        item['_partners'] = partnersByUserGame['${uId}_$gId'];
      }

      // Inyectar datos de reseña si es un evento "reviewed"
      if (item['action_type'] == 'reviewed') {
        final reviewId = (item['metadata'] as Map?)?['review_id'] as String?;
        if (reviewId != null && reviewsById.containsKey(reviewId)) {
          item = Map<String, dynamic>.from(item);
          item['_review'] = reviewsById[reviewId];
        }
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
                prev['action_type'] = 'status_change';
                (prev['metadata'] as Map? ?? {})['status'] =
                    (item['metadata'] as Map? ?? {})['status'];
                wasMerged = true;
                break;
              } else if (type == 'reviewed' &&
                  prev['action_type'] == 'status_change') {
                prev['_review'] = item['_review'];
                wasMerged = true;
                break;
              } else if (type == 'status_change' &&
                  prev['action_type'] == 'status_change') {
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
}
