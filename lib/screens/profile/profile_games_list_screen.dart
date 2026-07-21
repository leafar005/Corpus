import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../library/game_details_screen.dart';

class ProfileGamesListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> games;

  const ProfileGamesListScreen({
    super.key,
    required this.title,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: games.isEmpty
          ? const Center(
              child: Text('No hay juegos.', style: TextStyle(color: Colors.grey)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) {
                return _buildGameCard(context, games[index]);
              },
            ),
    );
  }

  Widget _buildGameCard(BuildContext context, Map<String, dynamic> game) {
    final coverUrl = game['cover_url'] ?? '';
    final title = game['title'] ?? 'Desconocido';
    final userRating = (game['user_rating'] ?? 0).toDouble();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(gameData: game),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).primaryColorDark,
                    child: const Center(
                        child: Icon(Icons.videogame_asset,
                            size: 30, color: Colors.white54)),
                  ),
            if (coverUrl.isEmpty)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Text(title,
                    style: const TextStyle(fontSize: 10, ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            if (userRating > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.54),
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    userRating.toStringAsFixed(1),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
