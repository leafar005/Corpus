import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Añadido para kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import 'animated_background.dart';
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

  Future<Map<String, dynamic>> _fetchPlayingGames() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // Obtener display_name (o username como fallback, o email como último recurso)
    final userResp = await Supabase.instance.client
        .from('users')
        .select('display_name, username')
        .eq('id', userId)
        .maybeSingle();
    final displayName = (userResp?['display_name'] as String?)?.isNotEmpty == true
        ? userResp!['display_name'] as String
        : (userResp?['username'] as String?)?.isNotEmpty == true
            ? userResp!['username'] as String
            : (Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'tú');

    // Obtener juegos
    final response = await Supabase.instance.client
        .from('user_games')
        .select('*, games(*)')
        .eq('user_id', userId)
        .eq('status', 'playing');
        
    final games = List<Map<String, dynamic>>.from(response);

    // Obtener capturas de pantalla de IGDB para el fondo animado
    final igdbIds = games.map((g) => g['game_id'] as int).toList();
    if (igdbIds.isNotEmpty) {
      try {
        final igdbData = await IGDBService.getGamesByIds(igdbIds);
        
        final screenshotsMap = <int, List<String>>{};
        for (var item in igdbData) {
          final id = item['id'] as int;
          final screenshots = item['screenshots'] as List<dynamic>? ?? [];
          screenshotsMap[id] = screenshots
              .map((s) => IGDBService.getScreenshotUrl(s['image_id'] as String?))
              .where((url) => url.isNotEmpty)
              .toList();
        }

        for (var game in games) {
          final id = game['game_id'] as int;
          game['screenshots_list'] = screenshotsMap[id] ?? [];
        }
      } catch (e) {
        debugPrint('Error obteniendo capturas para la pantalla de inicio: $e');
      }
    }

    return {
      'games': games,
      'displayName': displayName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: kIsWeb 
        ? null 
        : AppBar(
            title: const Text('Inicio'),
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            elevation: 0,
          ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchPlayingGames(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final playingGames = (snapshot.data?['games'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final displayName = snapshot.data?['displayName'] as String? ?? '';

          if (playingGames.isEmpty) {
            return const Center(
              child: Text('No estás jugando a nada ahora mismo.\n¡Busca un juego para empezar!', textAlign: TextAlign.center),
            );
          }

          return HeroShowcase(
            playingGames: playingGames,
            userName: displayName,
          );
        },
      ),
    );
  }
}
