// lib/screens/social/notifications_feed_screen.dart
//
// Lista de notificaciones sociales: likes, solicitudes de amistad,
// comentarios en tu reseña y respuestas a tu comentario. Más reciente arriba.
//
// Al abrir esta pantalla se marcan todas las notificaciones como leídas
// (mismo patrón que al entrar en la pestaña Actividad). El estilo visual
// "nuevo" de cada fila se basa en una foto fija tomada justo al cargar cada
// página, no en el estado real ya actualizado en servidor.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/globals.dart';
import '../../repositories/notifications_repository.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_network_image.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../activity/activity_formatters.dart';

class NotificationsFeedScreen extends StatefulWidget {
  const NotificationsFeedScreen({super.key});

  @override
  State<NotificationsFeedScreen> createState() =>
      _NotificationsFeedScreenState();
}

class _NotificationsFeedScreenState extends State<NotificationsFeedScreen>
    with PaginatedScrollMixin {
  final _repo = NotificationsRepository();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _unreadAtOpen = {};
  bool _isLoading = true;
  int _offset = 0;

  bool get _isGuest => _supabase.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadFirstPage();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    if (_isGuest) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final result = await _repo.fetchNotificationsPage(0);
    if (!mounted) return;

    setState(() {
      _notifications = result.notifications;
      _offset = result.nextOffset;
      hasMore = result.hasMore;
      _unreadAtOpen
        ..clear()
        ..addAll(
          result.notifications
              .where((n) => n['read_at'] == null)
              .map((n) => n['id'] as String),
        );
      _isLoading = false;
    });
    triggerScrollCheck();

    // Reset optimista del badge global + persistencia en servidor. El
    // estilo "nuevo" de esta pantalla sigue usando _unreadAtOpen (foto
    // fija tomada arriba), no el read_at ya actualizado.
    unreadNotificationsCount.value = 0;
    _repo.markAllRead();
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _isGuest) return;
    setState(() => isLoadingMore = true);

    final result = await _repo.fetchNotificationsPage(_offset);
    if (!mounted) return;

    setState(() {
      _notifications.addAll(result.notifications);
      _offset = result.nextOffset;
      hasMore = result.hasMore;
      isLoadingMore = false;
      _unreadAtOpen.addAll(
        result.notifications
            .where((n) => n['read_at'] == null)
            .map((n) => n['id'] as String),
      );
    });
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'] as String?;
    final reviewId = notification['review_id'] as String?;
    final actor = notification['users'] as Map<String, dynamic>?;
    final actorId = actor?['id'] as String?;

    switch (type) {
      case 'like':
      case 'comment':
      case 'reply':
        if (reviewId == null) return;
        final nav = await _repo.fetchReviewForNavigation(reviewId);
        if (nav == null || !mounted) return;
        context.pushReviewDetails(
          nav.gameData,
          nav.userData,
          nav.reviewData,
          focusComment: type == 'comment' || type == 'reply',
        );
        break;
      case 'friend_request':
        context.pushFriends();
        break;
      case 'friend_request_accepted':
        if (actorId != null) context.pushProfile(userId: actorId);
        break;
    }
  }

  String _notificationText(Map<String, dynamic> n) {
    final actor = n['users'] as Map<String, dynamic>?;
    final name = actor != null
        ? ActivityFormatters.displayName(actor)
        : 'Alguien';
    final meta = n['metadata'] as Map<String, dynamic>? ?? {};
    final gameTitle = meta['game_title'] as String?;

    switch (n['type']) {
      case 'like':
        return gameTitle != null
            ? '$name le dio like a tu reseña de $gameTitle'
            : '$name le dio like a tu reseña';
      case 'comment':
        return gameTitle != null
            ? '$name comentó tu reseña de $gameTitle'
            : '$name comentó tu reseña';
      case 'reply':
        return '$name respondió a tu comentario';
      case 'friend_request':
        return '$name te envió una solicitud de amistad';
      case 'friend_request_accepted':
        return '$name aceptó tu solicitud de amistad';
      default:
        return '$name interactuó contigo';
    }
  }

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'like':
        return Icons.thumb_up_alt_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'reply':
        return Icons.reply_rounded;
      case 'friend_request':
        return Icons.person_add_alt_1_rounded;
      case 'friend_request_accepted':
        return Icons.people_alt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Widget _buildRow(Map<String, dynamic> n) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>();
    final actor = n['users'] as Map<String, dynamic>?;
    final avatarUrl = actor?['avatar_url'] as String?;
    final meta = n['metadata'] as Map<String, dynamic>? ?? {};
    final snippet = meta['comment_snippet'] as String?;
    final coverUrl = meta['game_cover_url'] as String?;
    final isUnread = _unreadAtOpen.contains(n['id']);
    final createdAt = n['created_at'] as String?;

    return InkWell(
      onTap: () => _onNotificationTap(n),
      child: Container(
        color: isUnread ? cs.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(
                      _notificationIcon(n['type'] as String?),
                      size: 12,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _notificationText(n),
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    createdAt != null
                        ? ActivityFormatters.formatRelativeDate(createdAt)
                        : '',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (coverUrl != null) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: ext?.radiusSmall ?? BorderRadius.circular(6),
                child: CorpusNetworkImage(
                  url: coverUrl,
                  width: 40,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuest) {
      return Scaffold(
        appBar: AppBar(title: const CorpusScreenTitle('Notificaciones')),
        body: const Center(
          child: GuestLoginPrompt(
            icon: Icons.notifications_none_rounded,
            message: 'Inicia sesión para ver tus notificaciones.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const CorpusScreenTitle('Notificaciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text('No tienes notificaciones todavía'))
          : ListView.separated(
              controller: scrollController,
              itemCount: _notifications.length + (hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= _notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _buildRow(_notifications[index]);
              },
            ),
    );
  }
}
