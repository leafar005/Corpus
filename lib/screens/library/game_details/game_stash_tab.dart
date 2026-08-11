// Fase 3 del refactor B-C2.
// Origen: _buildStashReviewsList -> líneas 1204-1331.
// Esta es la pestaña "Comunidad" (contenido de communityTabIdx en el
// original). No confundir con game_reviews_card.dart, que es la card de
// "tu review / la de tu pareja" mostrada en el Hero.

import 'package:flutter/material.dart';
import '../../../widgets/guest_login_prompt.dart';
import '../../../theme/corpus_theme_extension.dart';
import '../../../utils/format_utils.dart';

class GameStashTab extends StatefulWidget {
  const GameStashTab({
    super.key,
    required this.isGuest,
    required this.isLoadingStashReviews,
    required this.stashReviews,
  });

  final bool isGuest;
  final bool isLoadingStashReviews;
  final List<Map<String, dynamic>> stashReviews;

  @override
  State<GameStashTab> createState() => _GameStashTabState();
}

class _GameStashTabState extends State<GameStashTab> {
  int _stashReviewLimit = 5;

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: GuestLoginPrompt(
          icon: Icons.reviews_outlined,
          message: 'Inicia sesión para ver las reseñas de la comunidad.',
        ),
      );
    }

    if (widget.isLoadingStashReviews && widget.stashReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.stashReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No hay reseñas de la comunidad.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final visibleReviews = widget.stashReviews.take(_stashReviewLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...visibleReviews.map((review) {
          final rating = (review['rating'] ?? 0).toDouble();
          final comment = review['comment'] ?? '';
          final displayName = review['stash_user_display_name'] ?? 'Usuario';
          final avatarUrl = review['stash_user_avatar_url'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: Theme.of(
                context,
              ).extension<CorpusThemeExtension>()!.radiusMedium,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (rating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            formatRating(rating),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        if (widget.stashReviews.length > _stashReviewLimit)
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _stashReviewLimit += 5;
                });
              },
              icon: const Icon(Icons.expand_more),
              label: const Text('Ver más reseñas'),
            ),
          ),
      ],
    );
  }
}
