import 'package:flutter/material.dart';

import '../../activity/review_details_screen.dart';
import '../../../models/models.dart';
import '../../../widgets/coop_badge.dart';

class GameReviewsCard extends StatelessWidget {
  const GameReviewsCard({
    super.key,
    required this.reviews,
    required this.gameData,
    required this.userData,
    required this.partnerData,
    this.onEditReview,
    this.onDeleteReview,
    this.onShowFullScreenGallery,
    this.onShowFriendActivity,
    required this.isDesktop,
  });

  final List<Review> reviews;
  final Map<String, dynamic> gameData;
  final UserProfile? userData;
  final UserProfile? partnerData;
  final bool isDesktop;
  final Function(Review)? onEditReview;
  final Function(Review)? onDeleteReview;
  final Function(BuildContext, List<String>, int)? onShowFullScreenGallery;
  final Function(Map<String, dynamic>)? onShowFriendActivity;

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


  String _formatDateRange(DateTime? from, DateTime? until) {
    if (from == null) return '';
    try {
      final f = from;
      final fs = '${f.day} ${_getMonthAbbr(f.month)}';
      if (until == null) return '$fs ${f.year}';
      final u = until;
      if (f.year == u.year) {
        if (f.month == u.month && f.day == u.day) return '$fs ${f.year}';
        return '$fs - ${u.day} ${_getMonthAbbr(u.month)} ${f.year}';
      }
      return '$fs ${f.year} - ${u.day} ${_getMonthAbbr(u.month)} ${u.year}';
    } catch (_) {
      return '';
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


  Widget _buildSubRatingBadge(BuildContext context, String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoBadge(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getCompletionTypeText(String type) {
    switch (type) {
      case 'story':
        return 'Historia';
      case 'story_extras':
        return 'Historia + Extras';
      case '100_percent':
        return '100%';
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
        return Icons.stars;
      case 'endless':
        return Icons.all_inclusive;
      case 'on_hold':
        return Icons.pause;
      default:
        return Icons.flag;
    }
  }

  Widget _buildReviewsList(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      children: reviews.map((review) {
        final rating = review.rating ?? 0.0;
        final comment = review.comment ?? '';
        final completionType = review.completionType ?? 'story';
        final isReplay = review.isReplay;
        final replayNumber = review.replayNumber;
        final rPlatform = review.platform;
        final playTime = review.playTimeHours ?? 0.0;
        final playedFrom = review.playedFrom;
        final playedUntil = review.playedUntil;
        final progress = review.progressPercent;
        final createdAt = review.createdAt;
        final rGameplay = review.ratingGameplay ?? 0.0;
        final rNarrative = review.ratingNarrative ?? 0.0;
        final rSoundtrack = review.ratingSoundtrack ?? 0.0;
        final rVisuals = review.ratingVisuals ?? 0.0;
        final List<String> imageUrls = review.imageUrls;
        final dateStr = createdAt != null ? _formatDate(createdAt.toIso8601String()) : '';
        final rStatus = review.status.dbValue;
        String statusText;
        switch (rStatus) {
          case 'playing':
            statusText = 'Jugando';
            break;
          case 'beaten':
            statusText = 'Terminado';
            break;
          case 'abandoned':
            statusText = 'Abandonado';
            break;
          case 'on_hold':
            statusText = 'En Pausa';
            break;
          case 'wishlist':
            statusText = 'Quiero';
            break;
          default:
            statusText = 'Desconocido';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewDetailsScreen(
                  gameData: gameData,
                  userData: userData?.toMap() ?? {}, // Assuming it expects map
                  reviewData: review.toMap(), // Need to add toMap to Review, or update ReviewDetailsScreen
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                          if (rPlatform != null)
                            _buildInfoBadge(
                              rPlatform,
                              Icons.devices,
                              Colors.blueGrey,
                            ),
                        ],
                      ),
                    ),
                    if (review.id.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            padding: const EdgeInsets.only(right: 12),
                            constraints: const BoxConstraints(),
                            tooltip: 'Editar reseña',
                            onPressed: () =>
                                onEditReview?.call(review),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Eliminar reseña',
                            onPressed: () => onDeleteReview?.call(review),
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 24),
                if (partnerData != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CoopBadge(
                      username: partnerData!.effectiveName,
                      avatarUrl: partnerData!.avatarUrl,
                      size: 20,
                      status: rStatus,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (rating > 0) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (rGameplay > 0 ||
                    rNarrative > 0 ||
                    rSoundtrack > 0 ||
                    rVisuals > 0) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (rGameplay > 0)
                        _buildSubRatingBadge(context, 'Gameplay', rGameplay),
                      if (rNarrative > 0)
                        _buildSubRatingBadge(context, 'Narrativa', rNarrative),
                      if (rSoundtrack > 0)
                        _buildSubRatingBadge(context, 'Música', rSoundtrack),
                      if (rVisuals > 0)
                        _buildSubRatingBadge(context, 'Gráficos', rVisuals),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (comment.isNotEmpty)
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => onShowFullScreenGallery?.call(
                              context,
                              List<String>.from(imageUrls),
                              idx,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrls[idx],
                                height: 100,
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (playTime > 0 || playedFrom != null || progress != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (playTime > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playTime.toStringAsFixed(1)}h',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (playedFrom != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateRange(playedFrom, playedUntil),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (progress != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$progress%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return _buildReviewsList(context);
  }
}
