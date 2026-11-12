import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/format_utils.dart';
import '../../widgets/corpus_network_image.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../library/game_details_screen.dart';
import '../library/review_modal.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../widgets/achievement_toast.dart';
import '../../models/models.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/coop_badge.dart';
import 'review_details/review_details_controller.dart';
import 'widgets/comment_composer.dart';
import 'widgets/comment_thread_section.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Game gameData;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic> reviewData;
  final String? postId;
  final bool focusComment;

  const ReviewDetailsScreen({
    super.key,
    required this.gameData,
    required this.userData,
    required this.reviewData,
    this.postId,
    this.focusComment = false,
  });

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  late final ReviewDetailsController _controller;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  XFile? _commentImage;
  Map<String, dynamic>? _selectedGameForComment;
  String? _replyToCommentId;
  String? _replyToUsername;

  Map<String, dynamic> get _currentReviewData => _controller.currentReviewData;
  bool get _isLoading => _controller.isLoading;
  int get _likesCount => _controller.likesCount;
  bool get _hasLiked => _controller.hasLiked;
  List<Map<String, dynamic>> get _comments => _controller.comments;
  bool get _isSubmitting => _controller.isSubmitting;
  List<Map<String, dynamic>> get _partnersData => _controller.partnersData;

  @override
  void initState() {
    super.initState();
    _controller = ReviewDetailsController(
      initialReviewData: widget.reviewData,
      game: widget.gameData,
      postId: widget.postId,
    );
    _controller.fetchInteractions();
    _controller.fetchPartner();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    await _controller.toggleLike();
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty &&
        _commentImage == null &&
        _selectedGameForComment == null) {
      return;
    }

    try {
      await _controller.submitComment(
        content: content,
        commentImage: _commentImage,
        attachedGame: _selectedGameForComment,
        parentCommentId: _replyToCommentId,
      );
      _commentController.clear();
      setState(() {
        _commentImage = null;
        _selectedGameForComment = null;
        _replyToCommentId = null;
        _replyToUsername = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar comentario: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId, {String? imageUrl}) async {
    try {
      await _controller.deleteComment(commentId, imageUrl: imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comentario eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar comentario: $e')),
        );
      }
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    final user = comment['users'] as Map<String, dynamic>?;
    final targetUsername = user?['username']?.toString() ?? 'Usuario';
    final prefix = '@$targetUsername ';
    final withoutOldPrefix = _commentController.text.replaceFirst(
      RegExp(r'^@\w+\s*'),
      '',
    );

    setState(() {
      _replyToCommentId = comment['id'] as String?;
      _replyToUsername = targetUsername;
      _commentController.text = prefix + withoutOldPrefix;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    if (_replyToCommentId == null) return;
    setState(() {
      _replyToCommentId = null;
      _replyToUsername = null;
      _commentController.text = _commentController.text.replaceFirst(
        RegExp(r'^@\w+\s*'),
        '',
      );
    });
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: const Text('¿Seguro que quieres eliminar esta reseña?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _controller.deleteReview(reviewId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reseña eliminada')));
        libraryUpdateNotifier.value++;
        AppNavigationController.instance.requestBack(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar reseña: $e')));
      }
    }
  }

  void _editReview() {
    final rating = (_currentReviewData['rating'] ?? 0).toDouble();
    final ratingGameplay = (_currentReviewData['rating_gameplay'] ?? 0)
        .toDouble();
    final ratingNarrative = (_currentReviewData['rating_narrative'] ?? 0)
        .toDouble();
    final ratingSoundtrack = (_currentReviewData['rating_soundtrack'] ?? 0)
        .toDouble();
    final ratingVisuals = (_currentReviewData['rating_visuals'] ?? 0)
        .toDouble();
    final metadata =
        _currentReviewData['metadata'] as Map<String, dynamic>? ?? {};
    final status =
        _currentReviewData['status'] ?? metadata['status'] ?? 'beaten';

    ReviewModal.show(
      context: context,
      gameData: widget.gameData.toMap(),
      enrichedData: widget.gameData.toMap(),
      existingReview: Review.fromMap(_currentReviewData),
      currentPartnerIds: _partnersData.map((e) => e['id'] as String).toList(),
      isSaving: _isSubmitting,
      currentRating: rating,
      currentRatingGameplay: ratingGameplay,
      currentRatingNarrative: ratingNarrative,
      currentRatingSoundtrack: ratingSoundtrack,
      currentRatingVisuals: ratingVisuals,
      currentStatus: status,
      initialComment:
          _currentReviewData['comment'] ?? _currentReviewData['content'] ?? '',
      onSave: _saveReviewModal,
    );
  }

  Future<bool> _saveReviewModal({
    String? reviewId,
    required double rating,
    required double ratingGameplay,
    required double ratingNarrative,
    required double ratingSoundtrack,
    required double ratingVisuals,
    required String comment,
    required String status,
    required String completionType,
    required bool isReplay,
    required int? replayNumber,
    required String? platform,
    required double? playTimeHours,
    required DateTime? playedFrom,
    required DateTime? playedUntil,
    required int? progressPercent,
    required DateTime? reviewDate,
    required List<XFile> newImages,
    required List<String> existingImages,
    required List<String> partnerIds,
  }) async {
    try {
      final result = await _controller.saveReviewModal(
        reviewId: reviewId,
        rating: rating,
        ratingGameplay: ratingGameplay,
        ratingNarrative: ratingNarrative,
        ratingSoundtrack: ratingSoundtrack,
        ratingVisuals: ratingVisuals,
        comment: comment,
        status: status,
        completionType: completionType,
        isReplay: isReplay,
        replayNumber: replayNumber,
        platform: platform,
        playTimeHours: playTimeHours,
        playedFrom: playedFrom,
        playedUntil: playedUntil,
        progressPercent: progressPercent,
        reviewDate: reviewDate,
        newImages: newImages,
        existingImages: existingImages,
        partnerIds: partnerIds,
      );

      // Mostrar toasts de logros si se han desbloqueado al editar
      if (mounted && result.newAchievementDetails.isNotEmpty) {
        AchievementToast.showFromList(
          context,
          result.newAchievementDetails,
          isMounted: () => mounted,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reseña actualizada con éxito')),
        );
        libraryUpdateNotifier.value++;
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar reseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  String _getStatusText(String status) => GameStatus.labelForString(status);

  CorpusIconKind _getStatusIcon(String status) =>
      GameStatus.iconForString(status);

  String _getCompletionTypeText(String type) {
    switch (type) {
      case 'story':
        return 'Historia';
      case 'story_extras':
        return 'Historia + Extras';
      case '100_percent':
        return 'Platino';
      case 'endless':
        return 'Sin Fin';
      case 'on_hold':
        return 'En Pausa';
      default:
        return type;
    }
  }

  CorpusIconKind _getCompletionTypeIcon(String type) {
    switch (type) {
      case 'story':
        return CorpusIconKind.AutoStories;
      case 'story_extras':
        return CorpusIconKind.Extension;
      case '100_percent':
        return CorpusIconKind.EmojiEvents;
      case 'endless':
        return CorpusIconKind.AllInclusive;
      case 'on_hold':
        return CorpusIconKind.Pause;
      default:
        return CorpusIconKind.Flag;
    }
  }

  Widget _buildInfoBadge(
    String label,
    CorpusIconKind icon,
    Color color, {
    Widget? customIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusMedium,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          customIcon ?? CorpusTablerIcon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubRatingBadge(
    String label,
    double rating,
    CorpusIconKind icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusMedium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpusTablerIcon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            formatRating(rating),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final title = widget.gameData.title.isNotEmpty
        ? widget.gameData.title
        : 'Desconocido';
    final coverUrl = widget.gameData.coverUrl ?? '';
    final username = widget.userData?['username'] ?? 'Jugador';
    final avatarUrl = widget.userData?['avatar_url'];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Extract all fields from reviewData
    final rating = (_currentReviewData['rating'] ?? 0).toDouble();
    final comment =
        _currentReviewData['comment'] ?? _currentReviewData['content'] ?? '';
    final metadata =
        _currentReviewData['metadata'] as Map<String, dynamic>? ?? {};
    final status =
        _currentReviewData['status'] ?? metadata['status'] ?? 'unknown';
    final createdAt = _currentReviewData['created_at'];
    final completionType = _currentReviewData['completion_type'] ?? 'story';
    final isReplay = _currentReviewData['is_replay'] ?? false;
    final replayNumber = _currentReviewData['replay_number'];
    final platform = _currentReviewData['platform'];
    final List<dynamic> imageUrls = _currentReviewData['image_urls'] ?? [];
    final playTimeHours = (_currentReviewData['play_time_hours'] ?? 0)
        .toDouble();
    final playedFrom = _currentReviewData['played_from'];
    final playedUntil = _currentReviewData['played_until'];
    final progressPercent = _currentReviewData['progress_percent'];

    final ratingGameplay = (_currentReviewData['rating_gameplay'] ?? 0)
        .toDouble();
    final ratingNarrative = (_currentReviewData['rating_narrative'] ?? 0)
        .toDouble();
    final ratingSoundtrack = (_currentReviewData['rating_soundtrack'] ?? 0)
        .toDouble();
    final ratingVisuals = (_currentReviewData['rating_visuals'] ?? 0)
        .toDouble();

    final dateStr = createdAt != null ? formatDateLong(createdAt) : '';

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const CorpusTablerIcon(CorpusIconKind.ArrowBack),
              onPressed: () =>
                  AppNavigationController.instance.requestBack(context),
            ),
            title: CorpusScreenTitle(
              title,
              abbreviateIfLong: true,
              trailingBalanceWidth:
                  CorpusVisuallyBalancedTitle.defaultLeadingWidth,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const CorpusTablerIcon(CorpusIconKind.Share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compartir próximamente')),
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Info
                              GestureDetector(
                                onTap: () {
                                  final userId = _currentReviewData['user_id'];
                                  if (userId != null) {
                                    context.pushProfile(userId: userId);
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
                                          ? const CorpusTablerIcon(
                                              CorpusIconKind.Person,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '@$username',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    if (_currentReviewData['user_id'] ==
                                        Supabase
                                            .instance
                                            .client
                                            .auth
                                            .currentUser
                                            ?.id)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: CorpusTablerIcon(
                                              CorpusIconKind.EditOutlined,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            tooltip: 'Editar reseña',
                                            onPressed: _editReview,
                                          ),
                                          IconButton(
                                            icon: CorpusTablerIcon(
                                              CorpusIconKind.DeleteOutline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            tooltip: 'Eliminar reseña',
                                            onPressed: () => _deleteReview(
                                              _currentReviewData['id'],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Badges: completion type, replay, platform
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (completionType != 'none')
                                    _buildInfoBadge(
                                      _getCompletionTypeText(completionType),
                                      _getCompletionTypeIcon(completionType),
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  if (isReplay)
                                    _buildInfoBadge(
                                      'Rejugada${replayNumber != null ? ' #$replayNumber' : ''}',
                                      CorpusIconKind.Replay,
                                      Colors.orangeAccent,
                                    ),
                                  if (platform != null)
                                    Builder(
                                      builder: (context) {
                                        final pStyle =
                                            IgdbConstants.getPlatformStyle(
                                              platform,
                                            );
                                        final pColor =
                                            pStyle['color'] as Color? ??
                                            Colors.blueGrey;
                                        final iconPath =
                                            pStyle['icon'] as String?;
                                        final fallbackIcon =
                                            pStyle['fallbackIcon']
                                                as CorpusIconKind?;

                                        Widget? customIcon;
                                        if (iconPath != null) {
                                          customIcon = Image.asset(
                                            iconPath,
                                            width: 14,
                                            height: 14,
                                            color: pColor,
                                          );
                                        } else if (fallbackIcon != null) {
                                          customIcon = CorpusTablerIcon(
                                            fallbackIcon,
                                            size: 14,
                                            color: pColor,
                                          );
                                        }

                                        return _buildInfoBadge(
                                          platform,
                                          CorpusIconKind.Devices,
                                          pColor,
                                          customIcon: customIcon,
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Game Mini-Card and Rating
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cover Image
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {
                                        final isDesktop =
                                            MediaQuery.of(context).size.width >
                                            800;
                                        if (isDesktop) {
                                          context.pushGameDetails(
                                            widget.gameData,
                                          );
                                        } else {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: false,
                                            enableDrag: true,
                                            builder: (context) =>
                                                DraggableScrollableSheet(
                                                  initialChildSize: 1.0,
                                                  minChildSize: 0.5,
                                                  maxChildSize: 1.0,
                                                  expand: false,
                                                  snap: true,
                                                  builder:
                                                      (
                                                        context,
                                                        scrollController,
                                                      ) {
                                                        return GameDetailsScreen(
                                                          gameData:
                                                              widget.gameData,
                                                          scrollController:
                                                              scrollController,
                                                        );
                                                      },
                                                ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        width: 100,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          borderRadius: Theme.of(context)
                                              .extension<
                                                CorpusThemeExtension
                                              >()!
                                              .radiusSmall,
                                          color: Theme.of(
                                            context,
                                          ).primaryColorDark,
                                          image: coverUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(coverUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: coverUrl.isEmpty
                                            ? Center(
                                                child: CorpusTablerIcon(
                                                  CorpusIconKind.VideogameAsset,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.54),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Rating & Status
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (rating > 0) ...[
                                          Row(
                                            children: [
                                              CorpusTablerIcon(
                                                CorpusIconKind.Star,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formatRating(rating),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (ratingGameplay > 0 ||
                                            ratingNarrative > 0 ||
                                            ratingSoundtrack > 0 ||
                                            ratingVisuals > 0) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (ratingGameplay > 0)
                                                _buildSubRatingBadge(
                                                  'Gameplay',
                                                  ratingGameplay,
                                                  CorpusIconKind.SportsEsports,
                                                ),
                                              if (ratingNarrative > 0)
                                                _buildSubRatingBadge(
                                                  'Narrativa',
                                                  ratingNarrative,
                                                  CorpusIconKind.AutoStories,
                                                ),
                                              if (ratingSoundtrack > 0)
                                                _buildSubRatingBadge(
                                                  'Banda Sonora',
                                                  ratingSoundtrack,
                                                  CorpusIconKind.MusicNote,
                                                ),
                                              if (ratingVisuals > 0)
                                                _buildSubRatingBadge(
                                                  'Visuales',
                                                  ratingVisuals,
                                                  CorpusIconKind.Brush,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        Row(
                                          children: [
                                            CorpusTablerIcon(
                                              _getStatusIcon(status),
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getStatusText(status),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_partnersData.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: _partnersData.map((
                                              partner,
                                            ) {
                                              return CoopBadge(
                                                username:
                                                    partner['username'] ??
                                                    'Usuario',
                                                avatarUrl:
                                                    partner['avatar_url'],
                                                status: status,
                                                userId:
                                                    partner['id'] as String?,
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Review Content
                              if (comment.isNotEmpty)
                                Text(
                                  comment,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),

                              if (imageUrls.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                if (isDesktop)
                                  SizedBox(
                                    height: 140,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: imageUrls.length,
                                      itemBuilder: (context, idx) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              final strUrls = imageUrls
                                                  .map((e) => e.toString())
                                                  .toList();
                                              showFullScreenGallery(
                                                context,
                                                strUrls,
                                                idx,
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius: Theme.of(context)
                                                  .extension<
                                                    CorpusThemeExtension
                                                  >()!
                                                  .radiusSmall,
                                              child: CorpusNetworkImage(
                                                url: imageUrls[idx],
                                                height: isDesktop ? 280 : 140,
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                                          showFullScreenGallery(
                                            context,
                                            strUrls,
                                            idx,
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: Theme.of(context)
                                              .extension<
                                                CorpusThemeExtension
                                              >()!
                                              .radiusSmall,
                                          child: CorpusNetworkImage(
                                            url: imageUrls[idx],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],

                              // Extra info
                              if (playTimeHours > 0 ||
                                  playedFrom != null ||
                                  progressPercent != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: Theme.of(context)
                                        .extension<CorpusThemeExtension>()!
                                        .radiusMedium,
                                  ),
                                  child: Column(
                                    children: [
                                      if (playTimeHours > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              CorpusTablerIcon(
                                                CorpusIconKind.AccessTime,
                                                size: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${playTimeHours.toStringAsFixed(1)} horas',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (playedFrom != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              CorpusTablerIcon(
                                                CorpusIconKind.CalendarToday,
                                                size: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formatDateRange(
                                                  playedFrom?.toString(),
                                                  playedUntil?.toString(),
                                                ),
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (progressPercent != null)
                                        Row(
                                          children: [
                                            CorpusTablerIcon(
                                              CorpusIconKind.PieChart,
                                              size: 16,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$progressPercent% completado',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              // Date
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 16),
                              Divider(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.24),
                              ),
                              const SizedBox(height: 8),

                              // Like and Comment Buttons
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _toggleLike,
                                    icon: CorpusTablerIcon(
                                      _hasLiked
                                          ? CorpusIconKind.ThumbUp
                                          : CorpusIconKind.ThumbUpAltOutlined,
                                      size: 18,
                                      color: _hasLiked
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                    label: Text(
                                      _likesCount.toString(),
                                      style: TextStyle(
                                        color: _hasLiked
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      side: BorderSide(
                                        color: _hasLiked
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                      ),
                                      backgroundColor: _hasLiked
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1)
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: Theme.of(context)
                                            .extension<CorpusThemeExtension>()!
                                            .radiusLarge,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _commentFocusNode.requestFocus(),
                                    icon: const CorpusTablerIcon(
                                      CorpusIconKind.ChatBubbleOutline,
                                      size: 18,
                                    ),
                                    label: Text(_comments.length.toString()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: Theme.of(context)
                                            .extension<CorpusThemeExtension>()!
                                            .radiusLarge,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Comments List
                              if (_comments.isNotEmpty) ...[
                                CommentThreadSection(
                                  comments: _comments,
                                  currentUserId: currentUserId,
                                  authorId: widget.userData?['id'] as String?,
                                  onReply: _startReply,
                                  onDeleteComment: (commentId, imageUrl) =>
                                      _deleteComment(
                                        commentId,
                                        imageUrl: imageUrl,
                                      ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Comentario input at the bottom
                    if (!_isLoading)
                      CommentComposer(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        isSubmitting: _isSubmitting,
                        onSubmit: _submitComment,
                        replyToCommentId: _replyToCommentId,
                        replyToUsername: _replyToUsername,
                        onClearReply: _clearReplyTarget,
                        selectedImage: _commentImage,
                        onImageChanged: (img) =>
                            setState(() => _commentImage = img),
                        selectedGame: _selectedGameForComment,
                        onGameChanged: (game) =>
                            setState(() => _selectedGameForComment = game),
                      ),
                  ],
                ),
        );
      },
    );
  }

  // _showImageFullScreen removed in favor of full_screen_gallery.dart
}
