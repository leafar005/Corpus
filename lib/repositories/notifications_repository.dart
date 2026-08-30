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

  /// Página de notificaciones del usuario actual, más reciente primero,
  /// con los datos del autor (actor) embebidos.
  Future<NotificationsPageResult> fetchNotificationsPage(
    int offset, {
    int limit = 30,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      return const NotificationsPageResult(
        notifications: [],
        hasMore: false,
        nextOffset: 0,
      );
    }

    final from = offset;
    final to = offset + limit - 1;

    final response = await _client
        .from('notifications')
        .select('''
            *,
            users!notifications_actor_id_fkey(id, username, display_name, avatar_url)
          ''')
        .eq('recipient_id', myId)
        .order('created_at', ascending: false)
        .range(from, to);

    final items = List<Map<String, dynamic>>.from(response);

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
    try {
      await _client.rpc('mark_all_notifications_read');
    } catch (e) {
      debugPrint('[NotificationsRepository] markAllRead error: $e');
    }
  }

  /// Marca una notificación concreta como leída.
  Future<void> markRead(String notificationId) async {
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (e) {
      debugPrint('[NotificationsRepository] markRead error: $e');
    }
  }

  /// Reseña + juego + autor, en una sola query, para navegar a
  /// ReviewDetailsScreen desde una notificación de like/comentario/respuesta.
  Future<ReviewNavigationData?> fetchReviewForNavigation(
    String reviewId,
  ) async {
    try {
      final resp = await _client
          .from('reviews')
          .select('''
              *,
              users!reviews_user_id_users_fkey(*),
              games!reviews_game_id_fkey(*),
              review_likes(user_id),
              review_comments(id)
            ''')
          .eq('id', reviewId)
          .maybeSingle();

      if (resp == null) return null;

      final reviewData = Map<String, dynamic>.from(resp);
      final userData =
          reviewData.remove('users') as Map<String, dynamic>? ?? {};
      final gameData =
          reviewData.remove('games') as Map<String, dynamic>? ?? {};

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
