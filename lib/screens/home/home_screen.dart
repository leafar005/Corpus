import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import 'package:corpus/widgets/game_card.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _fetchPlayingGames();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
  }

  @override
  void dispose() {
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPlayingGames() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('user_games')
        .select('*, games(*)')
        .eq('user_id', userId)
        .eq('status', 'playing');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPlayingGames(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final playingGames = snapshot.data ?? [];

          if (playingGames.isEmpty) {
            return const Center(
              child: Text('No estás jugando a nada ahora mismo.\n¡Busca un juego para empezar!', textAlign: TextAlign.center),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150, 
              childAspectRatio: 0.7, 
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: playingGames.length,
            itemBuilder: (context, index) {
              final userGame = playingGames[index];
              final gameData = userGame['games']; 
              final rating = (userGame['rating'] ?? 0).toDouble();
              return GameCard(
                game: gameData,
                isInLibrary: true,
                userRating: rating,
                onReturn: () => setState(() {}),
              );
            },
          );
        },
      ),
    );
  }
}
