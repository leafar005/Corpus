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

// ─── Modelos de datos por fase ──────────────────────────────────────────────

/// Datos que llegan rápido (Supabase del usuario + prefs).
class _PhaseOneData {
  final List<Map<String, dynamic>> games;
  final String displayName;
  final List<String> sectionsOrder;
  final Set<String> sectionsHidden;
  final String anticipatedCountdownStyle;
  final String wishlistCountdownStyle;

  const _PhaseOneData({
    required this.games,
    required this.displayName,
    required this.sectionsOrder,
    required this.sectionsHidden,
    required this.anticipatedCountdownStyle,
    required this.wishlistCountdownStyle,
  });
}

/// Datos que tardan más (IGDB + reseñas globales + wishlist anticipated).
class _PhaseTwoData {
  final List<dynamic> anticipatedGames;
  final List<dynamic> wishlistAnticipatedGames;
  final List<Map<String, dynamic>> latestReviews;

  const _PhaseTwoData({
    required this.anticipatedGames,
    required this.wishlistAnticipatedGames,
    required this.latestReviews,
  });
}

// ────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSearch;

  const HomeScreen({super.key, this.onNavigateToSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _latestReviewsScrollController = ScrollController();
  final ValueNotifier<bool> _canScrollLeft = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollRight = ValueNotifier(true);

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  late Future<_PhaseOneData> _phaseOneFuture;
  _PhaseTwoData? _phaseTwoData;
  bool _phaseTwoLoaded = false;

  StreamSubscription<AuthState>? _authSub;

  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    _startLoading();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
    _latestReviewsScrollController.addListener(_updateScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollArrows();
    });
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _startLoading();
    });
  }

  void _startLoading() {
    setState(() {
      _phaseTwoData = null;
      _phaseTwoLoaded = false;
      _phaseOneFuture = _fetchPhaseOne();
    });
    _fetchPhaseTwo().then((data) {
      if (mounted) {
        setState(() {
          _phaseTwoData = data;
          _phaseTwoLoaded = true;
        });
      }
    });
  }

  void _updateScrollArrows() {
    if (!mounted || !_latestReviewsScrollController.hasClients) return;
    final position = _latestReviewsScrollController.position;
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
    if (mounted) _startLoading();
  }

  Future<void> _handleRefresh() async {
    _startLoading();
    await _phaseOneFuture;
  }

  // ── FASE 1: datos del usuario en paralelo ─────────────────────────────────
  Future<_PhaseOneData> _fetchPhaseOne() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final prefsFuture = SharedPreferences.getInstance();

    String displayName = '';
    List<Map<String, dynamic>> games = [];

    if (currentUser != null) {
      final userId = currentUser.id;

      // Las tres llamadas a Supabase del usuario en paralelo
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('users')
            .select('display_name, username')
            .eq('id', userId)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_games')
            .select('*, games(*)')
            .eq('user_id', userId)
            .eq('status', 'playing'),
        Supabase.instance.client
            .from('reviews')
            .select('game_id')
            .eq('user_id', userId)
            .eq('completion_type', 'on_hold'),
      ]);

      final userResp = results[0] as Map<String, dynamic>?;
      displayName = (userResp?['display_name'] as String?)?.isNotEmpty == true
          ? userResp!['display_name'] as String
          : (userResp?['username'] as String?)?.isNotEmpty == true
          ? userResp!['username'] as String
          : (currentUser.email?.split('@').first ?? 'tu');

      games = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);

      final onHoldReviews = results[2] as List<dynamic>;
      if (onHoldReviews.isNotEmpty) {
        final onHoldGameIds = onHoldReviews.map((r) => r['game_id']).toSet();
        games.removeWhere((g) => onHoldGameIds.contains(g['game_id']));
      }

      // Screenshots (batch único de IGDB — depende de la lista de juegos)
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
    }

    final prefs = await prefsFuture;
    final savedOrder = prefs.getStringList('home_sections_order') ??
        ['hero', 'stash_activity', 'anticipated_games'];
    final savedHidden = prefs.getStringList('home_sections_hidden') ?? [];
    final anticipatedCountdownStyle =
        prefs.getString('anticipated_countdown_style') ?? 'full';
    final wishlistCountdownStyle =
        prefs.getString('wishlist_countdown_style') ??
        prefs.getString('anticipated_countdown_style') ??
        'full';

    const defaultOrder = [
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

    return _PhaseOneData(
      games: games,
      displayName: displayName,
      sectionsOrder: loadedOrder,
      sectionsHidden: savedHidden.toSet(),
      anticipatedCountdownStyle: anticipatedCountdownStyle,
      wishlistCountdownStyle: wishlistCountdownStyle,
    );
  }

  // ── FASE 2: IGDB + reseñas globales, todo en paralelo ────────────────────
  Future<_PhaseTwoData> _fetchPhaseTwo() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    final anticipatedFuture = IGDBService.getMostAnticipatedGames().catchError((e) {
      debugPrint('Error obteniendo anticipated games: $e');
      return <dynamic>[];
    });

    final reviewsFuture = currentUser != null
        ? Supabase.instance.client
              .from('stash_community_reviews')
              .select('*, games(title, cover_url)')
              .eq('source_context', 'recent_activity_feed')
              .order('stash_created_at', ascending: false)
              .limit(25)
              .then((r) => List<Map<String, dynamic>>.from(r))
              .catchError((e) {
                debugPrint('Error obteniendo resenas globales: $e');
                return <Map<String, dynamic>>[];
              })
        : Future.value(<Map<String, dynamic>>[]);

    Future<List<dynamic>> wishlistFuture() async {
      if (currentUser == null) return [];
      try {
        final wishlistResp = await Supabase.instance.client
            .from('user_games')
            .select('game_id')
            .eq('user_id', currentUser.id)
            .eq('status', 'wishlist');
        final wishlistGameIds = List<Map<String, dynamic>>.from(wishlistResp)
            .map((g) => g['game_id'] as int)
            .toList();
        if (wishlistGameIds.isEmpty) return [];
        return await IGDBService.getUpcomingGamesByIds(wishlistGameIds);
      } catch (e) {
        debugPrint('Error obteniendo wishlist anticipados: $e');
        return [];
      }
    }

    // Capturamos cada resultado en variables tipadas via .then()
    // para evitar problemas de inferencia con Future.wait heterogéneo.
    List<dynamic> anticipatedResult = [];
    List<Map<String, dynamic>> reviewsResult = [];
    List<dynamic> wishlistResult = [];

    await Future.wait([
      anticipatedFuture.then((v) => anticipatedResult = v),
      reviewsFuture.then((v) => reviewsResult = v),
      wishlistFuture().then((v) => wishlistResult = v),
    ]);

    return _PhaseTwoData(
      anticipatedGames: anticipatedResult,
      latestReviews: reviewsResult,
      wishlistAnticipatedGames: wishlistResult,
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
      body: FutureBuilder<_PhaseOneData>(
        future: _phaseOneFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final p1 = snapshot.data!;
          final p2 = _phaseTwoData;

          final latestReviews = p2?.latestReviews ?? [];
          final anticipatedGames = p2?.anticipatedGames ?? [];
          final wishlistAnticipatedGames = p2?.wishlistAnticipatedGames ?? [];

          List<Widget> slivers = [];

          for (final sectionKey in p1.sectionsOrder) {
            if (p1.sectionsHidden.contains(sectionKey)) continue;

            if (sectionKey == 'hero') {
              slivers.add(
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: Stack(
                      children: [
                        _isGuest
                            ? GuestHeroShowcase(
                                switchDuration: GuestHeroShowcase.defaultSwitchDuration,
                              )
                            : p1.games.isEmpty
                            ? EmptyPlayingHero(
                                userName: p1.displayName,
                                onSearchPressed: widget.onNavigateToSearch ?? () {},
                                switchDuration: EmptyPlayingHero.defaultSwitchDuration,
                              )
                            : HeroShowcase(
                                playingGames: p1.games,
                                userName: p1.displayName,
                                switchDuration: HeroShowcase.defaultSwitchDuration,
                              ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (sectionKey == 'wishlist_anticipated') {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _phaseTwoLoaded
                        ? (wishlistAnticipatedGames.isNotEmpty
                            ? AnticipatedGamesSection(
                                key: const ValueKey(
                                  'wishlist_anticipated_loaded',
                                ),
                                games: wishlistAnticipatedGames,
                                countdownStyle: p1.wishlistCountdownStyle,
                                title: 'Proximos en tu Wishlist',
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('wishlist_empty'),
                              ))
                        : const _SectionShimmer(
                            key: ValueKey('wishlist_shimmer'),
                            label: 'Proximos en tu Wishlist',
                          ),
                  ),
                ),
              );
            } else if (sectionKey == 'anticipated_games') {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _phaseTwoLoaded
                        ? (anticipatedGames.isNotEmpty
                            ? AnticipatedGamesSection(
                                key: const ValueKey('anticipated_loaded'),
                                games: anticipatedGames,
                                countdownStyle: p1.anticipatedCountdownStyle,
                              )
                            : const SizedBox.shrink(key: ValueKey('anticipated_empty')))
                        : const _SectionShimmer(
                            key: ValueKey('anticipated_shimmer'),
                            label: 'Juegos mas anticipados',
                          ),
                  ),
                ),
              );
            } else if (sectionKey == 'stash_activity') {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _phaseTwoLoaded
                        ? (latestReviews.isNotEmpty
                            ? _buildStashActivity(latestReviews)
                            : const SizedBox.shrink(key: ValueKey('stash_empty')))
                        : const _SectionShimmer(
                            key: ValueKey('stash_shimmer'),
                            label: 'Actividad Global de Stash',
                          ),
                  ),
                ),
              );
            }
          }

          slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));

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

  Widget _buildStashActivity(List<Map<String, dynamic>> latestReviews) {
    return Container(
      key: const ValueKey('stash_activity_loaded'),
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 48.0),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
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
                                              if (game?['title'] != null)
                                                'title': game!['title'],
                                              if (game?['cover_url'] != null)
                                                'cover_url': game!['cover_url'],
                                            },
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
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.videogame_asset),
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
                                            backgroundImage: NetworkImage(
                                              review['stash_user_avatar_url'],
                                            ),
                                            onBackgroundImageError: (_, _) {},
                                          )
                                        else
                                          const Icon(Icons.person, size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            review['stash_user_display_name'] ?? 'Usuario',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.7),
                                            ),
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
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
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
                ValueListenableBuilder<bool>(
                  valueListenable: _canScrollLeft,
                  builder: (context, canLeft, _) {
                    if (!_isDesktop || !canLeft) return const SizedBox.shrink();
                    return Positioned(
                      left: 0, top: 0, bottom: 0,
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
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _canScrollRight,
                  builder: (context, canRight, _) {
                    if (!_isDesktop || !canRight) return const SizedBox.shrink();
                    return Positioned(
                      right: 0, top: 0, bottom: 0,
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
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer placeholder ─────────────────────────────────────────────────────
class _SectionShimmer extends StatefulWidget {
  final String label;
  const _SectionShimmer({super.key, required this.label});

  @override
  State<_SectionShimmer> createState() => _SectionShimmerState();
}

class _SectionShimmerState extends State<_SectionShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.04, end: 0.12).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, child) => Container(
              width: 220,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _anim.value),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (_, child) => AnimatedBuilder(
                animation: _anim,
                builder: (_, child2) => Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _anim.value),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
