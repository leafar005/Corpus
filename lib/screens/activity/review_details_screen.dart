import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/format_utils.dart';
import '../library/game_details_screen.dart';
import '../library/review_modal.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/activity_repository.dart';
import '../../widgets/achievement_toast.dart';
import '../../models/models.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../profile/profile_screen.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../library/search_screen.dart';
import '../../services/igdb_service.dart';
import '../../widgets/coop_badge.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
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
  final _repo = ActivityRepository();

  late Map<String, dynamic> _currentReviewData;
  bool _isLoading = true;
  int _likesCount = 0;
  bool _hasLiked = false;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  XFile? _commentImage;
  Map<String, dynamic>? _selectedGameForComment;
  List<Map<String, dynamic>> _partnersData = [];

  @override
  void initState() {
    super.initState();
    _currentReviewData = Map<String, dynamic>.from(widget.reviewData);
    _fetchInteractions();
    _fetchPartner();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPartner() async {
    final userId = _currentReviewData['user_id'] as String?;
    final gameId = (_currentReviewData['game_id'] as num?)?.toInt();
    if (userId == null || gameId == null) return;
    try {
      final partners = await _repo.fetchPartners(
        userId: userId,
        gameId: gameId,
      );
      if (mounted) setState(() => _partnersData = partners);
    } catch (_) {}
  }

  Future<void> _fetchInteractions() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final reviewId = _currentReviewData['id'] as String?;

    if (currentUserId == null || reviewId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await _repo.fetchInteractions(reviewId, currentUserId);
      _likesCount = result.likesCount;
      _hasLiked = result.hasLiked;
      _comments = result.comments;
    } catch (e) {
      debugPrint('[ReviewDetailsScreen] Error fetching interactions: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleLike() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final reviewId = _currentReviewData['id'] as String?;
    if (reviewId == null) return;

    // Optimistic UI update
    setState(() {
      _hasLiked = !_hasLiked;
      _likesCount += _hasLiked ? 1 : -1;
    });

    try {
      await _repo.toggleLike(
        reviewId: reviewId,
        userId: currentUserId,
        currentlyLiked: !_hasLiked, // was toggled above, pass pre-toggle value
      );
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _hasLiked = !_hasLiked;
          _likesCount += _hasLiked ? 1 : -1;
        });
      }
      debugPrint('[ReviewDetailsScreen] Error toggling like: $e');
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty &&
        _commentImage == null &&
        _selectedGameForComment == null) {
      return;
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final reviewId = widget.reviewData['id'] as String?;
    if (reviewId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _repo.submitComment(
        reviewId: reviewId,
        userId: currentUserId,
        content: content.isNotEmpty ? content : null,
        commentImage: _commentImage,
        attachedGame: _selectedGameForComment,
      );

      _commentController.clear();
      setState(() {
        _commentImage = null;
        _selectedGameForComment = null;
      });
      await _fetchInteractions();
    } catch (e) {
      debugPrint('[ReviewDetailsScreen] Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar comentario: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      final comment = _comments.firstWhere(
        (c) => c['id'] == commentId,
        orElse: () => <String, dynamic>{},
      );
      await _repo.deleteComment(
        commentId: commentId,
        imageUrl: comment['image_url'] as String?,
      );
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c['id'] == commentId));
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

  Widget _buildCommentContent(String text) {
    final RegExp regex = RegExp(r'(@\w+)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 14, height: 1.4));
    }

    int currentIndex = 0;
    List<TextSpan> spans = [];

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(fontSize: 14, height: 1.4),
        children: spans,
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
      final gameId =
          (widget.gameData['igdb_id'] ??
                  widget.gameData['id'] ??
                  _currentReviewData['game_id'] as num?)
              ?.toInt();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (gameId == null || currentUserId == null) return;

      final currentImages =
          (_currentReviewData['image_urls'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();

      await _repo.deleteReview(
        reviewId: reviewId,
        gameId: gameId,
        userId: currentUserId,
        currentImageUrls: currentImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reseña eliminada')));
        Navigator.pop(context);
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
      gameData: widget.gameData,
      enrichedData: widget.gameData,
      existingReview: Review.fromMap(_currentReviewData),
      currentPartnerIds: _partnersData.map((e) => e['id'] as String).toList(),
      isSaving: _isSubmitting,
      currentRating: rating,
      currentRatingGameplay: ratingGameplay,
      currentRatingNarrative: ratingNarrative,
      currentRatingSoundtrack: ratingSoundtrack,
      currentRatingVisuals: ratingVisuals,
      currentStatus: status,
      commentController: TextEditingController(
        text:
            _currentReviewData['comment'] ??
            _currentReviewData['content'] ??
            '',
      ),
      onSave: _saveReviewModal,
    );
  }

  Future<void> _saveReviewModal({
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
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    final igdbId =
        widget.gameData['igdb_id'] ??
        widget.gameData['id'] ??
        _currentReviewData['game_id'];
    final repo = ReviewRepository();

    try {
      final result = await repo.saveReview(
        userId: userId,
        igdbId: igdbId,
        gameData: widget.gameData,
        enrichedData: widget.gameData,
        reviewId: reviewId ?? _currentReviewData['id'],
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
        int toastDelay = 300;
        for (final ach in result.newAchievementDetails) {
          final String aId = ach['id'] as String;
          final String title = ach['name'] as String? ?? 'Logro desbloqueado';
          final String rarity =
              (ach['rarity'] as String?)?.toLowerCase() ?? 'comun';
          final int xpReward = ach['xp_reward'] as int? ?? 0;

          String subtitle = 'Logro desbloqueado';
          Color color = const Color(0xFFFFD700);

          if (title.contains('(Maestro)') ||
              title.contains('(Nivel 3)') ||
              aId.endsWith('_all')) {
            subtitle = 'Maestro de saga';
            color = const Color(0xFFFFD700);
          } else if (title.contains('(Nivel 2)')) {
            subtitle = 'Hito alcanzado';
            color = const Color(0xFFC0C0C0);
          } else if (title.contains('(Nivel 1)')) {
            subtitle = 'Logro desbloqueado';
            color = const Color(0xFFCD7F32);
          } else {
            if (rarity == 'legendario' ||
                rarity == 'platino' ||
                rarity == 'épico' ||
                rarity == 'epico') {
              subtitle = 'Hazaña legendaria';
              color = Colors.cyanAccent;
            } else if (rarity == 'difícil' ||
                rarity == 'dificil' ||
                rarity == 'medio') {
              subtitle = 'Logro desbloqueado';
              color = Colors.blueAccent;
            } else {
              subtitle = 'Logro desbloqueado';
              color = Colors.green;
            }
          }

          Future.delayed(Duration(milliseconds: toastDelay), () {
            if (mounted) {
              AchievementToast.show(
                context,
                title: title,
                subtitle: subtitle,
                xpReward: xpReward,
                icon: Icons.workspace_premium,
                color: color,
              );
            }
          });
          toastDelay += 3700;
        }
      }

      final updatedReview = await _repo.fetchUpdatedReview(
        _currentReviewData['id'] as String,
        fallbackUserData: _currentReviewData['users'] as Map<String, dynamic>?,
      );

      if (updatedReview != null && mounted) {
        setState(() => _currentReviewData = updatedReview);
      }

      await _fetchPartner();

      if (mounted) {
        Navigator.pop(context); // Cierra el modal de reseña
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reseña actualizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar reseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
      return "${date.day} de ${months[date.month - 1]} de ${date.year}";
    } catch (e) {
      return '';
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[month - 1];
  }

  String _formatDateRange(String? from, String? until) {
    if (from == null) return '';
    try {
      final f = DateTime.parse(from);
      final fs = '${f.day} ${_getMonthAbbr(f.month)}';
      if (until == null) return '$fs ${f.year}';
      final u = DateTime.parse(until);
      final us = '${u.day} ${_getMonthAbbr(u.month)} ${u.year}';
      return f.year == u.year ? '$fs - $us' : '$fs ${f.year} - $us';
    } catch (_) {
      return '';
    }
  }

  String _getStatusText(String status) => GameStatus.labelForString(status);

  IconData _getStatusIcon(String status) => GameStatus.iconForString(status);

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

  IconData _getCompletionTypeIcon(String type) {
    switch (type) {
      case 'story':
        return Icons.auto_stories;
      case 'story_extras':
        return Icons.extension;
      case '100_percent':
        return Icons.emoji_events;
      case 'endless':
        return Icons.all_inclusive;
      case 'on_hold':
        return Icons.pause;
      default:
        return Icons.flag;
    }
  }

  Widget _buildInfoBadge(String label, IconData icon, Color color) {
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
          Icon(icon, size: 14, color: color),
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

  Widget _buildSubRatingBadge(String label, double rating, IconData icon) {
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
          Icon(
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
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
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

    final dateStr = createdAt != null ? _formatDate(createdAt) : '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: CorpusScreenTitle(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(userId: userId),
                                  ),
                                );
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
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        tooltip: 'Editar reseña',
                                        onPressed: _editReview,
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
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
                                  Icons.replay,
                                  Colors.orangeAccent,
                                ),
                              if (platform != null)
                                _buildInfoBadge(
                                  platform,
                                  Icons.devices,
                                  Colors.blueGrey,
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
                                        MediaQuery.of(context).size.width > 800;
                                    if (isDesktop) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              GameDetailsScreen(
                                                gameData: widget.gameData,
                                              ),
                                        ),
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
                                                  (context, scrollController) {
                                                    return GameDetailsScreen(
                                                      gameData: widget.gameData,
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
                                          .extension<CorpusThemeExtension>()!
                                          .radiusSmall,
                                      color: Theme.of(context).primaryColorDark,
                                      image: coverUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(coverUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: coverUrl.isEmpty
                                        ? Center(
                                            child: Icon(
                                              Icons.videogame_asset,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (rating > 0) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.star,
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
                                              Icons.sports_esports,
                                            ),
                                          if (ratingNarrative > 0)
                                            _buildSubRatingBadge(
                                              'Narrativa',
                                              ratingNarrative,
                                              Icons.auto_stories,
                                            ),
                                          if (ratingSoundtrack > 0)
                                            _buildSubRatingBadge(
                                              'Banda Sonora',
                                              ratingSoundtrack,
                                              Icons.music_note,
                                            ),
                                          if (ratingVisuals > 0)
                                            _buildSubRatingBadge(
                                              'Visuales',
                                              ratingVisuals,
                                              Icons.brush,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    Row(
                                      children: [
                                        Icon(
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
                                        children: _partnersData.map((partner) {
                                          return CoopBadge(
                                            username:
                                                partner['username'] ??
                                                'Usuario',
                                            avatarUrl: partner['avatar_url'],
                                            status: status,
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
                          const SizedBox(height: 32),

                          // Review Content
                          if (comment.isNotEmpty)
                            Text(
                              comment,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),

                          if (imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 140,
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
                                        showFullScreenGallery(
                                          context,
                                          strUrls,
                                          idx,
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: Theme.of(context)
                                            .extension<CorpusThemeExtension>()!
                                            .radiusSmall,
                                        child: Image.network(
                                          imageUrls[idx],
                                          height: isDesktop ? 280 : 140,
                                          fit: BoxFit.fitHeight,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
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
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${playTimeHours.toStringAsFixed(1)} horas',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (playedFrom != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDateRange(
                                              playedFrom,
                                              playedUntil,
                                            ),
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (progressPercent != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pie_chart,
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
                                icon: Icon(
                                  _hasLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_alt_outlined,
                                  size: 18,
                                  color: _hasLiked
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                label: Text(
                                  _likesCount.toString(),
                                  style: TextStyle(
                                    color: _hasLiked
                                        ? Theme.of(context).colorScheme.primary
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
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                  ),
                                  backgroundColor: _hasLiked
                                      ? Theme.of(context).colorScheme.primary
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
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
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
                              itemCount: _comments.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final user = comment['users'];
                                final isMyComment =
                                    comment['user_id'] == currentUserId;
                                final contentStr =
                                    comment['content']?.toString() ?? '';
                                final isReply = contentStr.trim().startsWith(
                                  '@',
                                );

                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: isReply ? 40.0 : 0.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          final uid = comment['user_id'];
                                          if (uid != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProfileScreen(userId: uid),
                                              ),
                                            );
                                          }
                                        },
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          backgroundImage:
                                              user?['avatar_url'] != null
                                              ? NetworkImage(user['avatar_url'])
                                              : null,
                                          child: user?['avatar_url'] == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                final uid = comment['user_id'];
                                                if (uid != null) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ProfileScreen(
                                                            userId: uid,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  Text(
                                                    user?['username'] ??
                                                        'Usuario',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _formatDate(
                                                      comment['created_at'],
                                                    ),
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (comment['content'] != null &&
                                                comment['content']
                                                    .toString()
                                                    .isNotEmpty)
                                              _buildCommentContent(
                                                comment['content'],
                                              ),
                                            if (comment['image_url'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      showFullScreenGallery(
                                                        context,
                                                        [comment['image_url']],
                                                        0,
                                                      ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Image.network(
                                                      comment['image_url'],
                                                      height: isDesktop
                                                          ? 300
                                                          : 150,
                                                      fit: BoxFit.fitHeight,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (comment['attached_game'] !=
                                                null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    final gameData =
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(
                                                          comment['attached_game'],
                                                        );
                                                    final isDesktop =
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width >
                                                        800;
                                                    if (isDesktop) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              GameDetailsScreen(
                                                                gameData:
                                                                    gameData,
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      showModalBottomSheet(
                                                        context: context,
                                                        isScrollControlled:
                                                            true,
                                                        useSafeArea: false,
                                                        enableDrag: true,
                                                        builder: (context) =>
                                                            DraggableScrollableSheet(
                                                              initialChildSize:
                                                                  1.0,
                                                              minChildSize: 0.5,
                                                              maxChildSize: 1.0,
                                                              expand: false,
                                                              snap: true,
                                                              builder:
                                                                  (
                                                                    context,
                                                                    scrollController,
                                                                  ) => GameDetailsScreen(
                                                                    gameData:
                                                                        gameData,
                                                                    scrollController:
                                                                        scrollController,
                                                                  ),
                                                            ),
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    width: isDesktop
                                                        ? 160
                                                        : 120,
                                                    height: isDesktop
                                                        ? 224
                                                        : 168,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColorDark,
                                                      image:
                                                          (comment['attached_game']['cover_url'] !=
                                                                  null ||
                                                              comment['attached_game']['cover'] !=
                                                                  null)
                                                          ? DecorationImage(
                                                              image: NetworkImage(
                                                                comment['attached_game']['cover_url'] ??
                                                                    IGDBService.getCoverUrl(
                                                                      comment['attached_game']['cover']?['image_id'],
                                                                    ),
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child:
                                                        (comment['attached_game']['cover_url'] ==
                                                                null &&
                                                            comment['attached_game']['cover'] ==
                                                                null)
                                                        ? Center(
                                                            child: Icon(
                                                              Icons
                                                                  .videogame_asset,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.54,
                                                                      ),
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.reply,
                                              size: 20,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: () {
                                              final targetUsername =
                                                  user?['username'] ??
                                                  'Usuario';
                                              final prefix =
                                                  '@$targetUsername ';
                                              if (!_commentController.text
                                                  .contains(prefix)) {
                                                _commentController.text =
                                                    prefix +
                                                    _commentController.text;
                                              }
                                              _commentController.selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset: _commentController
                                                          .text
                                                          .length,
                                                    ),
                                                  );
                                              _commentFocusNode.requestFocus();
                                            },
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          if (isMyComment)
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                              onPressed: () =>
                                                  _deleteComment(comment['id']),
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                                        ? Image.network(
                                            _commentImage!.path,
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
                                      onTap: () =>
                                          setState(() => _commentImage = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
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
                                          .extension<CorpusThemeExtension>()!
                                          .radiusSmall,
                                      color: Theme.of(context).primaryColorDark,
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
                                            child: Icon(
                                              Icons.videogame_asset,
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
                                        () => _selectedGameForComment = null,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
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
                                icon: Icon(
                                  Icons.add_photo_alternate,
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
                                icon: Icon(
                                  Icons.videogame_asset,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final game = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SearchScreen(
                                        isSelectionMode: true,
                                      ),
                                    ),
                                  );
                                  if (game != null) {
                                    setState(
                                      () => _selectedGameForComment = game,
                                    );
                                  }
                                },
                              ),
                              Expanded(
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    final isDesktop =
                                        MediaQuery.of(context).size.width > 800;
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
                                  icon: Icon(
                                    Icons.send,
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
  }

  // _showImageFullScreen removed in favor of full_screen_gallery.dart
}
