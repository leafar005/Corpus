import 'package:flutter/material.dart';
import '../../../utils/igdb_constants.dart';
import '../../../widgets/game_card.dart';
import '../../../widgets/profile_stat_icon.dart';
import '../../../models/models.dart';

/// Visión general de juegos en el perfil: carruseles por estado con títulos clicables.
class ProfileGamesOverview extends StatelessWidget {
  final List<Map<String, dynamic>> wishlistGames;
  final List<Map<String, dynamic>> playingGames;
  final List<Map<String, dynamic>> beatenGames;
  final List<Map<String, dynamic>> platinumGames;
  final int wishlistCount;
  final int playingCount;
  final int beatenCount;
  final int platinumCount;
  final void Function(String? status) onSeeAll;
  final VoidCallback onReturn;

  const ProfileGamesOverview({
    super.key,
    required this.wishlistGames,
    required this.playingGames,
    required this.beatenGames,
    required this.platinumGames,
    required this.wishlistCount,
    required this.playingCount,
    required this.beatenCount,
    required this.platinumCount,
    required this.onSeeAll,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wishlistGames.isNotEmpty) ...[
          _buildSectionTitle(
            context,
            'Quiero',
            wishlistCount,
            'wishlist',
            iconType: ProfileStatIconType.wishlist,
          ),
          _buildCarousel(context, wishlistGames),
          const SizedBox(height: 24),
        ],
        if (playingGames.isNotEmpty) ...[
          _buildSectionTitle(
            context,
            'Jugando',
            playingCount,
            'playing',
            iconType: ProfileStatIconType.playing,
          ),
          _buildCarousel(context, playingGames),
          const SizedBox(height: 24),
        ],
        if (beatenGames.isNotEmpty) ...[
          _buildSectionTitle(
            context,
            'Completados',
            beatenCount,
            'beaten',
            iconType: ProfileStatIconType.beaten,
          ),
          _buildCarousel(context, beatenGames),
          const SizedBox(height: 24),
        ],
        if (platinumGames.isNotEmpty) ...[
          _buildSectionTitle(
            context,
            'Platinos',
            platinumCount,
            'completed',
            iconType: ProfileStatIconType.platinum,
          ),
          _buildCarousel(context, platinumGames),
          const SizedBox(height: 24),
        ],
        if (beatenGames.isEmpty &&
            platinumGames.isEmpty &&
            playingGames.isEmpty &&
            wishlistGames.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Aún no tienes juegos en tu biblioteca.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    int count,
    String? status, {
    ProfileStatIconType? iconType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSeeAll(status),
              child: Row(
                children: [
                  if (iconType != null) ...[
                    ProfileStatIcon(type: iconType, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSeeAll(status),
              child: Text(
                'Ver todo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(
    BuildContext context,
    List<Map<String, dynamic>> games,
  ) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: AspectRatio(
              aspectRatio: IgdbConstants.coverAspectRatio,
              child: _buildGameCard(game),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final userRating = (game['user_rating'] ?? 0).toDouble();
    final completionType = game['completion_type'] as String?;
    return GameCard(
      game: Game.fromMap(game),
      isInLibrary: true,
      userRating: userRating,
      completionType: completionType,
      onReturn: onReturn,
    );
  }
}
