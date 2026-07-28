import 'package:flutter/material.dart';
import 'package:corpus/widgets/game_card.dart';

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
              child: Text(
                'No hay juegos.',
                style: TextStyle(color: Colors.grey),
              ),
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
    final userRating = (game['user_rating'] ?? 0).toDouble();
    return GameCard(
      game: game,
      isInLibrary: true,
      userRating: userRating,
      onReturn: () {},
    );
  }
}
