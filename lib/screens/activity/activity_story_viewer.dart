import 'dart:ui';

import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/globals.dart';
import '../../models/models.dart';
import '../../repositories/activity_repository.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_network_image.dart';
import '../library/game_details_screen.dart';
import 'activity_formatters.dart';

/// Un amigo + sus historias, para navegación encadenada tipo Instagram.
class StoryGroup {
  const StoryGroup({required this.userData, required this.activities});
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> activities;
}

/// Visor de "historias" generadas automáticamente a partir del feed de actividad.
class ActivityStoryViewer extends StatefulWidget {
  const ActivityStoryViewer({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialActivityIndex = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialActivityIndex;

  @override
  State<ActivityStoryViewer> createState() => _ActivityStoryViewerState();
}

class _ActivityStoryViewerState extends State<ActivityStoryViewer>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(seconds: 10);

  final _repo = ActivityRepository();
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();

  late int _groupIndex;
  late int _activityIndex;
  final Set<String> _viewedThisSession = {};
  int _slideDirection = 1;

  late AnimationController _progressController;
  bool _isPaused = false;

  int _likesCount = 0;
  bool _hasLiked = false;

  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    _activityIndex = widget.initialActivityIndex.clamp(
      0,
      widget.groups[_groupIndex].activities.length - 1,
    );
    _progressController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    )..addStatusListener(_onProgressComplete);

