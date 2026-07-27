import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Añadido para kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../library/game_details_screen.dart';
import 'animated_background.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _latestReviewsScrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  bool get _isDesktop => defaultTargetPlatform == TargetPlatform.windows || 
                         defaultTargetPlatform == TargetPlatform.macOS || 
                         defaultTargetPlatform == TargetPlatform.linux || 
                         kIsWeb;

  late Future<Map<String, dynamic>> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _fetchHomeData();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
    _latestReviewsScrollController.addListener(_updateScrollArrows);
    
    // Al cargar los datos, comprobamos si podemos hacer scroll a la derecha
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollArrows();
    });
  }

  void _updateScrollArrows() {
    if (!mounted || !_latestReviewsScrollController.hasClients) return;
    final position = _latestReviewsScrollController.position;
    setState(() {
      _canScrollLeft = position.pixels > 1.0;
      _canScrollRight = position.pixels < (position.maxScrollExtent - 1.0);
    });
  }

  @override
  void dispose() {
    _latestReviewsScrollController.removeListener(_updateScrollArrows);
    _latestReviewsScrollController.dispose();
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      setState(() {
        _homeDataFuture = _fetchHomeData();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchHomeData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // Obtener display_name
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

    // Obtener capturas
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

    // Obtener las últimas 25 reseñas globales
    List<Map<String, dynamic>> latestReviews = [];
    try {
      final reviewsResp = await Supabase.instance.client
          .from('stash_community_reviews')
          .select('*, games(title, cover_url)')
          .eq('source_context', 'recent_activity_feed')
          .order('stash_created_at', ascending: false)
          .limit(25);
      latestReviews = List<Map<String, dynamic>>.from(reviewsResp);
    } catch (e) {
      debugPrint('Error obteniendo ultimas reseñas globales: $e');
    }

    return {
      'games': games,
      'displayName': displayName,
      'latestReviews': latestReviews,
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
        future: _homeDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final playingGames = (snapshot.data?['games'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final displayName = snapshot.data?['displayName'] as String? ?? '';
          final latestReviews = (snapshot.data?['latestReviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: playingGames.isEmpty ? 200 : MediaQuery.of(context).size.height * 0.75,
                  child: Stack(
                    children: [
                      playingGames.isEmpty 
                        ? const Center(
                            child: Text('No estás jugando a nada ahora mismo.\n¡Busca un juego para empezar!', textAlign: TextAlign.center),
                          )
                        : HeroShowcase(
                            playingGames: playingGames,
                            userName: displayName,
                          ),
                      // Degradado inferior para fundir a negro suavemente
                      if (latestReviews.isNotEmpty)
                        Positioned(
                          bottom: -1, // Un píxel extra para evitar cualquier línea blanca/corte
                          left: 0,
                          right: 0,
                          height: 250, // Más alto para que el degradado sea más suave
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.black,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (latestReviews.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.black, // Color sólido, ya que el degradado está encima
                    padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 100.0), // Más espacio arriba (48)
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actividad Global de Stash',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _latestReviewsScrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: latestReviews.length,
                                itemBuilder: (context, index) {
                                  final review = latestReviews[index];
                                  final game = review['games'];
                                  
                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (game?['cover_url'] != null)
                                              InkWell(
                                                onTap: () {
                                                  if (review['game_id'] != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => GameDetailsScreen(
                                                          gameData: {
                                                            'id': review['game_id'],
                                                            if (game?['title'] != null) 'title': game!['title'],
                                                            if (game?['cover_url'] != null) 'cover_url': game!['cover_url'],
                                                          }
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    game['cover_url'],
                                                    width: 40,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.videogame_asset),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      game?['title'] ?? 'Juego Desconocido',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Row(
                                                      children: [
                                                        if (review['stash_user_avatar_url'] != null)
                                                          CircleAvatar(
                                                            radius: 8,
                                                            backgroundImage: NetworkImage(review['stash_user_avatar_url']),
                                                            onBackgroundImageError: (_, __) {},
                                                          )
                                                        else
                                                          const Icon(Icons.person, size: 16),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            review['stash_user_display_name'] ?? 'Usuario',
                                                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (review['rating'] != null)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      review['rating'].toString(),
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Text(
                                            review['comment'] ?? '',
                                            style: const TextStyle(fontSize: 13),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Flecha Izquierda
                              if (_isDesktop && _canScrollLeft)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                                        onPressed: () {
                                          _latestReviewsScrollController.animateTo(
                                            _latestReviewsScrollController.offset - 500,
                                            duration: const Duration(milliseconds: 500),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              // Flecha Derecha
                              if (_isDesktop && _canScrollRight)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                                        onPressed: () {
                                          _latestReviewsScrollController.animateTo(
                                            _latestReviewsScrollController.offset + 500,
                                            duration: const Duration(milliseconds: 500),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                          ],
                        ),
                    ),
                  ), // Cierra SliverToBoxAdapter
                ],
          );
        },
      ),
    );
  }
}
