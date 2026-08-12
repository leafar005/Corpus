import 'dart:ui';

import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../repositories/activity_repository.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_network_image.dart';
import '../../widgets/full_screen_gallery.dart';
import '../library/game_details_screen.dart';
import 'activity_formatters.dart';
import 'review_details_screen.dart';

/// Visor de "historias" generadas automáticamente a partir del feed de actividad.
class ActivityStoryViewer extends StatefulWidget {
  const ActivityStoryViewer({
    super.key,
    required this.userData,
    required this.activities,
    this.initialIndex = 0,
  });

  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> activities;
  final int initialIndex;

  @override
  State<ActivityStoryViewer> createState() => _ActivityStoryViewerState();
}

class _ActivityStoryViewerState extends State<ActivityStoryViewer>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(seconds: 5);

  final _repo = ActivityRepository();
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();

  late int _currentIndex;
  late AnimationController _progressController;
  bool _isPaused = false;

  List<Map<String, dynamic>> _comments = [];
  int _likesCount = 0;
  bool _hasLiked = false;
  bool _isLoadingInteractions = false;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.activities.length - 1);
    _progressController = AnimationController(vsync: this, duration: _slideDuration)
      ..addStatusListener(_onProgressComplete);

    _commentFocusNode.addListener(_onCommentFocusChanged);
    _loadReviewInteractions();
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

  Map<String, dynamic> get _currentActivity => widget.activities[_currentIndex];

  Map<String, dynamic>? get _currentReview =>
      _currentActivity['_review'] as Map<String, dynamic>?;

  bool get _isReviewSlide {
    final review = _currentReview;
    if (review == null) return false;
    return _currentActivity['action_type'] == 'reviewed' ||
        review['id'] != null;
  }

  void _onCommentFocusChanged() {
    _togglePause(_commentFocusNode.hasFocus);
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isPaused && !_isReviewSlide) {
      _goNext();
    }
  }

  void _startSlide() {
    if (_isReviewSlide) {
      _progressController.stop();
      return;
    }
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
        _comments = [];
        _likesCount = 0;
        _hasLiked = false;
        _isLoadingInteractions = false;
      });
      return;
    }

    setState(() => _isLoadingInteractions = true);

    // Datos precargados del feed (evita parpadeo)
    final cachedLikes = review?['review_likes'] as List? ?? [];
    final cachedComments = review?['review_comments'] as List? ?? [];

    setState(() {
      _likesCount = cachedLikes.length;
      _hasLiked = cachedLikes.any((l) => l['user_id'] == userId);
      _comments = cachedComments
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
    });

    try {
      final result = await _repo.fetchInteractions(reviewId, userId);
      if (!mounted || _currentReview?['id'] != reviewId) return;
      setState(() {
        _comments = result.comments;
        _likesCount = result.likesCount;
        _hasLiked = result.hasLiked;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingInteractions = false);
    }
  }

  void _goNext() {
    if (_currentIndex < widget.activities.length - 1) {
      setState(() {
        _currentIndex++;
        _commentController.clear();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      _loadReviewInteractions();
      _startSlide();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _commentController.clear();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      _loadReviewInteractions();
      _startSlide();
    } else if (!_isReviewSlide) {
      _progressController
        ..reset()
        ..forward();
    }
  }

  void _togglePause(bool paused) {
    if (_isPaused == paused) return;
    setState(() => _isPaused = paused);
    if (_isReviewSlide) return;
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
    } catch (_) {
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
        ? context.pushGameDetails(gameData)
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
                gameData: gameData,
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewDetailsScreen(
          gameData: gameData,
          userData: widget.userData,
          reviewData: review,
          focusComment: false,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadReviewInteractions();
        _togglePause(false);
      }
    });
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
    final status = meta['status'] as String? ??
        review?['status'] as String?;
    final dateStr = ActivityFormatters.formatRelativeDate(
      activity['created_at'] as String? ?? '',
    );

    final myId = Supabase.instance.client.auth.currentUser?.id;
    final userId = widget.userData['id'] as String?;
    final isOwn = myId != null && myId == userId;
    final displayName = ActivityFormatters.displayName(widget.userData);
    final avatarUrl = widget.userData['avatar_url'] as String?;

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
    final imageUrls = review?['image_urls'] as List? ?? [];
    final playTimeHours = (review?['play_time_hours'] as num?)?.toDouble();
    final replayCount = review?['replay_count'] as int? ?? 0;

    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    return Scaffold(
      backgroundColor: cs.scrim,
      resizeToAvoidBottomInset: true,
      body: Stack(
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
                        child: _isReviewSlide && review != null
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
                                imageUrls: imageUrls,
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
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _goPrevious,
                            ),
                          ),
                          const Expanded(flex: 2, child: SizedBox()),
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _goNext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isReviewSlide && review != null)
                  _buildCommentBar(cs, ext),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBars(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: List.generate(widget.activities.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i < widget.activities.length - 1 ? 4 : 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: i < _currentIndex
                      ? ColoredBox(color: cs.onSurface)
                      : i == _currentIndex
                      ? _isReviewSlide
                            ? ColoredBox(color: cs.onSurface)
                            : AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  return LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor: cs.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                                    color: cs.onSurface,
                                  );
                                },
                              )
                      : ColoredBox(
                          color: cs.onSurface.withValues(alpha: 0.3),
                        ),
                ),
              ),
            ),
          );
        }),
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
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 18)
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
            icon: const Icon(Icons.close),
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
    required IconData actionIcon,
    required Color actionColor,
    required String actionText,
    required bool isOwn,
    required String displayName,
    required String? status,
    required double? rating,
    required String comment,
  }) {
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
            Icon(actionIcon, color: actionColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: cs.onSurface,
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
    required List<dynamic> imageUrls,
    required double? playTimeHours,
    required int replayCount,
    required bool isOwn,
    required String displayName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl != null)
              GestureDetector(
                onTap: () => _openGameDetails(gameData),
                child: Container(
                  width: 88,
                  height: 124,
                  decoration: BoxDecoration(
                    borderRadius: ext.radiusSmall,
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CorpusNetworkImage(
                    url: coverUrl,
                    fit: BoxFit.cover,
                    width: 88,
                    height: 124,
                  ),
                ),
              ),
            if (coverUrl != null) const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOwn ? 'Tu reseña' : 'Reseña de $displayName',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    _statusChip(cs, ext, status),
                  ],
                  if (rating != null && rating > 0) ...[
                    const SizedBox(height: 8),
                    _ratingRow(cs, rating),
                  ],
                  if (playTimeHours != null && playTimeHours > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${playTimeHours.toStringAsFixed(1)} h',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (replayCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.replay, size: 16, color: cs.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Replay ×$replayCount',
                          style: TextStyle(
                            color: cs.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.4),
              borderRadius: ext.radiusMedium,
            ),
            child: Text(
              comment,
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
        ],
        if (imageUrls.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final url = imageUrls[idx].toString();
                return GestureDetector(
                  onTap: () async {
                    _togglePause(true);
                    await showDialog(
                      context: context,
                      builder: (context) => FullScreenGallery(
                        imageUrls: imageUrls.map((e) => e.toString()).toList(),
                        initialIndex: idx,
                      ),
                    );
                    if (mounted) _togglePause(false);
                  },
                  child: ClipRRect(
                    borderRadius: ext.radiusSmall,
                    child: CorpusNetworkImage(
                      url: url,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            InkWell(
              onTap: _toggleLike,
              borderRadius: ext.radiusSmall,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                      size: 20,
                      color: _hasLiked ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _likesCount.toString(),
                      style: TextStyle(
                        color: _hasLiked ? cs.primary : cs.onSurfaceVariant,
                        fontWeight:
                            _hasLiked ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              _comments.length.toString(),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _openFullReview(gameData, review),
              child: const Text('Ver reseña completa'),
            ),
          ],
        ),
        if (_isLoadingInteractions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_comments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Comentarios',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          ..._comments.take(5).map((c) => _buildCommentTile(cs, ext, c)),
          if (_comments.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => _openFullReview(gameData, review),
                child: Text('Ver los ${_comments.length} comentarios'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCommentTile(
    ColorScheme cs,
    CorpusThemeExtension ext,
    Map<String, dynamic> comment,
  ) {
    final user = comment['users'] as Map<String, dynamic>? ?? {};
    final author =
        user['display_name'] as String? ?? user['username'] as String? ?? 'Usuario';
    final avatar = user['avatar_url'] as String?;
    final content = comment['content'] as String? ?? '';
    final createdAt = ActivityFormatters.formatRelativeDate(
      comment['created_at'] as String? ?? '',
    );

    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null ? const Icon(Icons.person, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.35),
                borderRadius: ext.radiusSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ],
              ),
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
                icon: Icon(Icons.send, color: cs.primary),
                tooltip: 'Enviar',
                onPressed: _submitComment,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(
    ColorScheme cs,
    CorpusThemeExtension ext,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: ext.radiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(GameStatus.iconForString(status), size: 16, color: cs.onSurface),
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
        Icon(Icons.star, color: cs.secondary, size: 20),
        const SizedBox(width: 4),
        Text(
          formatRating(rating),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
