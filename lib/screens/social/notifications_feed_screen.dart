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
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import '../../models/models.dart';

import 'package:corpus/globals.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/notifications_repository.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/corpus_network_image.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../activity/activity_formatters.dart';

class NotificationsFeedScreen extends StatefulWidget {
  const NotificationsFeedScreen({super.key, this.repository});

  final NotificationsRepository? repository;

  @override
  State<NotificationsFeedScreen> createState() =>
      _NotificationsFeedScreenState();
}

class _NotificationsFeedScreenState extends State<NotificationsFeedScreen>
    with PaginatedScrollMixin {
  late final NotificationsRepository _repo =
      widget.repository ?? NotificationsRepository();

  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _loadedIds = {};
  final Set<String> _unreadAtOpen = {};
  bool _isLoading = true;
  String? _loadError;
  String? _loadMoreError;
  int _offset = 0;

  bool get _isGuest => _repo.isGuest;

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

    if (!_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _loadMoreError = null;
      });
    }

    try {
      final result = await _repo.fetchNotificationsPage(0);
      if (!mounted) return;

      _loadedIds.clear();
      final uniqueItems = <Map<String, dynamic>>[];
      for (final item in result.notifications) {
        final id = item['id']?.toString();
        if (id == null || _loadedIds.add(id)) {
          uniqueItems.add(item);
        }
      }

      setState(() {
        _notifications = uniqueItems;
        _offset = result.nextOffset;
        hasMore = result.hasMore;
        _loadError = null;
        _loadMoreError = null;
        _unreadAtOpen
          ..clear()
          ..addAll(
            uniqueItems
                .where((n) => n['read_at'] == null && n['id'] != null)
                .map((n) => n['id'].toString()),
          );
        _isLoading = false;
      });
      triggerScrollCheck();

      // Reset optimista del badge global + persistencia en servidor. El
      // estilo "nuevo" de esta pantalla sigue usando _unreadAtOpen (foto
      // fija tomada arriba), no el read_at ya actualizado.
      unreadNotificationsCount.value = 0;
      _repo.markAllRead();
    } catch (e) {
      debugPrint('[NotificationsFeedScreen] Error cargando notificaciones: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'No se pudieron cargar las notificaciones.';
      });
    }
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _isGuest || _loadMoreError != null) return;
    setState(() {
      isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final result = await _repo.fetchNotificationsPage(_offset);
      if (!mounted) return;

      final uniqueNew = <Map<String, dynamic>>[];
      for (final item in result.notifications) {
        final id = item['id']?.toString();
        if (id == null || _loadedIds.add(id)) {
          uniqueNew.add(item);
        }
      }

      setState(() {
        _notifications.addAll(uniqueNew);
        _offset = result.nextOffset;
        hasMore = result.hasMore;
        isLoadingMore = false;
        _loadMoreError = null;
        _unreadAtOpen.addAll(
          uniqueNew
              .where((n) => n['read_at'] == null && n['id'] != null)
              .map((n) => n['id'].toString()),
        );
      });
      triggerScrollCheck();
    } catch (e) {
      debugPrint('[NotificationsFeedScreen] Error paginando notificaciones: $e');
      if (!mounted) return;
      setState(() {
        isLoadingMore = false;
        _loadMoreError = 'No se pudieron cargar más notificaciones.';
      });
    }
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'] as String?;
    final reviewId = notification['review_id'] as String?;
    final postId = notification['post_id'] as String?;
    final meta = notification['metadata'] as Map<String, dynamic>? ?? {};
    final gamesCount = (meta['games_count'] as num?)?.toInt() ?? 0;
    final actor = notification['users'] as Map<String, dynamic>?;
    final actorId = actor?['id'] as String?;

    switch (type) {
      case 'like':
      case 'comment':
      case 'reply':
        final focusComment = type == 'comment' || type == 'reply';
        if ((gamesCount > 1 || reviewId == null) && postId != null) {
          context.pushGroupedPostDetails(
            postId: postId,
            focusComment: focusComment,
          );
          return;
        }
        if (reviewId == null) return;
        if (postId != null) {
          final currentReviewPostId = await ActivityRepository()
              .resolvePostIdForReview(reviewId, create: false);
          if (!mounted) return;
          if (currentReviewPostId != null && currentReviewPostId != postId) {
            context.pushGroupedPostDetails(
              postId: postId,
              focusComment: focusComment,
            );
            return;
          }
        }
        final nav = await _repo.fetchReviewForNavigation(reviewId);
        if (nav == null || !mounted) return;
        context.pushReviewDetails(
          Game.fromMap(nav.gameData),
          nav.userData,
          nav.reviewData,
          postId: postId,
          focusComment: focusComment,
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
    final gamesCount = (meta['games_count'] as num?)?.toInt() ?? 0;

    switch (n['type']) {
      case 'like':
        if (gamesCount > 1) {
          return '$name le dio like a tu publicación de $gamesCount juegos';
        }
        return gameTitle != null
            ? '$name le dio like a tu reseña de $gameTitle'
            : '$name le dio like a tu reseña';
      case 'comment':
        if (gamesCount > 1) {
          return '$name comentó tu publicación de $gamesCount juegos';
        }
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

  CorpusIconKind _notificationIcon(String? type) {
    switch (type) {
      case 'like':
        return CorpusIconKind.ThumbUpAltRounded;
      case 'comment':
        return CorpusIconKind.ChatBubbleRounded;
      case 'reply':
        return CorpusIconKind.ReplyRounded;
      case 'friend_request':
        return CorpusIconKind.PersonAddAlt1Rounded;
      case 'friend_request_accepted':
        return CorpusIconKind.PeopleAltRounded;
      default:
        return CorpusIconKind.NotificationsRounded;
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
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  onBackgroundImageError:
                      avatarUrl != null && avatarUrl.isNotEmpty
                      ? (_, _) {}
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const CorpusTablerIcon(CorpusIconKind.Person)
                      : null,
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
                    child: CorpusTablerIcon(
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
            if (coverUrl != null && coverUrl.isNotEmpty) ...[
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

  Widget _buildLoadErrorState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CorpusTablerIcon(
              CorpusIconKind.ErrorOutline,
              size: 48,
              color: cs.error,
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'No se pudieron cargar las notificaciones.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadFirstPage,
              icon: const CorpusTablerIcon(CorpusIconKind.Refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadMoreError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => _loadMoreError = null);
                loadMore();
              },
              icon: const CorpusTablerIcon(CorpusIconKind.Refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isGuest) {
      content = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
            onPressed: () =>
                AppNavigationController.instance.requestBack(context),
          ),
          title: const CorpusScreenTitle('Notificaciones'),
        ),
        body: const Center(
          child: GuestLoginPrompt(
            icon: CorpusIconKind.NotificationsNoneRounded,
            message: 'Inicia sesión para ver tus notificaciones.',
          ),
        ),
      );
    } else {
      content = Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
            onPressed: () =>
                AppNavigationController.instance.requestBack(context),
          ),
          title: const CorpusScreenTitle('Notificaciones'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _buildLoadErrorState(context)
            : _notifications.isEmpty
            ? const Center(child: Text('No tienes notificaciones todavía'))
            : ListView.separated(
                controller: scrollController,
                itemCount:
                    _notifications.length +
                    ((hasMore || _loadMoreError != null) ? 1 : 0),
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= _notifications.length) {
                    return _buildLoadMoreFooter(context);
                  }
                  return _buildRow(_notifications[index]);
                },
              ),
      );
    }

    return content;
  }
}
