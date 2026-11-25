// lib/repositories/notifications_repository.dart
//
// Acceso a datos para el sistema de notificaciones sociales (campana):
// likes, solicitudes de amistad, comentarios y respuestas.
//
// La tabla `notifications` se puebla exclusivamente mediante triggers de
// PostgreSQL (ver supabase/migrations/20260830010000_add_notifications_system.sql).
// Este repositorio nunca hace INSERT/DELETE directo sobre esa tabla; solo
// lee y marca como leído vía RPC.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/postgrest_utils.dart';

/// Resultado de cargar una página de notificaciones.
class NotificationsPageResult {
  const NotificationsPageResult({
    required this.notifications,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<Map<String, dynamic>> notifications;
  final bool hasMore;
  final int nextOffset;
}

/// Datos necesarios para navegar a ReviewDetailsScreen desde una
/// notificación (gameData, userData y reviewData, tal y como los espera
/// `context.pushReviewDetails(...)`).
class ReviewNavigationData {
  const ReviewNavigationData({
    required this.gameData,
    required this.userData,
    required this.reviewData,
  });

  final Map<String, dynamic> gameData;
  final Map<String, dynamic> userData;
  final Map<String, dynamic> reviewData;
}

class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Whether the current user is a guest (not logged in).
  bool get isGuest => _client.auth.currentUser == null;

  /// Página de notificaciones del usuario actual, más reciente primero,
  /// con los datos del autor (actor) embebidos.
  Future<NotificationsPageResult> fetchNotificationsPage(
    int offset, {
    int limit = 30,
    String? beforeCreatedAt,
    String? beforeId,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      return const NotificationsPageResult(
        notifications: [],
        hasMore: false,
        nextOffset: 0,
      );
    }

    var query = _client
        .from('notifications')
        .select(
          '$kNotificationColumns, '
          'users!notifications_actor_id_fkey($kPublicUserBasicColumns)',
        )
        .eq('recipient_id', myId);

    dynamic response;
    if (beforeCreatedAt != null &&
        beforeCreatedAt.isNotEmpty &&
        beforeId != null &&
        isValidUuid(beforeId)) {
      response = await query
          .or(
            'created_at.lt.$beforeCreatedAt,'
            'and(created_at.eq.$beforeCreatedAt,id.lt.$beforeId)',
          )
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
    } else {
      final from = offset;
      final to = offset + limit - 1;
      response = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, to);
    }

    final items = (response as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return NotificationsPageResult(
      notifications: items,
      hasMore: items.length == limit,
      nextOffset: offset + items.length,
    );
  }

  /// Nº de notificaciones no leídas del usuario actual (calculado en servidor).
  Future<int> fetchUnreadCount() async {
    if (_client.auth.currentUser?.id == null) return 0;
    try {
      final res = await _client.rpc('get_unread_notifications_count');
      return (res as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[NotificationsRepository] fetchUnreadCount error: $e');
      return 0;
    }
  }

  /// Marca todas las notificaciones del usuario actual como leídas.
  Future<void> markAllRead() async {
    if (_client.auth.currentUser?.id == null) return;
    try {
      await _client.rpc('mark_all_notifications_read');
    } catch (e) {
      debugPrint('[NotificationsRepository] markAllRead error: $e');
      rethrow;
    }
  }

  /// Marca una notificación concreta como leída.
  Future<void> markRead(String notificationId) async {
    if (_client.auth.currentUser?.id == null) return;
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (e) {
      debugPrint('[NotificationsRepository] markRead error: $e');
      rethrow;
    }
  }

  /// Reseña + juego + autor (+ compañeros + post) para navegar a
  /// ReviewDetailsScreen desde una notificación de like/comentario/respuesta.
  Future<ReviewNavigationData?> fetchReviewForNavigation(
    String reviewId,
  ) async {
    try {
      final resp = await _client
          .from('reviews')
          .select(
            '$kReviewColumns, '
            'users!reviews_user_id_users_fkey($kPublicUserBasicColumns), '
            'games!reviews_game_id_fkey($kGameDetailColumns)',
          )
          .eq('id', reviewId)
          .maybeSingle();

      if (resp == null) return null;

      final reviewData = Map<String, dynamic>.from(resp);
      final rawUsers = reviewData.remove('users');
      final userData = rawUsers is Map
          ? Map<String, dynamic>.from(rawUsers)
          : <String, dynamic>{};
      final rawGames = reviewData.remove('games');
      final gameData = rawGames is Map
          ? Map<String, dynamic>.from(rawGames)
          : <String, dynamic>{};

      final rawPartnerIds = reviewData['partner_ids'];
      final partnerIds = rawPartnerIds is List
          ? rawPartnerIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const <String>[];

      if (partnerIds.isNotEmpty) {
        try {
          final partnersRes = await _client
              .from('users')
              .select(kPublicUserBasicColumns)
              .inFilter('id', partnerIds);
          final partnersById = <String, Map<String, dynamic>>{};
          for (final p in (partnersRes as List).whereType<Map>()) {
            final map = Map<String, dynamic>.from(p);
            final pid = map['id']?.toString();
            if (pid != null) partnersById[pid] = map;
          }
          reviewData['partners'] = [
            for (final pid in partnerIds)
              if (partnersById.containsKey(pid)) partnersById[pid]!,
          ];
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[NotificationsRepository] Error cargando partners: $e',
            );
          }
        }
      }

      try {
        final postRes = await _client.rpc(
          'current_post_for_review',
          params: {'p_review_id': reviewId},
        );
        if (postRes is String && postRes.isNotEmpty) {
          reviewData['post_id'] = postRes;
        } else if (postRes is Map) {
          final postMap = Map<String, dynamic>.from(postRes);
          reviewData['_post'] = postMap;
          if (postMap['id'] != null) {
            reviewData['post_id'] = postMap['id'].toString();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[NotificationsRepository] Error resolviendo post para review: $e',
          );
        }
      }

      return ReviewNavigationData(
        gameData: gameData,
        userData: userData,
        reviewData: reviewData,
      );
    } catch (e) {
      debugPrint(
        '[NotificationsRepository] fetchReviewForNavigation error: $e',
      );
      return null;
    }
  }
}
