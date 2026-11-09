import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/comment_thread_utils.dart';
import 'package:corpus/utils/format_utils.dart';
import '../../widgets/corpus_network_image.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../library/game_details_screen.dart';
import '../library/review_modal.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../widgets/achievement_toast.dart';
import '../../widgets/mention_text.dart';
import '../../models/models.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../services/igdb_service.dart';
import '../../widgets/coop_badge.dart';
import 'review_details/review_details_controller.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Game gameData;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic> reviewData;
  final bool focusComment;

  const ReviewDetailsScreen({
    super.key,
    required this.gameData,
    required this.userData,
    required this.reviewData,
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
  List<Map<String, dynamic>> get _orderedComments =>
      orderCommentsThreaded(_comments);
  bool get _isSubmitting => _controller.isSubmitting;
  List<Map<String, dynamic>> get _partnersData => _controller.partnersData;

  @override
  void initState() {
    super.initState();
    _controller = ReviewDetailsController(
      initialReviewData: widget.reviewData,
      game: widget.gameData,
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

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este comentario?',
        ),
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
      await _controller.deleteComment(commentId);
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

  /// Delega en [MentionText] el renderizado de texto con menciones `@usuario`.
  Widget _buildCommentContent(String text) => MentionText(text: text);

  /// Tarjeta contenedora con recuadro relleno para un comentario o respuesta.
  Widget _buildCommentCard({
    required Map<String, dynamic> comment,
    required String? currentUserId,
    required bool isDesktop,
  }) {
    final user = comment['users'] as Map<String, dynamic>?;
    final isMyComment = comment['user_id'] == currentUserId;
    final isReviewAuthor = widget.userData?['id'] != null &&
        comment['user_id'] == widget.userData!['id'];
    final threadDepth = comment['_thread_depth'] as int? ?? 0;
    // Solo aplicamos sangría visual para el primer nivel de respuesta. A partir de
    // ahí se mantiene la misma sangría para evitar desbordamiento en pantallas estrechas.
    final visualThreadDepth = threadDepth > 1 ? 1 : threadDepth;
    final isReply = visualThreadDepth > 0;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<CorpusThemeExtension>();
    final borderRadius = ext?.radiusMedium ?? BorderRadius.circular(12);

    final leftIndent = isReply ? (isDesktop ? 48.0 : 36.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: leftIndent),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final uid = comment['user_id'];
                      if (uid != null) {
                        context.pushProfile(
                          userId: uid,
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: user?['avatar_url'] != null
                          ? NetworkImage(
                              user!['avatar_url'],
                            )
                          : null,
                      child: user?['avatar_url'] == null
                          ? const CorpusTablerIcon(
                              CorpusIconKind.Person,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila superior: nombre, autor, fecha.
                        // Padding a la derecha para no solapar con los botones fijados en la esquina.
                        Padding(
                          padding: EdgeInsets.only(
                            right: isMyComment ? 64.0 : 36.0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              final uid = comment['user_id'];
                              if (uid != null) {
                                context.pushProfile(
                                  userId: uid,
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user?['username'] ?? 'Usuario',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isReviewAuthor) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Autor',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  _formatCommentDate(comment['created_at']),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Texto del comentario (ancho completo)
                        if (comment['content'] != null &&
                            comment['content'].toString().isNotEmpty)
                          _buildCommentContent(comment['content']),
                        if (comment['image_url'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GestureDetector(
                              onTap: () => showFullScreenGallery(
                                context,
                                [comment['image_url']],
                                0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CorpusNetworkImage(
                                  url: comment['image_url'],
                                  height: isDesktop ? 300 : 150,
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                            ),
                          ),
                        if (comment['attached_game'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                final gameData = Map<String, dynamic>.from(
                                  comment['attached_game'],
                                );
                                final isDesktop =
                                    MediaQuery.of(context).size.width > 800;
                                if (isDesktop) {
                                  context.pushGameDetails(Game.fromMap(gameData));
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
                                      builder: (context, scrollController) =>
                                          GameDetailsScreen(
                                        gameData: Game.fromMap(gameData),
                                        scrollController: scrollController,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: isDesktop ? 160 : 120,
                                height: isDesktop ? 224 : 168,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context).primaryColorDark,
                                  image: (comment['attached_game']['cover_url'] !=
                                              null ||
                                          comment['attached_game']['cover'] !=
                                              null)
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            comment['attached_game']
                                                    ['cover_url'] ??
                                                IGDBService.getCoverUrl(
                                                  comment['attached_game']
                                                      ['cover']?['image_id'],
                                                ),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (comment['attached_game']['cover_url'] ==
                                            null &&
                                        comment['attached_game']['cover'] == null)
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Botones fijados en la esquina superior derecha
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: CorpusTablerIcon(
                      CorpusIconKind.Reply,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: 'Responder',
                    onPressed: () => _startReply(comment),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  if (isMyComment) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: CorpusTablerIcon(
                        CorpusIconKind.DeleteOutline,
                        size: 18,
                        color: cs.error,
                      ),
                      tooltip: 'Eliminar',
                      onPressed: () => _deleteComment(comment['id']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  CorpusIconKind _getStatusIcon(String status) => GameStatus.iconForString(status);

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

  Widget _buildSubRatingBadge(String label, double rating, CorpusIconKind icon) {
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
          CorpusTablerIcon(icon,
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
                                          ? const CorpusTablerIcon(CorpusIconKind.Person)
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
                                            icon: CorpusTablerIcon(CorpusIconKind.EditOutlined,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            tooltip: 'Editar reseña',
                                            onPressed: _editReview,
                                          ),
                                          IconButton(
                                            icon: CorpusTablerIcon(CorpusIconKind.DeleteOutline,
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
                                            pStyle['fallbackIcon'] as CorpusIconKind?;

                                        Widget? customIcon;
                                        if (iconPath != null) {
                                          customIcon = Image.asset(
                                            iconPath,
                                            width: 14,
                                            height: 14,
                                            color: pColor,
                                          );
                                        } else if (fallbackIcon != null) {
                                          customIcon = CorpusTablerIcon(fallbackIcon,
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
                                                child: CorpusTablerIcon(CorpusIconKind.VideogameAsset,
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
                                              CorpusTablerIcon(CorpusIconKind.Star,
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
                                            CorpusTablerIcon(_getStatusIcon(status),
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
                                              CorpusTablerIcon(CorpusIconKind.AccessTime,
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
                                              CorpusTablerIcon(CorpusIconKind.CalendarToday,
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
                                            CorpusTablerIcon(CorpusIconKind.PieChart,
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
                                    icon: CorpusTablerIcon(_hasLiked
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
                                    onPressed: () {
                                      // TODO: Focus on text field
                                    },
                                    icon: const CorpusTablerIcon(CorpusIconKind.ChatBubbleOutline,
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
                                const Text(
                                  'Comentarios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _orderedComments.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) =>
                                      _buildCommentCard(
                                    comment: _orderedComments[index],
                                    currentUserId: currentUserId,
                                    isDesktop: isDesktop,
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
                      Container(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: MediaQuery.of(context).padding.bottom + 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_replyToCommentId != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Respondiendo a @$_replyToUsername',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const CorpusTablerIcon(CorpusIconKind.Close, size: 18),
                                      onPressed: _clearReplyTarget,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            if (_commentImage != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: Theme.of(context)
                                            .extension<CorpusThemeExtension>()!
                                            .radiusSmall,
                                        child: kIsWeb
                                            ? CorpusNetworkImage(
                                                url: _commentImage!.path,
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(_commentImage!.path),
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _commentImage = null,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const CorpusTablerIcon(CorpusIconKind.Close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_selectedGameForComment != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          borderRadius: Theme.of(context)
                                              .extension<
                                                CorpusThemeExtension
                                              >()!
                                              .radiusSmall,
                                          color: Theme.of(
                                            context,
                                          ).primaryColorDark,
                                          image:
                                              (_selectedGameForComment!['cover_url'] !=
                                                      null ||
                                                  _selectedGameForComment!['cover'] !=
                                                      null)
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    _selectedGameForComment!['cover_url'] ??
                                                        IGDBService.getCoverUrl(
                                                          _selectedGameForComment!['cover']?['image_id'],
                                                        ),
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child:
                                            (_selectedGameForComment!['cover_url'] ==
                                                    null &&
                                                _selectedGameForComment!['cover'] ==
                                                    null)
                                            ? Center(
                                                child: CorpusTablerIcon(CorpusIconKind.VideogameAsset,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.54),
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () =>
                                                _selectedGameForComment = null,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const CorpusTablerIcon(CorpusIconKind.Close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 16,
                                top: 4,
                                bottom: 4,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: CorpusTablerIcon(CorpusIconKind.AddPhotoAlternate,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final file = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 70,
                                        maxWidth: 1080,
                                      );
                                      if (file != null) {
                                        setState(() => _commentImage = file);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 0),
                                  IconButton(
                                    icon: CorpusTablerIcon(CorpusIconKind.VideogameAsset,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final game = await context.pushSearch(
                                        isSelectionMode: true,
                                      );
                                      if (game != null) {
                                        setState(() {
                                          if (game is Game) {
                                            _selectedGameForComment = game
                                                .toMap();
                                          } else if (game
                                              is Map<String, dynamic>) {
                                            _selectedGameForComment = game;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: Focus(
                                      onKeyEvent: (node, event) {
                                        final isDesktop =
                                            MediaQuery.of(context).size.width >
                                            800;
                                        if (isDesktop &&
                                            event is KeyDownEvent &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.enter &&
                                            !HardwareKeyboard
                                                .instance
                                                .isShiftPressed) {
                                          _submitComment();
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: TextField(
                                        focusNode: _commentFocusNode,
                                        controller: _commentController,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        maxLength: 500,
                                        decoration: InputDecoration(
                                          hintText: 'Añadir un comentario...',
                                          hintStyle: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                        ),
                                        maxLines: null,
                                      ),
                                    ),
                                  ),
                                  if (_isSubmitting)
                                    const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: CorpusTablerIcon(CorpusIconKind.Send,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      onPressed: _submitComment,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  // _showImageFullScreen removed in favor of full_screen_gallery.dart

  /// Formatea la fecha de un comentario en formato relativo, por ejemplo "hace 2 horas".
  String _formatCommentDate(String? isoString) => formatDateRelative(isoString);
}