    _commentFocusNode.addListener(_onCommentFocusChanged);
    _loadReviewInteractions();
    _markCurrentActivityAsViewed();
    _startSlide();
  }

  @override
  void dispose() {
    _commentFocusNode.removeListener(_onCommentFocusChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentActivity =>
      widget.groups[_groupIndex].activities[_activityIndex];
  Map<String, dynamic> get _currentUserData =>
      widget.groups[_groupIndex].userData;

  Map<String, dynamic>? get _currentReview =>
      _currentActivity['_review'] as Map<String, dynamic>?;

  bool get _isReviewSlide =>
      !ActivityRepository.isGroupedActivity(_currentActivity) &&
      _currentReview?['id'] != null;

  void _onCommentFocusChanged() {
    _togglePause(_commentFocusNode.hasFocus);
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isPaused) {
      _goNext();
    }
  }

  void _startSlide() {
    _progressController
      ..duration = _slideDuration
      ..reset()
      ..forward();
  }

  Future<void> _loadReviewInteractions() async {
    final review = _currentReview;
    final reviewId = review?['id'] as String?;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (!_isReviewSlide || reviewId == null || userId == null) {
      setState(() {
        _likesCount = 0;
        _hasLiked = false;
      });
      return;
    }

    // Datos precargados del feed (evita parpadeo)
    final cachedLikes = review?['review_likes'] as List? ?? [];

    setState(() {
      _likesCount = cachedLikes.length;
      _hasLiked = cachedLikes.any((l) => l['user_id'] == userId);
    });

    try {
      final result = await _repo.fetchInteractions(reviewId, userId);
      if (!mounted || _currentReview?['id'] != reviewId) return;
      setState(() {
        _likesCount = result.likesCount;
        _hasLiked = result.hasLiked;
      });
    } catch (e) {
      debugPrint('[ActivityStoryViewer] fetchInteractions failed: $e');
    } finally {}
  }

  void _markCurrentActivityAsViewed() {
    final ids = ActivityRepository.activityIdsOf(_currentActivity);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (ids.isEmpty || myId == null) return;
    final unseenIds = ids
        .where((id) => !_viewedThisSession.contains(id))
        .toList();
    if (unseenIds.isEmpty) return;
    _viewedThisSession.addAll(unseenIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewedStoryIdsNotifier.value = {
        ...viewedStoryIdsNotifier.value,
        ...unseenIds,
      }; // optimista
    });
    _repo
        .markStoriesViewed(userId: myId, activityIds: unseenIds)
        .catchError((_) {}); // persistir, fire-and-forget
  }

  void _afterSlideChange() {
    _commentController.clear();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadReviewInteractions();
    _markCurrentActivityAsViewed();
    _startSlide();
  }

  void _goNext() {
    final activities = widget.groups[_groupIndex].activities;
    if (_activityIndex < activities.length - 1) {
      setState(() => _activityIndex++);
      _afterSlideChange();
      return;
    }

    final nextGroupIndex = _groupIndex + 1;
    if (nextGroupIndex >= widget.groups.length) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _slideDirection = 1;
      _groupIndex = nextGroupIndex;
      // Si ya la vio entera, firstUnseenIndex devuelve 0 → la re-reproduce
      // desde el principio, igual que si la tocara manualmente en la franja.
      _activityIndex = ActivityRepository.firstUnseenIndex(
        widget.groups[nextGroupIndex].activities,
        viewedStoryIdsNotifier.value,
      );
    });
    _afterSlideChange();
  }

  void _goPrevious() {
    if (_activityIndex > 0) {
      setState(() => _activityIndex--);
      _afterSlideChange();
      return;
    }
    if (_groupIndex > 0) {
      setState(() {
        _slideDirection = -1;
        _groupIndex--;
        _activityIndex = widget.groups[_groupIndex].activities.length - 1;
      });
      _afterSlideChange();
      return;
    }
    _progressController
      ..reset()
      ..forward(); // ya en el primer slide del primer amigo
  }

  void _goNextGroup() {
    final nextGroupIndex = _groupIndex + 1;
    if (nextGroupIndex >= widget.groups.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _slideDirection = 1;
      _groupIndex = nextGroupIndex;
      _activityIndex = ActivityRepository.firstUnseenIndex(
        widget.groups[nextGroupIndex].activities,
        viewedStoryIdsNotifier.value,
      );
    });
    _afterSlideChange();
  }

  void _goPreviousGroup() {
    if (_groupIndex > 0) {
      setState(() {
        _slideDirection = -1;
        _groupIndex--;
        _activityIndex = widget.groups[_groupIndex].activities.length - 1;
      });
      _afterSlideChange();
      return;
    }
    _progressController
      ..reset()
      ..forward();
  }

  void _togglePause(bool paused) {
    if (_isPaused == paused) return;
    setState(() => _isPaused = paused);
    if (paused) {
      _progressController.stop();
    } else {
      _progressController.forward();
    }
  }

  Future<void> _toggleLike() async {
    final review = _currentReview;
    final reviewId = review?['id'] as String?;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (reviewId == null || userId == null) return;

    final wasLiked = _hasLiked;
    setState(() {
      _hasLiked = !wasLiked;
      _likesCount += wasLiked ? -1 : 1;
    });

    try {
      await _repo.toggleLike(
        reviewId: reviewId,
        userId: userId,
        currentlyLiked: wasLiked,
      );
    } catch (e) {
      debugPrint('[ActivityStoryViewer] toggleLike failed: $e');
      if (mounted) {
        setState(() {
          _hasLiked = wasLiked;
          _likesCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmittingComment) return;

    final reviewId = _currentReview?['id'] as String?;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (reviewId == null || userId == null) return;

    setState(() => _isSubmittingComment = true);
    try {
      await _repo.submitComment(
        reviewId: reviewId,
        userId: userId,
        content: content,
        commentImage: null,
        attachedGame: null,
      );
      _commentController.clear();
      await _loadReviewInteractions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar comentario: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _openGameDetails(Map<String, dynamic> gameData) {
    _togglePause(true);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final future = isDesktop
        ? context.pushGameDetails(Game.fromMap(gameData))
        : showModalBottomSheet(
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
          );
    future.then((_) {
      if (mounted) _togglePause(false);
    });
  }

  void _openFullReview(
    Map<String, dynamic> gameData,
    Map<String, dynamic> review,
  ) {
    _togglePause(true);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.context.pushReviewDetails(
      Game.fromMap(gameData),
      _currentUserData,
      review,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = _currentActivity;
    final gameData = activity['games'] as Map<String, dynamic>? ?? {};
    final meta = activity['metadata'] as Map<String, dynamic>? ?? {};
    final review = _currentReview;

    final gameTitle = gameData['title'] as String? ?? 'Juego desconocido';
    final coverUrl = gameData['cover_url'] as String?;
    final actionType = activity['action_type'] as String? ?? 'status_change';
    final status = meta['status'] as String? ?? review?['status'] as String?;
    final dateStr = ActivityFormatters.formatRelativeDate(
      activity['created_at'] as String? ?? '',
    );

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final userId = _currentUserData['id'] as String?;
    final isOwn = myId != null && myId == userId;
    final displayName = ActivityFormatters.displayName(_currentUserData);
    final avatarUrl = _currentUserData['avatar_url'] as String?;

    final actionText = ActivityFormatters.actionText(
      actionType,
      status,
      isOwnActivity: isOwn,
    );
    final actionIcon = ActivityFormatters.actionIcon(actionType, status);
    final actionColor = ActivityFormatters.actionColor(
      actionType,
      status,
      context,
    );

    final rating = review != null
        ? (review['rating'] as num?)?.toDouble()
        : (meta['rating'] as num?)?.toDouble();
    final comment =
        review?['comment'] as String? ?? meta['comment'] as String? ?? '';
    final playTimeHours = (review?['play_time_hours'] as num?)?.toDouble();
    final replayCount = review?['replay_count'] as int? ?? 0;

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    final isMobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      backgroundColor: cs.scrim,
      resizeToAvoidBottomInset: true,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _goPrevious();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goNext();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Dismissible(
          key: const Key('story_dismiss'),
          direction: isMobile ? DismissDirection.down : DismissDirection.none,
          resizeDuration: null,
          onUpdate: (details) {
            if (details.progress > 0) {
              if (!_isPaused) _togglePause(true);
            } else {
              if (_isPaused) _togglePause(false);
            }
          },
          onDismissed: (_) => Navigator.of(context).pop(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final isEntering = child.key == ValueKey(_groupIndex);
              final slideOffset = isEntering
                  ? _slideDirection.toDouble()
                  : -_slideDirection.toDouble();

              final offsetAnimation = Tween<Offset>(
                begin: Offset(slideOffset, 0.0),
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(position: offsetAnimation, child: child);
            },
            child: Stack(
              key: ValueKey(_groupIndex),
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: CorpusNetworkImage(
                        url: coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.scrim.withValues(alpha: 0.6),
                          cs.scrim.withValues(alpha: 0.35),
                          cs.scrim.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProgressBars(cs),
                      _buildHeader(
                        cs: cs,
                        userId: userId,
                        avatarUrl: avatarUrl,
                        isOwn: isOwn,
                        displayName: displayName,
                        dateStr: dateStr,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                _isReviewSlide ? 8 : 24,
                              ),
                              child: ActivityRepository.isGroupedActivity(activity)
                                  ? _buildGroupedStatusContent(
                                      cs: cs,
                                      ext: ext,
                                      activity: activity,
                                      actionIcon: actionIcon,
                                      actionColor: actionColor,
                                      isOwn: isOwn,
                                      displayName: displayName,
                                      status: status,
                                    )
                                  : activity['action_type'] == 'reviewed' &&
                                        review != null
                                  ? _buildReviewContent(
                                      cs: cs,
                                      ext: ext,
                                      gameData: gameData,
                                      review: review,
                                      gameTitle: gameTitle,
                                      coverUrl: coverUrl,
                                      status: status,
                                      rating: rating,
                                      comment: comment,
                                      playTimeHours: playTimeHours,
                                      replayCount: replayCount,
                                      isOwn: isOwn,
                                      displayName: displayName,
                                    )
                                  : _buildStatusContent(
                                      cs: cs,
                                      ext: ext,
                                      gameData: gameData,
                                      gameTitle: gameTitle,
                                      coverUrl: coverUrl,
                                      actionIcon: actionIcon,
                                      actionColor: actionColor,
                                      actionText: actionText,
                                      isOwn: isOwn,
                                      displayName: displayName,
                                      status: status,
                                      rating: rating,
                                      comment: comment,
                                    ),
                            ),
                            GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                if (!_isPaused) _togglePause(true);
                              },
                              onHorizontalDragEnd: (details) {
                                _togglePause(false);
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity < -300) {
                                  _goNextGroup();
                                } else if (velocity > 300) {
                                  _goPreviousGroup();
                                }
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapDown: (_) => _togglePause(true),
                                      onTapUp: (_) => _togglePause(false),
                                      onTapCancel: () => _togglePause(false),
                                      onTap: _goPrevious,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapDown: (_) => _togglePause(true),
                                      onTapUp: (_) => _togglePause(false),
                                      onTapCancel: () => _togglePause(false),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapDown: (_) => _togglePause(true),
                                      onTapUp: (_) => _togglePause(false),
                                      onTapCancel: () => _togglePause(false),
                                      onTap: _goNext,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isReviewSlide) _buildCommentBar(cs, ext),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBars(ColorScheme cs) {
    final activities = widget.groups[_groupIndex].activities;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: List.generate(activities.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i < activities.length - 1 ? 4 : 0,
              ),
              child: _buildProgressBar(
                cs,
                index: i,
                currentIndex: _activityIndex,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgressBar(
    ColorScheme cs, {
    required int index,
    required int currentIndex,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: index < currentIndex
            ? ColoredBox(color: cs.onSurface)
            : index == currentIndex
            ? AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.3),
                    color: cs.onSurface,
                  );
                },
              )
            : ColoredBox(color: cs.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildHeader({
    required ColorScheme cs,
    required String? userId,
    required String? avatarUrl,
    required bool isOwn,
    required String displayName,
    required String dateStr,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (userId != null) context.pushProfile(userId: userId);
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: cs.surfaceContainerHighest,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? const CorpusTablerIcon(CorpusIconKind.Person, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwn ? 'Tú' : displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const CorpusTablerIcon(CorpusIconKind.Close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent({
    required ColorScheme cs,
    required CorpusThemeExtension ext,
    required Map<String, dynamic> gameData,
    required String gameTitle,
    required String? coverUrl,
    required CorpusIconKind actionIcon,
    required Color actionColor,
    required String actionText,
    required bool isOwn,
    required String displayName,
    required String? status,
    required double? rating,
    required String comment,
  }) {
    const textShadows = [
      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1.5, 1.5)),
      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    ];

    return Column(
      children: [
        if (coverUrl != null) ...[
          GestureDetector(
            onTap: () => _openGameDetails(gameData),
            child: Container(
              width: 160,
              height: 224,
              decoration: BoxDecoration(
                borderRadius: ext.radiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CorpusNetworkImage(
                url: coverUrl,
                fit: BoxFit.cover,
                width: 160,
                height: 224,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CorpusTablerIcon(actionIcon,
              color: actionColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: cs.onSurface,
                    shadows: textShadows,
                  ),
                  children: [
                    TextSpan(
                      text: isOwn ? 'Tú' : displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' $actionText '),
                    TextSpan(
                      text: gameTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (status != null) ...[
          const SizedBox(height: 12),
          _statusChip(cs, ext, status),
        ],
        if (rating != null && rating > 0) ...[
          const SizedBox(height: 12),
          _ratingRow(cs, rating),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            comment,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupedStatusContent({
    required ColorScheme cs,
    required CorpusThemeExtension ext,
    required Map<String, dynamic> activity,
    required CorpusIconKind actionIcon,
    required Color actionColor,
    required bool isOwn,
    required String displayName,
    required String? status,
  }) {
    const textShadows = [
      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1.5, 1.5)),
      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    ];

    final games = (activity['_games'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final titles = games
        .map((g) => g['title'] as String? ?? 'Juego desconocido')
        .toList();
    final titleParts = ActivityFormatters.splitGroupedGameTitles(
      titles,
      maxShown: 3,
    );
    final groupedAction = ActivityFormatters.groupedActionText(
      status,
      isOwnActivity: isOwn,
    );

    final visibleGames = games.take(kMaxGroupedFeedCards).toList();
    final extraCount = games.length - visibleGames.length;

    return Column(
      children: [
        if (visibleGames.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final gMap in visibleGames)
                GestureDetector(
                  onTap: () => _openGameDetails(gMap),
                  child: Container(
                    width: 84,
                    height: 112,
                    decoration: BoxDecoration(
                      borderRadius: ext.radiusSmall,
                      color: cs.surfaceContainerHighest,
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (gMap['cover_url'] as String?)?.isNotEmpty == true
                        ? CorpusNetworkImage(
                            url: gMap['cover_url'] as String,
                            fit: BoxFit.cover,
                            width: 84,
                            height: 112,
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                gMap['title'] as String? ?? '',
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              if (extraCount > 0)
                Container(
                  width: 84,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: ext.radiusSmall,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$extraCount',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CorpusTablerIcon(
              actionIcon,
              color: actionColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: cs.onSurface,
                    shadows: textShadows,
                  ),
                  children: [
                    TextSpan(
                      text: isOwn ? 'Tú' : displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' $groupedAction '),
                    TextSpan(
                      text: titleParts.shownTitles,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    if (titleParts.moreSuffix != null)
                      TextSpan(text: titleParts.moreSuffix),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (status != null) ...[
          const SizedBox(height: 12),
          _statusChip(cs, ext, status),
        ],
      ],
    );
  }

  Widget _buildReviewContent({
    required ColorScheme cs,
    required CorpusThemeExtension ext,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> review,
    required String gameTitle,
    required String? coverUrl,
    required String? status,
    required double? rating,
    required String comment,
    required double? playTimeHours,
    required int replayCount,
    required bool isOwn,
    required String displayName,
  }) {
    const textShadows = [
      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1.5, 1.5)),
      Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
    ];

    return Column(
      children: [
        if (coverUrl != null) ...[
          GestureDetector(
            onTap: () => _openGameDetails(gameData),
            child: Container(
              width: 160,
              height: 224,
              decoration: BoxDecoration(
                borderRadius: ext.radiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CorpusNetworkImage(
                url: coverUrl,
                fit: BoxFit.cover,
                width: 160,
                height: 224,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          gameTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            shadows: textShadows,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isOwn ? 'Tu reseña' : 'Reseña de $displayName',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.75),
            shadows: textShadows,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (status != null) _statusChip(cs, ext, status),
            if (rating != null && rating > 0) _ratingRow(cs, rating),
            if (playTimeHours != null && playTimeHours > 0)
              _metaChip(
                cs,
                ext,
                icon: CorpusIconKind.AccessTime,
                label: '${playTimeHours.toStringAsFixed(1)} h',
              ),
            if (replayCount > 0)
              _metaChip(
                cs,
                ext,
                icon: CorpusIconKind.Replay,
                label: 'Replay ×$replayCount',
                color: cs.secondary,
              ),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              comment,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _openFullReview(gameData, review),
          icon: const CorpusTablerIcon(CorpusIconKind.ArticleOutlined, size: 18),
          label: const Text('Ver reseña completa'),
        ),
      ],
    );
  }

  Widget _metaChip(
    ColorScheme cs,
    CorpusThemeExtension ext, {
    required CorpusIconKind icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: ext.radiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpusTablerIcon(icon, size: 16, color: color ?? cs.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBar(ColorScheme cs, CorpusThemeExtension ext) {
    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          8 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _toggleLike,
              borderRadius: ext.radiusSmall,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CorpusTablerIcon(_hasLiked ? CorpusIconKind.ThumbUp : CorpusIconKind.ThumbUpAltOutlined,
                      size: 22,
                      color: _hasLiked ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _likesCount > 0 ? _likesCount.toString() : '0',
                      style: TextStyle(
                        color: _hasLiked ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: _hasLiked
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Añadir un comentario...',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: ext.radiusMedium,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  counterText: '',
                ),
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            const SizedBox(width: 8),
            if (_isSubmittingComment)
              const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: CorpusTablerIcon(CorpusIconKind.Send, color: cs.primary),
                tooltip: 'Enviar',
                onPressed: _submitComment,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ColorScheme cs, CorpusThemeExtension ext, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: ext.radiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpusTablerIcon(GameStatus.iconForString(status), size: 16, color: cs.onSurface),
          const SizedBox(width: 6),
          Text(
            GameStatus.labelForString(status),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(ColorScheme cs, double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CorpusTablerIcon(CorpusIconKind.Star, color: cs.secondary, size: 20),
        const SizedBox(width: 4),
        Text(
          formatRating(rating),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
