import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';

/// Controller para [MainScreen].
///
/// Gestiona los tres canales Realtime (amistad, actividad, notificaciones) y
/// los contadores de badge correspondientes. La UI solo llama a los métodos
/// públicos; nunca accede a Supabase directamente.
class MainScreenController {
  MainScreenController({required this.isOnActivityTab, SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Devuelve true cuando el usuario está en la pestaña Actividad.
  /// Se usa para evitar incrementar el badge mientras ya la tiene abierta.
  final bool Function() isOnActivityTab;

  final SupabaseClient _client;
  bool _disposed = false;

  RealtimeChannel? _friendshipsChannel;
  RealtimeChannel? _activityFeedChannel;
  RealtimeChannel? _notificationsChannel;

  final Set<String> _recentActivityGames = <String>{};
  final Set<String> _countedPostIds = <String>{};

  String? get _myId => _client.auth.currentUser?.id;

  // ──────────────────────────────────────────────────────────────────────────
  // Ciclo de vida
  // ──────────────────────────────────────────────────────────────────────────

  /// Inicia las tres suscripciones Realtime y carga los badges iniciales.
  void init() {
    if (_disposed) return;
    _subscribeFriendRequests();
    _subscribeActivityFeed();
    _subscribeNotifications();
  }

  /// Cancela todos los canales abiertos. Llamar desde [State.dispose].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final ch in [
      _friendshipsChannel,
      _activityFeedChannel,
      _notificationsChannel,
    ]) {
      if (ch != null) {
        try {
          unawaited(_client.removeChannel(ch));
        } catch (e) {
          debugPrint('[MainScreenController] Error removiendo canal: $e');
        }
      }
    }
    _friendshipsChannel = null;
    _activityFeedChannel = null;
    _notificationsChannel = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Badges
  // ──────────────────────────────────────────────────────────────────────────

  /// Recarga todos los contadores de badge desde el servidor.
  /// Llamar al volver de segundo plano (excepto si estamos en pestaña Actividad).
  Future<void> fetchInitialBadges() async {
    if (_disposed) return;
    final myId = _myId;
    if (myId == null) return;

    // Solicitudes de amistad pendientes.
    try {
      final res = await _client
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', myId)
          .eq('status', 'pending');
      if (_disposed) return;
      unreadFriendRequestsCount.value = res.length;
    } catch (e) {
      debugPrint(
        '[MainScreenController] Error cargando solicitudes de amistad: $e',
      );
    }

    if (_disposed) return;

    // Actividad no leída (calculada en servidor).
    try {
      final res = await _client.rpc('get_unread_activity_summary').single();
      if (_disposed) return;
      unreadActivityCount.value = (res['unread_count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[MainScreenController] Error fetch activity summary: $e');
    }
  }

  /// Marca la actividad como leída: reset optimista en la UI + persistencia
  /// en servidor (para sincronizar otros dispositivos de la misma cuenta).
  Future<void> markActivityRead() async {
    if (_disposed) return;
    final myId = _myId;
    if (myId == null) return;

    unreadActivityCount.value = 0; // Optimista — no revertir aunque falle.
    _recentActivityGames.clear();
    _countedPostIds.clear();
    try {
      await _client.rpc('mark_activity_read');
    } catch (e) {
      debugPrint(
        '[MainScreenController] Error marcando actividad como leída: $e',
      );
    }
  }

  /// Recarga el conteo de notificaciones no leídas.
  Future<void> fetchNotificationsCount() async {
    if (_disposed) return;
    final myId = _myId;
    if (myId == null) return;
    try {
      final res = await _client.rpc('get_unread_notifications_count');
      if (_disposed) return;
      unreadNotificationsCount.value = (res as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[MainScreenController] Error fetch notifications count: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Canales Realtime (privados)
  // ──────────────────────────────────────────────────────────────────────────

  void _subscribeFriendRequests() {
    final myId = _myId;
    if (myId == null) return;

    // Carga inicial.
    _client
        .from('friendships')
        .select('requester_id')
        .eq('addressee_id', myId)
        .eq('status', 'pending')
        .then((rows) {
          if (_disposed) return;
          unreadFriendRequestsCount.value = rows.length;
        })
        .catchError((Object e) {
          debugPrint('[MainScreenController] Error inicial solicitudes: $e');
        });

    _friendshipsChannel = _client
        .channel('pending_friend_requests:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: myId,
          ),
          callback: (payload) {
            if (_disposed) return;
            final status = payload.newRecord['status'];
            if (status == 'pending') {
              unreadFriendRequestsCount.value++;
            }
          },
        )
        .subscribe();
  }

  void _subscribeActivityFeed() {
    final myId = _myId;
    if (myId == null) return;

    fetchInitialBadges();

    _activityFeedChannel = _client
        .channel('main_activity_feed_badge:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_feed',
          callback: (payload) {
            if (_disposed) return;
            final record = payload.newRecord;
            final userId = record['user_id'];
            if (userId == myId) return; // Ignorar posts propios.

            final gameId = record['game_id'];
            if (gameId != null) {
              final key = '${userId}_$gameId';
              if (_recentActivityGames.contains(key)) return;
              _recentActivityGames.add(key);
              if (_recentActivityGames.length > 50) {
                _recentActivityGames.clear();
              }
            }

            // Todos los ítems que comparten `post_id` (posts agrupados o fusión
            // reviewed + status_change) incrementan el contador solo una vez.
            final postId = record['post_id'] as String?;
            if (postId != null) {
              if (_countedPostIds.contains(postId)) return;
              _countedPostIds.add(postId);
              if (_countedPostIds.length > 100) {
                _countedPostIds.clear();
                _countedPostIds.add(postId);
              }
            }

            if (!isOnActivityTab()) {
              unreadActivityCount.value++;
            }
          },
        )
        .subscribe((status, error) {
          if (_disposed) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Re-fetch también en reconexiones (cortes de red, suspensión).
            fetchInitialBadges();
          }
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              '[MainScreenController] Canal actividad con problemas: $status / $error',
            );
          }
        });
  }

  void _subscribeNotifications() {
    final myId = _myId;
    if (myId == null) return;

    fetchNotificationsCount();

    _notificationsChannel = _client
        .channel('unread_notifications_badge:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: myId,
          ),
          callback: (_) {
            if (_disposed) return;
            fetchNotificationsCount();
          },
        )
        .subscribe((status, error) {
          if (_disposed) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            fetchNotificationsCount();
          }
        });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Devuelve true si la plataforma debe persistir la pestaña activa entre
  /// sesiones (web + escritorio nativo).
  static bool get shouldPersistTab {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      debugPrint('[MainScreenController] Platform.isDesktop falló: $e');
      return false;
    }
  }
}
