import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../library/game_details_screen.dart';
import 'hero_showcase.dart';
import 'anticipated_games_section.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSearch;

  const HomeScreen({super.key, this.onNavigateToSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _latestReviewsScrollController = ScrollController();
  // ValueNotifier en lugar de bool+setState para evitar rebuild completo de
  // HomeScreen cada vez que el usuario mueve el scroll horizontal
  final ValueNotifier<bool> _canScrollLeft = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollRight = ValueNotifier(true);

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  late Future<Map<String, dynamic>> _homeDataFuture;
  StreamSubscription<AuthState>? _authSub;

  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;

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

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _homeDataFuture = _fetchHomeData();
        });
      }
    });
  }

  void _updateScrollArrows() {
    if (!mounted || !_latestReviewsScrollController.hasClients) return;
    final position = _latestReviewsScrollController.position;
    // Actualiza solo el ValueNotifier — no lanza rebuild de toda la pantalla
    _canScrollLeft.value = position.pixels > 1.0;
    _canScrollRight.value = position.pixels < (position.maxScrollExtent - 1.0);
  }

  @override
  void dispose() {
    _latestReviewsScrollController.removeListener(_updateScrollArrows);
    _latestReviewsScrollController.dispose();
    _canScrollLeft.dispose();
    _canScrollRight.dispose();
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _authSub?.cancel();
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      setState(() {
        _homeDataFuture = _fetchHomeData();
      });
    }
  }

  Future<void> _handleRefresh() async {
    final newData = await _fetchHomeData();
    if (mounted) {
      setState(() {
        _homeDataFuture = Future.value(newData);
      });
    }
  }

  Future<Map<String, dynamic>> _fetchHomeData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    String displayName = '';
    List<Map<String, dynamic>> games = [];

    if (currentUser != null) {
      final userId = currentUser.id;

      // Obtener display_name
      final userResp = await Supabase.instance.client
          .from('users')
          .select('display_name, username')
          .eq('id', userId)
          .maybeSingle();
      displayName = (userResp?['display_name'] as String?)?.isNotEmpty == true
          ? userResp!['display_name'] as String
          : (userResp?['username'] as String?)?.isNotEmpty == true
          ? userResp!['username'] as String
          : (currentUser.email?.split('@').first ?? 'tú');

      // Obtener juegos
      final response = await Supabase.instance.client
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', userId)
          .eq('status', 'playing');

      games = List<Map<String, dynamic>>.from(response);

      // Descartar los juegos que el usuario tiene marcados como 'on_hold' en sus reseñas
      try {
        final onHoldReviews = await Supabase.instance.client
            .from('reviews')
            .select('game_id')
            .eq('user_id', userId)
            .eq('completion_type', 'on_hold');

        if (onHoldReviews.isNotEmpty) {
          final onHoldGameIds = onHoldReviews.map((r) => r['game_id']).toSet();
          games.removeWhere((g) => onHoldGameIds.contains(g['game_id']));
        }
      } catch (e) {
        debugPrint('Error obteniendo reseñas on_hold: $e');
      }

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
                .map(
                  (s) => IGDBService.getScreenshotUrl(s['image_id'] as String?),
                )
                .where((url) => url.isNotEmpty)
                .toList();
          }

          for (var game in games) {
            final id = game['game_id'] as int;
            game['screenshots_list'] = screenshotsMap[id] ?? [];
          }
        } catch (e) {
          debugPrint(
            'Error obteniendo capturas para la pantalla de inicio: $e',
          );
        }
      }
    }

    // Obtener las últimas 25 reseñas globales
    List<Map<String, dynamic>> latestReviews = [];
    if (currentUser != null) {
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
    }

    final anticipatedGames = await IGDBService.getMostAnticipatedGames();

    List<dynamic> wishlistAnticipatedGames = [];
    if (currentUser != null) {
      try {
        final wishlistResp = await Supabase.instance.client
            .from('user_games')
            .select('game_id')
            .eq('user_id', currentUser.id)
            .eq('status', 'wishlist');

        final wishlistGameIds = List<Map<String, dynamic>>.from(
          wishlistResp,
        ).map((g) => g['game_id'] as int).toList();

        if (wishlistGameIds.isNotEmpty) {
          wishlistAnticipatedGames = await IGDBService.getUpcomingGamesByIds(
            wishlistGameIds,
          );
        }
      } catch (e) {
        debugPrint('Error obteniendo juegos de wishlist anticipados: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedOrder =
        prefs.getStringList('home_sections_order') ??
        ['hero', 'stash_activity', 'anticipated_games'];
    final savedHidden = prefs.getStringList('home_sections_hidden') ?? [];
    final countdownStyle =
        prefs.getString('anticipated_countdown_style') ?? 'full';

    final defaultOrder = [
      'hero',
      'stash_activity',
      'wishlist_anticipated',
      'anticipated_games',
    ];
    List<String> loadedOrder = List<String>.from(savedOrder);
    for (int i = 0; i < defaultOrder.length; i++) {
      if (!loadedOrder.contains(defaultOrder[i])) {
        loadedOrder.insert(i.clamp(0, loadedOrder.length), defaultOrder[i]);
      }
    }
    loadedOrder.removeWhere((key) => !defaultOrder.contains(key));

    return {
      'games': games,
      'displayName': displayName,
      'latestReviews': latestReviews,
      'anticipatedGames': anticipatedGames,
      'wishlistAnticipatedGames': wishlistAnticipatedGames,
      'sectionsOrder': loadedOrder,
      'sectionsHidden': savedHidden.toSet(),
      'countdownStyle': countdownStyle,
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

          final playingGames =
              (snapshot.data?['games'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final displayName = snapshot.data?['displayName'] as String? ?? '';
          final latestReviews =
              (snapshot.data?['latestReviews'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final anticipatedGames =
              (snapshot.data?['anticipatedGames'] as List<dynamic>?) ?? [];
          final wishlistAnticipatedGames =
              (snapshot.data?['wishlistAnticipatedGames'] as List<dynamic>?) ??
              [];

          final sectionsOrder =
              snapshot.data?['sectionsOrder'] as List<String>? ??
              [
                'hero',
                'stash_activity',
                'wishlist_anticipated',
                'anticipated_games',
              ];
          final sectionsHidden =
              snapshot.data?['sectionsHidden'] as Set<String>? ?? {};
          final countdownStyle =
              snapshot.data?['countdownStyle'] as String? ?? 'full';

          List<Widget> slivers = [];

          for (final sectionKey in sectionsOrder) {
            if (sectionsHidden.contains(sectionKey)) continue;

            if (sectionKey == 'hero') {
              slivers.add(
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: Stack(
                      children: [
                        _isGuest
                            ? GuestHeroShowcase(
                                switchDuration:
                                    GuestHeroShowcase.defaultSwitchDuration,
                              )
                            : playingGames.isEmpty
                            ? EmptyPlayingHero(
                                userName: displayName,
                                onSearchPressed:
                                    widget.onNavigateToSearch ?? () {},
                                switchDuration:
                                    EmptyPlayingHero.defaultSwitchDuration,
                              )
                            : HeroShowcase(
                                playingGames: playingGames,
                                userName: displayName,
                                switchDuration:
                                    HeroShowcase.defaultSwitchDuration,
                              ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (sectionKey == 'wishlist_anticipated' &&
                wishlistAnticipatedGames.isNotEmpty) {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnticipatedGamesSection(
                    games: wishlistAnticipatedGames,
                    countdownStyle: countdownStyle,
                    title: 'Próximos en tu Wishlist',
                  ),
                ),
              );
            } else if (sectionKey == 'anticipated_games' &&
                anticipatedGames.isNotEmpty) {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnticipatedGamesSection(
                    games: anticipatedGames,
                    countdownStyle: countdownStyle,
                  ),
                ),
              );
            } else if (sectionKey == 'stash_activity' &&
                latestReviews.isNotEmpty) {
              slivers.add(
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors
                        .black, // Color sólido, ya que el degradado está encima
                    padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 48.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actividad Global de Stash',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (game?['cover_url'] != null)
                                              InkWell(
                                                onTap: () {
                                                  if (review['game_id'] !=
                                                      null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => GameDetailsScreen(
                                                          gameData: {
                                                            'id':
                                                                review['game_id'],
                                                            if (game?['title'] !=
                                                                null)
                                                              'title':
                                                                  game!['title'],
                                                            if (game?['cover_url'] !=
                                                                null)
                                                              'cover_url':
                                                                  game!['cover_url'],
                                                          },
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    game['cover_url'],
                                                    width: 40,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        const Icon(
                                                          Icons.videogame_asset,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    game?['title'] ??
                                                        'Juego Desconocido',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Row(
                                                    children: [
                                                      if (review['stash_user_avatar_url'] !=
                                                          null)
                                                        CircleAvatar(
                                                          radius: 8,
                                                          backgroundImage:
                                                              NetworkImage(
                                                                review['stash_user_avatar_url'],
                                                              ),
                                                          onBackgroundImageError:
                                                              (_, _) {},
                                                        )
                                                      else
                                                        const Icon(
                                                          Icons.person,
                                                          size: 16,
                                                        ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          review['stash_user_display_name'] ??
                                                              'Usuario',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                                  const Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    review['rating'].toString(),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Text(
                                            review['comment'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Flechas de scroll — usan ValueListenableBuilder para
                              // no provocar un rebuild completo de HomeScreen al hacer scroll
                              ValueListenableBuilder<bool>(
                                valueListenable: _canScrollLeft,
                                builder: (context, canLeft, _) {
                                  if (!_isDesktop || !canLeft) return const SizedBox.shrink();
                                  return Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.chevron_left,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            _latestReviewsScrollController
                                                .animateTo(
                                                  _latestReviewsScrollController
                                                          .offset -
                                                      500,
                                                  duration: const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: _canScrollRight,
                                builder: (context, canRight, _) {
                                  if (!_isDesktop || !canRight) return const SizedBox.shrink();
                                  return Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            _latestReviewsScrollController
                                                .animateTo(
                                                  _latestReviewsScrollController
                                                          .offset +
                                                      500,
                                                  duration: const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          }

          slivers.add(
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          );

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            ),
          );
        },
      ),
    );
  }
}
