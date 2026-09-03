import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/igdb_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import '../../widgets/corpus_network_image.dart';
import '../../models/models.dart';
import '../../widgets/game_card.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'hero_showcase.dart';
import 'anticipated_games_section.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/p5r_styled_panel.dart';

import 'controller/home_controller.dart';

// ────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSearch;
  final Function(String)? onNavigateToBundles;

  const HomeScreen({
    super.key,
    this.onNavigateToSearch,
    this.onNavigateToBundles,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _latestReviewsScrollController = ScrollController();
  final ValueNotifier<bool> _canScrollLeft = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollRight = ValueNotifier(true);

  final PageController _bundlesScrollController = PageController();
  final ValueNotifier<bool> _canScrollBundlesLeft = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollBundlesRight = ValueNotifier(true);
  final ValueNotifier<int> _currentBundlePage = ValueNotifier(0);

  bool get _isDesktop {
    if (!mounted) return false;
    try {
      return MediaQuery.sizeOf(context).width > kDesktopBreakpoint;
    } catch (e) {
      debugPrint('[HomeScreen] MediaQuery no disponible en _isDesktop: $e');
      return defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;
    }
  }

  late final HomeController _controller;
  StreamSubscription<AuthState>? _authSub;

  bool get _isGuest => _controller.isGuest;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.reload();

    libraryUpdateNotifier.addListener(_onLibraryUpdated);
    _latestReviewsScrollController.addListener(_updateScrollArrows);
    _bundlesScrollController.addListener(_updateBundlesScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollArrows();
      _updateBundlesScrollArrows();
    });
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _controller.reload();
    });
  }

  void _updateScrollArrows() {
    if (!mounted || !_latestReviewsScrollController.hasClients) return;
    final position = _latestReviewsScrollController.position;
    _canScrollLeft.value = position.pixels > 1.0;
    _canScrollRight.value = position.pixels < (position.maxScrollExtent - 1.0);
  }

  void _updateBundlesScrollArrows() {
    if (!mounted || !_bundlesScrollController.hasClients) return;
    final position = _bundlesScrollController.position;
    _canScrollBundlesLeft.value = position.pixels > 1.0;
    _canScrollBundlesRight.value =
        position.pixels < (position.maxScrollExtent - 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _latestReviewsScrollController.removeListener(_updateScrollArrows);
    _latestReviewsScrollController.dispose();
    _bundlesScrollController.removeListener(_updateBundlesScrollArrows);
    _bundlesScrollController.dispose();
    _canScrollLeft.dispose();
    _canScrollRight.dispose();
    _canScrollBundlesLeft.dispose();
    _canScrollBundlesRight.dispose();
    _currentBundlePage.dispose();
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _authSub?.cancel();
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) _controller.reload();
  }

  Future<void> _handleRefresh() async {
    _controller.reload();
    await _controller.phaseOneFuture;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: kIsWeb
          ? null
          : AppBar(
              title: const CorpusScreenTitle('Inicio'),
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              elevation: 0,
            ),
      body: FutureBuilder<HomePhaseOneData>(
        future: _controller.phaseOneFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final p1 = snapshot.data!;
          final p2 = _controller.phaseTwoData;

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
                      clipBehavior: Clip.none,
                      children: [
                        _isGuest
                            ? GuestHeroShowcase(
                                switchDuration:
                                    GuestHeroShowcase.defaultSwitchDuration,
                              )
                            : p1.games.isEmpty
                            ? EmptyPlayingHero(
                                userName: p1.displayName,
                                onSearchPressed:
                                    widget.onNavigateToSearch ?? () {},
                                switchDuration:
                                    EmptyPlayingHero.defaultSwitchDuration,
                              )
                            : HeroShowcase(
                                playingGames: p1.games,
                                userName: p1.displayName,
                                switchDuration:
                                    HeroShowcase.defaultSwitchDuration,
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
                    child: _controller.phaseTwoLoaded
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
                    child: _controller.phaseTwoLoaded
                        ? (anticipatedGames.isNotEmpty
                              ? AnticipatedGamesSection(
                                  key: const ValueKey('anticipated_loaded'),
                                  games: anticipatedGames,
                                  countdownStyle: p1.anticipatedCountdownStyle,
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('anticipated_empty'),
                                ))
                        : const _SectionShimmer(
                            key: ValueKey('anticipated_shimmer'),
                            label: 'Juegos mas anticipados',
                          ),
                  ),
                ),
              );
            } else if (sectionKey == 'bundles_ending_soon') {
              final bundles = p2?.bundlesEndingSoon ?? [];
              slivers.add(
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _controller.phaseTwoLoaded
                        ? (bundles.isNotEmpty
                              ? _buildBundlesEndingSoonSection(bundles)
                              : const SizedBox.shrink(
                                  key: ValueKey('bundles_empty'),
                                ))
                        : const _SectionShimmer(
                            key: ValueKey('bundles_shimmer'),
                            label: 'Oportunidades Finales',
                          ),
                  ),
                ),
              );
            } else if (sectionKey == 'stash_activity') {
              slivers.add(
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _controller.phaseTwoLoaded
                        ? (latestReviews.isNotEmpty
                              ? _buildStashActivity(latestReviews)
                              : const SizedBox.shrink(
                                  key: ValueKey('stash_empty'),
                                ))
                        : const _SectionShimmer(
                            key: ValueKey('stash_shimmer'),
                            label: 'Actividad Global de Stash',
                          ),
                  ),
                ),
              );
            }
          }
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.only(bottom: getBottomSpacer(context)),
            ),
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

  Widget _buildBundlesEndingSoonSection(List<Map<String, dynamic>> bundles) {
    return Container(
      key: const ValueKey('bundles_loaded'),
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CorpusSectionTitle('Oportunidades Finales'),
          const SizedBox(height: 16),
          SizedBox(
            height: _isDesktop ? 220 : 240,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _bundlesScrollController,
                  itemCount: bundles.length,
                  onPageChanged: (index) {
                    _currentBundlePage.value = index;
                  },
                  itemBuilder: (context, index) {
                    final bundle = bundles[index];
                    final endDate = DateTime.parse(bundle['end_date']);
                    final difference = endDate.difference(DateTime.now());
                    final days = difference.inDays;
                    final hours = difference.inHours % 24;

                    // Extraer los primeros 4 juegos para mostrarlos
                    List<Map<String, dynamic>> allGames = [];
                    final tiers = bundle['tiers'] as List<dynamic>? ?? [];
                    for (final tier in tiers) {
                      final games = tier['games'] as List<dynamic>? ?? [];
                      for (final game in games) {
                        if (game is Map<String, dynamic>) {
                          allGames.add(game);
                        }
                      }
                    }

                    // Ordenar por popularidad
                    allGames.sort((a, b) {
                      final aPop =
                          (a['total_rating_count'] as num?)?.toInt() ??
                          (a['follows'] as num?)?.toInt() ??
                          (a['metacritic_score'] as num?)?.toInt() ??
                          0;
                      final bPop =
                          (b['total_rating_count'] as num?)?.toInt() ??
                          (b['follows'] as num?)?.toInt() ??
                          (b['metacritic_score'] as num?)?.toInt() ??
                          0;
                      return bPop.compareTo(aPop);
                    });
                    const coverWidth = 125.0;

                    final isHumble = (bundle['store_name'] ?? '')
                        .toLowerCase()
                        .contains('humble');
                    final isFanatical = (bundle['store_name'] ?? '')
                        .toLowerCase()
                        .contains('fanatical');
                    Widget storeIcon;
                    if (isHumble) {
                      storeIcon = Image.asset(
                        'assets/images/humble_logo.png',
                        width: 48,
                        height: 48,
                      );
                    } else if (isFanatical) {
                      storeIcon = Image.asset(
                        'assets/images/fanatical_logo.png',
                        width: 48,
                        height: 48,
                      );
                    } else {
                      storeIcon = Icon(
                        Icons.local_offer,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    }

                    final isP5r = Theme.of(
                      context,
                    ).extension<CorpusThemeExtension>()!.useDynamicFrames;

                    final bundleInfo = MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          context.pushBundleDetails(bundle);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bundle['store_name'] ?? 'Tienda',
                              style: TextStyle(
                                color: isP5r
                                    ? Colors.white54
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                fontSize: 13,
                                letterSpacing: isP5r ? 1.0 : 0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bundle['title'] ?? 'Bundle',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isP5r ? 20 : 22,
                                color: isP5r
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (isP5r)
                              P5rTextBadge(text: '$days días')
                            else
                              Text(
                                'Termina en $days días y $hours horas',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );

                    return CorpusStyledPanel(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const coverGap = 8.0;
                          const minTextWidth = 150.0;
                          final storeIconWidth = _isDesktop ? 48.0 + 12.0 : 0.0;
                          const mobileCoverGridWidth = 132.0;

                          int desktopCoverCount = allGames.length;
                          if (_isDesktop && allGames.isNotEmpty) {
                            desktopCoverCount = 1;
                            for (
                              int count = allGames.length;
                              count >= 1;
                              count--
                            ) {
                              final coversWidth =
                                  count * coverWidth + (count - 1) * coverGap;
                              final reservedWidth =
                                  storeIconWidth + 12 + coversWidth;
                              if (constraints.maxWidth - reservedWidth >=
                                  minTextWidth) {
                                desktopCoverCount = count;
                                break;
                              }
                            }
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_isDesktop) ...[
                                storeIcon,
                                const SizedBox(width: 12),
                              ],
                              Expanded(child: bundleInfo),
                              if (allGames.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                if (_isDesktop)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (
                                        int i = 0;
                                        i < desktopCoverCount;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(width: 8),
                                        SizedBox(
                                          width: coverWidth,
                                          child: AspectRatio(
                                            aspectRatio:
                                                IgdbConstants.coverAspectRatio,
                                            child: GameCard(
                                              key: ValueKey(
                                                allGames[i]['steamAppId'] ??
                                                    allGames[i]['title'] ??
                                                    i,
                                              ),
                                              game: Game.fromMap(allGames[i]),
                                              onReturn: () {},
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else
                                  SizedBox(
                                    width: mobileCoverGridWidth,
                                    child: GridView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 6,
                                            crossAxisSpacing: 6,
                                            childAspectRatio:
                                                IgdbConstants.coverAspectRatio,
                                          ),
                                      itemCount: allGames.length > 4
                                          ? 4
                                          : allGames.length,
                                      itemBuilder: (context, index) {
                                        return GameCard(
                                          key: ValueKey(
                                            allGames[index]['steamAppId'] ??
                                                allGames[index]['title'] ??
                                                index,
                                          ),
                                          game: Game.fromMap(allGames[index]),
                                          onReturn: () {},
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
                if (bundles.length > 1 && _isDesktop)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _canScrollBundlesLeft,
                        builder: (context, canScroll, child) {
                          if (!canScroll) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.chevron_left, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.5,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _bundlesScrollController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                if (bundles.length > 1 && _isDesktop)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _canScrollBundlesRight,
                        builder: (context, canScroll, child) {
                          if (!canScroll) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.chevron_right, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.5,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _bundlesScrollController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (bundles.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentBundlePage,
                  builder: (context, currentPage, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        bundles.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentPage == index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isTextTruncated(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  void _showFullReviewSheet(
    Map<String, dynamic> review,
    Map<String, dynamic>? game,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (game?['cover_url'] != null)
                        InkWell(
                          onTap: () {
                            if (review['game_id'] != null) {
                              Navigator.pop(
                                context,
                              ); // Close the bottom sheet first
                              context.pushGameDetails(
                                Game.fromMap({
                                  'id': review['game_id'],
                                  if (game['title'] != null)
                                    'title': game['title'],
                                  if (game['cover_url'] != null)
                                    'cover_url': game['cover_url'],
                                }),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CorpusNetworkImage(
                              url: game!['cover_url'],
                              width: 44,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: const Icon(Icons.videogame_asset),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game?['title'] ?? 'Juego Desconocido',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (review['stash_user_avatar_url'] != null)
                                  CircleAvatar(
                                    radius: 9,
                                    backgroundImage: NetworkImage(
                                      review['stash_user_avatar_url'],
                                    ),
                                    onBackgroundImageError: (_, _) {},
                                  )
                                else
                                  const Icon(Icons.person, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    review['stash_user_display_name'] ??
                                        'Usuario',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              review['rating'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    review['comment'] ?? '',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStashActivity(List<Map<String, dynamic>> latestReviews) {
    return Container(
      key: const ValueKey('stash_activity_loaded'),
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CorpusSectionTitle('Actividad Global de Stash'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.builder(
                  clipBehavior: Clip.none,
                  controller: _latestReviewsScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16.0),
                  itemCount: latestReviews.length,
                  itemBuilder: (context, index) {
                    final review = latestReviews[index];
                    final game = review['games'];
                    final comment = review['comment'] ?? '';
                    const commentStyle = TextStyle(fontSize: 13);
                    final isTruncated = _isTextTruncated(
                      comment,
                      commentStyle,
                      280 - 24,
                      4,
                    );

                    return GestureDetector(
                      onTap: () => _showFullReviewSheet(review, game),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 280,
                          child: CorpusStyledPanel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (game?['cover_url'] != null)
                                      InkWell(
                                        onTap: () {
                                          if (review['game_id'] != null) {
                                            context.pushGameDetails(
                                              Game.fromMap({
                                                'id': review['game_id'],
                                                if (game?['title'] != null)
                                                  'title': game!['title'],
                                                if (game?['cover_url'] != null)
                                                  'cover_url':
                                                      game!['cover_url'],
                                              }),
                                            );
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius: Theme.of(context)
                                              .extension<
                                                CorpusThemeExtension
                                              >()!
                                              .radiusSmall,
                                          child: CorpusNetworkImage(
                                            url: game['cover_url'],
                                            width: 40,
                                            height: 50,
                                            fit: BoxFit.cover,
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              if (review['stash_user_avatar_url'] !=
                                                  null)
                                                CircleAvatar(
                                                  radius: 8,
                                                  backgroundImage: NetworkImage(
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
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                    comment,
                                    style: commentStyle,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isTruncated)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Leer más',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
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
                    if (!_isDesktop || !canRight) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
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
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
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
    _anim = Tween<double>(
      begin: 0.04,
      end: 0.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) => Container(
                width: 220,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: _anim.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: 4,
              itemBuilder: (_, child) => AnimatedBuilder(
                animation: _anim,
                builder: (context, child2) => Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: _anim.value),
                    borderRadius: Theme.of(
                      context,
                    ).extension<CorpusThemeExtension>()!.radiusLarge,
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
