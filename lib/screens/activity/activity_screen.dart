import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_controller.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/globals.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../widgets/coop_badge.dart';
import '../activity/activity_formatters.dart';
import '../activity/activity_story_viewer.dart';
import '../activity/widgets/post_action_bar.dart';
import '../library/game_details_screen.dart';
import '../../repositories/activity_repository.dart';
import '../../widgets/corpus_network_image.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../../models/models.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../utils/igdb_constants.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/activity_story_ring.dart';
import '../../widgets/corpus_tabler_icon.dart';
import '../../widgets/game_card.dart';

/// Feed de actividad social en tiempo real.
/// Muestra la actividad del usuario actual y la de sus amigos aceptados.
/// La tabla `activity_feed` se puebla automáticamente mediante triggers
/// de PostgreSQL cuando se cambia el estado de un juego o se escribe una reseña.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with PaginatedScrollMixin {
  late final ActivityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivityController();
    initPagination();
    if (!_controller.isGuest) {
      libraryUpdateNotifier.addListener(_onLibraryUpdated);
    }
    _controller.init();
    tabScrollToTopNotifiers[2].addListener(_onScrollToTop);
  }

  @override
  void dispose() {
    disposePagination();
    tabScrollToTopNotifiers[2].removeListener(_onScrollToTop);
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _controller.dispose();
    super.dispose();
  }

  void _onScrollToTop() {
    if (!mounted) return;
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onLibraryUpdated() {
    if (mounted) _controller.fetchActivity(isRefresh: true, silent: true);
  }

  @override
  Future<void> loadMore() async {
    final stillHasMore = await _controller.fetchActivity(isRefresh: false);
    hasMore = stillHasMore;
    isLoadingMore = _controller.isLoadingMore;
    if (hasMore) triggerScrollCheck();
  }

  void _openUserStory(
    List<Map<String, dynamic>> orderedFriends,
    int tappedIndex,
  ) {
    final storyFriends = orderedFriends.where((f) {
      final id = f['id'] as String?;
      return id != null && (_controller.userStories[id]?.isNotEmpty ?? false);
    }).toList();

    final tappedId = orderedFriends[tappedIndex]['id'] as String?;
    if (tappedId == null) return;

    final groupIndex = storyFriends.indexWhere((f) => f['id'] == tappedId);
    if (groupIndex == -1) {
      context.pushProfile(
        userId: tappedId,
      ); // amigo sin historias → perfil normal
      return;
    }

    final groups = storyFriends
        .map(
          (f) => StoryGroup(
            userData: f,
            activities: _controller.userStories[f['id']]!,
          ),
        )
        .toList();

    final viewedIds = viewedStoryIdsNotifier.value;
    final initialActivityIndex = ActivityRepository.firstUnseenIndex(
      groups[groupIndex].activities,
      viewedIds,
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => ActivityStoryViewer(
          groups: groups,
          initialGroupIndex: groupIndex,
          initialActivityIndex: initialActivityIndex,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openFriendsScreen() async {
    await context.pushFriends();
    // Al volver, refrescamos por si se aceptaron/enviaron solicitudes.
    if (mounted) {
      final viewed = await _controller.fetchFriendsStripWithViewed();
      viewedStoryIdsNotifier.value = {
        ...viewedStoryIdsNotifier.value,
        ...viewed,
      };
    }
  }

  Future<void> _fetchFriendsStrip() async {
    final viewed = await _controller.fetchFriendsStripWithViewed();
    if (mounted) {
      viewedStoryIdsNotifier.value = {
        ...viewedStoryIdsNotifier.value,
        ...viewed,
      };
    }
  }

  // ──────────────────────────────────────────
  // HELPERS DE FORMATO
  // ──────────────────────────────────────────

  String _formatDate(String isoString) =>
      ActivityFormatters.formatRelativeDate(isoString);

  String _getStatusText(String status) => GameStatus.labelForString(status);

  CorpusIconKind _getStatusIcon(String status) =>
      GameStatus.iconForString(status);

  String _getActionText(
    String actionType,
    String? status,
    bool isOwnActivity,
  ) => ActivityFormatters.actionText(
    actionType,
    status,
    isOwnActivity: isOwnActivity,
  );

  CorpusIconKind _getActionIcon(String actionType, String? status) =>
      ActivityFormatters.actionIcon(actionType, status);

  Color _getActionColor(String actionType, String? status, BuildContext ctx) =>
      ActivityFormatters.actionColor(actionType, status, ctx);

  // ──────────────────────────────────────────
  // CARD
  // ──────────────────────────────────────────

  void _openGameDetailsForMap(Map<String, dynamic> gameData) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    if (isDesktop) {
      context
          .pushGameDetails(Game.fromMap(gameData))
          .then((_) => _controller.refreshInPlace());
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        enableDrag: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          snap: true,
          builder: (context, scrollController) => GameDetailsScreen(
            gameData: Game.fromMap(gameData),
            scrollController: scrollController,
          ),
        ),
      ).then((_) => _controller.refreshInPlace());
    }
  }

  Widget _buildMoreGamesCard({
    required int extraCount,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final radius =
        Theme.of(context).extension<CorpusThemeExtension>()?.radiusSmall ??
        BorderRadius.circular(8);

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+$extraCount',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ver todos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedActivityCard(Map<String, dynamic> activity, int index) {
    final userData = activity['users'] as Map<String, dynamic>? ?? {};
    final meta = activity['metadata'] as Map<String, dynamic>? ?? {};
    final status = meta['status'] as String?;
    final games =
        (activity['_games'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final displayName = ActivityFormatters.displayName(userData);
    final avatarUrl = userData['avatar_url'] as String?;
    final dateStr = _formatDate(activity['created_at'] as String? ?? '');

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final activityUserId =
        (userData['id'] as String?) ?? (activity['user_id'] as String?);
    final isOwnActivity = myId != null && myId == activityUserId;
    final postId = activity['post_id'] as String?;
    final stats = PostStats.fromDynamic(
      activity['_post'],
      fallbackPostId: postId,
    );

    void openGroupedDetails({bool focusComment = false}) {
      if (postId == null) {
        if (activityUserId != null) {
          context.pushProfile(userId: activityUserId);
        }
        return;
      }
      context
          .pushGroupedPostDetails(
            postId: postId,
            actorData: userData,
            status: status,
            createdAt: activity['created_at'] as String?,
            initialGames: games,
            initialStats: stats,
            focusComment: focusComment,
          )
          .then((_) => _controller.refreshInPlace());
    }

    final actorLabel = isOwnActivity ? 'Tú' : displayName;
    final actionText = ActivityFormatters.groupedActionText(
      status,
      isOwnActivity: isOwnActivity,
    );
    final actionIcon = _getActionIcon('status_change', status);
    final actionColor = _getActionColor('status_change', status, context);

    final titles = games
        .map((g) => g['title'] as String? ?? 'Juego desconocido')
        .toList();
    final titleParts = ActivityFormatters.splitGroupedGameTitles(
      titles,
      maxShown: 3,
    );

    final visibleGames = games.take(kMaxGroupedFeedCards).toList();
    final extraCount = games.length - visibleGames.length;
    final stripCount = visibleGames.length + (extraCount > 0 ? 1 : 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openGroupedDetails(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: avatar + acción agrupada + tiempo ──
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (activityUserId != null) {
                      context.pushProfile(userId: activityUserId);
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? CorpusTablerIcon.user(size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(
                        context,
                      ).style.copyWith(fontSize: 15),
                      children: [
                        TextSpan(
                          text: actorLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' $actionText '),
                        TextSpan(
                          text: titleParts.shownTitles,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (titleParts.moreSuffix != null)
                          TextSpan(
                            text: titleParts.moreSuffix,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CorpusTablerIcon(actionIcon, size: 16, color: actionColor),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Tira horizontal de GameCards (3:4) + tarjeta "+N" ──
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: stripCount,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (i < visibleGames.length) {
                    final gMap = visibleGames[i];
                    final game = Game.fromMap(gMap);
                    return AspectRatio(
                      aspectRatio: IgdbConstants.coverAspectRatio,
                      child: GameCard(
                        game: game,
                        onReturn: () => _controller.refreshInPlace(),
                        onTap: (_) => _openGameDetailsForMap(gMap),
                      ),
                    );
                  }
                  return AspectRatio(
                    aspectRatio: IgdbConstants.coverAspectRatio,
                    child: _buildMoreGamesCard(
                      extraCount: extraCount,
                      onTap: () => openGroupedDetails(),
                    ),
                  );
                },
              ),
            ),
            if (postId != null) ...[
              const SizedBox(height: 14),
              PostActionBar(
                likesCount: stats?.likesCount ?? 0,
                commentsCount: stats?.commentsCount ?? 0,
                likedByMe: stats?.likedByMe ?? false,
                onLikeTap: () => _controller.toggleLike(index),
                onCommentTap: () => openGroupedDetails(focusComment: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    if (ActivityRepository.isGroupedActivity(activity)) {
      return _buildGroupedActivityCard(activity, index);
    }

    final userData = activity['users'] as Map<String, dynamic>? ?? {};
    final gameData = activity['games'] as Map<String, dynamic>? ?? {};
    final meta = activity['metadata'] as Map<String, dynamic>? ?? {};
    final review = activity['_review'] as Map<String, dynamic>?;
    final partners =
        review?['partners'] as List<dynamic>? ??
        activity['_partners'] as List<dynamic>? ??
        [];

    final displayName =
        userData['display_name'] as String? ??
        userData['username'] as String? ??
        'Usuario';
    final avatarUrl = userData['avatar_url'] as String?;
    final gameTitle = gameData['title'] as String? ?? 'Juego desconocido';
    final coverUrl = gameData['cover_url'] as String?;

    final actionType = activity['action_type'] as String? ?? 'status_change';
    // El status efectivo: para eventos 'reviewed', tomamos el status de la propia
    // reseña (que refleja el estado real del juego). Para 'achievement' usamos
    // una clave especial. Para status_change usamos el metadata directamente.
    final String? effectiveStatus = actionType == 'reviewed'
        ? (review?['status'] as String? ?? meta['status'] as String?)
        : actionType == 'achievement'
        ? 'achievement'
        : meta['status'] as String?;
    final dateStr = _formatDate(activity['created_at'] as String? ?? '');

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final activityUserId = userData['id'] as String?;
    final isOwnActivity = myId == activityUserId;

    final actionText = _getActionText(
      actionType,
      effectiveStatus,
      isOwnActivity,
    );
    final actionIcon = _getActionIcon(actionType, effectiveStatus);
    final actionColor = _getActionColor(actionType, effectiveStatus, context);

    // Datos de la reseña enriquecida
    final rating = review != null
        ? (review['rating'] as num?)?.toDouble()
        : (meta['rating'] as num?)?.toDouble();
    final comment =
        review?['comment'] as String? ?? meta['comment'] as String? ?? '';
    final List<dynamic> imageUrls = review?['image_urls'] ?? [];
    final postId =
        (activity['post_id'] as String?) ??
        PostStats.fromDynamic(review?['_post'])?.postId;
    final stats = PostStats.fromDynamic(
      activity['_post'] ?? review?['_post'],
      fallbackPostId: postId,
    );
    final mergedPosts =
        (activity['_merged_posts'] as List?)
            ?.map((e) => PostStats.fromDynamic(e))
            .whereType<PostStats>()
            .where((p) => p.commentsCount > 0)
            .toList() ??
        const <PostStats>[];
    final previousPostWithComments = mergedPosts.isNotEmpty
        ? mergedPosts.first
        : null;
    final replayCount = review?['replay_count'] ?? 0;
    final isReview = review != null;

    void openReview({String? targetPostId, bool focusComment = false}) {
      if (review == null) return;
      context
          .pushReviewDetails(
            Game.fromMap(gameData),
            userData,
            review,
            postId: targetPostId ?? postId,
            focusComment: focusComment,
          )
          .then((_) => _controller.refreshInPlace());
    }

    void openReviewComments() => openReview(focusComment: true);

    void openGameDetails() {
      final isDesktop = MediaQuery.of(context).size.width > 800;
      if (isDesktop) {
        context
            .pushGameDetails(Game.fromMap(gameData))
            .then((_) => _controller.refreshInPlace());
      } else {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: false,
          enableDrag: true,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            expand: false,
            snap: true,
            builder: (context, scrollController) => GameDetailsScreen(
              gameData: Game.fromMap(gameData),
              scrollController: scrollController,
            ),
          ),
        ).then((_) => _controller.refreshInPlace());
      }
    }

    void handleStatusChangeTap() async {
      final uId = activityUserId;
      final internalGameId = activity['game_id'] as int?;

      if (uId != null && internalGameId != null) {
        final review = await ActivityRepository()
            .fetchLatestReviewForUserAndGame(uId, internalGameId);
        if (review != null && mounted) {
          context
              .pushReviewDetails(
                Game.fromMap(gameData),
                userData,
                review,
                postId:
                    postId ?? PostStats.fromDynamic(review['_post'])?.postId,
              )
              .then((_) => _controller.refreshInPlace());
          return;
        }
      }

      openGameDetails();
    }

    return GestureDetector(
      onTap: isReview ? openReview : handleStatusChangeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: avatar + acción + tiempo ──
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (activityUserId != null) {
                      context.pushProfile(userId: activityUserId);
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? CorpusTablerIcon.user(size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (activityUserId != null) {
                        context.pushProfile(userId: activityUserId);
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(fontSize: 15),
                        children: [
                          TextSpan(
                            text: isOwnActivity ? 'Tú' : displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' $actionText '),
                          TextSpan(
                            text: gameTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CorpusTablerIcon(actionIcon, size: 16, color: actionColor),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Cuerpo: portada + info del juego / reseña ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrl != null)
                  Container(
                    width: 100,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: Theme.of(
                        context,
                      ).extension<CorpusThemeExtension>()!.radiusSmall,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                if (coverUrl != null) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Estado del juego
                      if (effectiveStatus != null &&
                          effectiveStatus != 'achievement')
                        Row(
                          children: [
                            CorpusTablerIcon(
                              _getStatusIcon(effectiveStatus),
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(effectiveStatus),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      // Nota + tiempo de juego
                      if (rating != null && rating > 0 ||
                          (review?['play_time_hours'] ?? 0) > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (rating != null && rating > 0) ...[
                              CorpusTablerIcon.star(
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatRating(rating),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if ((review?['play_time_hours'] ?? 0) > 0) ...[
                              CorpusTablerIcon.timer(
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(review!['play_time_hours'] as num).toDouble().toStringAsFixed(1)} h',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                            if (replayCount > 0) ...[
                              const SizedBox(width: 12),
                              CorpusTablerIcon.repeat(
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                replayCount.toString(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (partners.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: partners.map((partner) {
                            return CoopBadge(
                              username: partner['username'] ?? 'Usuario',
                              avatarUrl: partner['avatar_url'],
                              size: 20,
                              status: effectiveStatus,
                              userId: partner['id'] as String?,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Comentario / reseña ──
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                comment,
                style: const TextStyle(fontSize: 16, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Imágenes adjuntas ──
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (MediaQuery.of(context).size.width > 600)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            final strUrls = imageUrls
                                .map((e) => e.toString())
                                .toList();
                            showFullScreenGallery(context, strUrls, idx);
                          },
                          child: ClipRRect(
                            borderRadius: Theme.of(
                              context,
                            ).extension<CorpusThemeExtension>()!.radiusSmall,
                            child: CorpusNetworkImage(
                              url: imageUrls[idx] as String,
                              height: 120,
                              fit: BoxFit.fitHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: imageUrls.length,
                  itemBuilder: (context, idx) {
                    return GestureDetector(
                      onTap: () {
                        final strUrls = imageUrls
                            .map((e) => e.toString())
                            .toList();
                        showFullScreenGallery(context, strUrls, idx);
                      },
                      child: ClipRRect(
                        borderRadius: Theme.of(
                          context,
                        ).extension<CorpusThemeExtension>()!.radiusSmall,
                        child: CorpusNetworkImage(
                          url: imageUrls[idx] as String,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    );
                  },
                ),
            ],

            // ── Acciones (likes / comentarios) del post ──
            if (isReview || postId != null) ...[
              const SizedBox(height: 14),
              PostActionBar(
                likesCount: stats?.likesCount ?? 0,
                commentsCount: stats?.commentsCount ?? 0,
                likedByMe: stats?.likedByMe ?? false,
                onLikeTap: () => _controller.toggleLike(index),
                onCommentTap: isReview
                    ? openReviewComments
                    : handleStatusChangeTap,
                trailing: (previousPostWithComments != null && isReview)
                    ? TextButton(
                        onPressed: () => openReview(
                          targetPostId: previousPostWithComments.postId,
                          focusComment: true,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Ver comentarios del estado anterior (${previousPostWithComments.commentsCount})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // _showImageFullScreen removed in favor of full_screen_gallery.dart
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CorpusTablerIcon.users(
            size: 72,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Aquí verás tu actividad y la de tus amigos',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '¡Añade juegos a tu biblioteca o invita a amigos para empezar!',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // FRANJA DE AMIGOS
  // ──────────────────────────────────────────

  Widget _buildFriendsStrip() {
    return Container(
      height: 110,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: _controller.isLoadingFriendsStrip
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _controller.friendsStrip.isEmpty
          ? Center(
              child: TextButton.icon(
                onPressed: _openFriendsScreen,
                icon: const CorpusTablerIcon.userPlus(size: 18),
                label: const Text('Añade amigos para ver su actividad'),
              ),
            )
          : AnimatedBuilder(
              animation: Listenable.merge([
                onlineUsersNotifier,
                viewedStoryIdsNotifier,
              ]),
              builder: (context, child) {
                final onlineUsers = onlineUsersNotifier.value;
                final viewedIds = viewedStoryIdsNotifier.value;
                final sortedFriends = ActivityRepository.sortFriendsStrip(
                  friends: _controller.friendsStrip,
                  userStories: _controller.userStories,
                  onlineUserIds: onlineUsers,
                  viewedStoryIds: viewedIds,
                );

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sortedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = sortedFriends[index];
                    final friendId = friend['id'] as String?;
                    final displayName =
                        friend['display_name'] as String? ??
                        friend['username'] as String? ??
                        'Usuario';
                    final avatarUrl = friend['avatar_url'] as String?;

                    // Lógica del juego en curso
                    final playingGame =
                        friend['currently_playing_name'] as String?;
                    final isPlaying =
                        friend['currently_playing_appid'] != null &&
                        playingGame != null;

                    // Lógica de si está online
                    final isOnline =
                        friendId != null && onlineUsers.contains(friendId);

                    final hasStory =
                        friendId != null &&
                        (_controller.userStories[friendId]?.isNotEmpty ??
                            false);

                    final playingColor = Colors.greenAccent[400]!;
                    const onlineColor = Colors.blueAccent;

                    return GestureDetector(
                      onTap: () {
                        if (friendId == null) return;
                        _openUserStory(sortedFriends, index);
                      },
                      onLongPress: () {
                        if (friendId == null) return;
                        context.pushProfile(userId: friendId);
                      },
                      child: Container(
                        width: 76,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ActivityStoryRing(
                                  radius: 30,
                                  hasStory: hasStory,
                                  hasUnseenStory:
                                      hasStory &&
                                      ActivityRepository.groupHasUnseenStory(
                                        _controller.userStories[friendId]!,
                                        viewedIds,
                                      ),
                                  avatarUrl: avatarUrl,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                // Dibujamos el punto si están jugando O si están online
                                if (isPlaying || isOnline)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 17,
                                      height: 17,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // Prioridad al color verde si están jugando, azul si solo están en la app
                                        color: isPlaying
                                            ? playingColor
                                            : onlineColor,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isPlaying
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isPlaying ? playingColor : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildFriendsHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Amigos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        _buildFriendsStrip(),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isGuest) {
          return Scaffold(
            appBar: AppBar(title: const CorpusScreenTitle('Actividad')),
            body: Center(
              child: GuestLoginPrompt(
                iconWidget: CorpusTablerIcon.users(
                  size: 56,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.6),
                ),
                message: 'Inicia sesión para ver la actividad de tus amigos.',
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const CorpusScreenTitle('Actividad'),
            actions: [
              IconButton(
                icon: ValueListenableBuilder<int>(
                  valueListenable: unreadNotificationsCount,
                  builder: (context, count, _) => Badge(
                    isLabelVisible: count > 0,
                    label: Text(count.toString()),
                    child: const CorpusTablerIcon.bell(),
                  ),
                ),
                tooltip: 'Notificaciones',
                onPressed: () => context.pushNotificationsFeed(),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: _controller.pendingRequestsCount > 0,
                  label: Text(_controller.pendingRequestsCount.toString()),
                  child: const CorpusTablerIcon.users(),
                ),
                tooltip: 'Amigos',
                onPressed: _openFriendsScreen,
              ),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await _controller.fetchActivity(isRefresh: true);
                    await _fetchFriendsStrip();
                  },
                  child: _controller.activities.isEmpty
                      ? ListView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: getBottomSpacer(context),
                          ),

                          children: [
                            _buildFriendsHeaderSection(),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: getBottomSpacer(context),
                          ),

                          itemCount:
                              _controller.activities.length +
                              1 +
                              (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildFriendsHeaderSection();
                            }
                            final activityIndex = index - 1;
                            if (activityIndex >=
                                _controller.activities.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildActivityCard(
                              _controller.activities[activityIndex],
                              activityIndex,
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}
