import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../library/game_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _playingGames = [];
  bool _isLoading = true;

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
              final title = gameData['title'] ?? 'Desconocido';
              final coverUrl = gameData['cover_url'] ?? '';
              final rating = (userGame['rating'] ?? 0).toDouble();
              
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailsScreen(
                        gameData: gameData,
                      ),
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      coverUrl.isNotEmpty
                          ? Image.network(coverUrl, fit: BoxFit.cover)
                          : Container(
                              color: Theme.of(context).primaryColorDark,
                              child: const Center(child: Icon(Icons.videogame_asset, size: 40, color: Colors.white54)),
                            ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Theme.of(context).scaffoldBackgroundColor.withOpacity(0.87), Colors.transparent],
                            ),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (rating > 0)
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.54), blurRadius: 4, offset: Offset(0, 2))
                              ],
                            ),
                            child: Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
