import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/globals.dart';
import 'dart:async';
import '../../services/igdb_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/explore_bundle_row.dart';
import '../../widgets/horizontal_game_row.dart';
import 'filter_screen.dart';

import '../../widgets/paginated_scroll_mixin.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_tabler_icon.dart';

class ExploreNavigation {
  static final targetQuery = ValueNotifier<String?>(null);
}

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final bool isSelectionMode;
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.isSelectionMode = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with PaginatedScrollMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isInitialSearchLoading = false;
  List<dynamic> _results = [];
  int _searchOffset = 0;

  final List<dynamic> _popularGames = [];
  String _popularGamesError = '';
  bool _isInitialPopularLoading = false;
  bool _hasMorePopularGamesCache = true;
  int _popularOffset = 0;

  GameFilters _filters = const GameFilters();

  // Caché de los juegos del usuario (game_id -> nota)
  Map<int, double> _userGamesCache = {};

  final List<Map<String, dynamic>> _bundles = [];
  bool _isBundlesLoading = true;
  String? _bundlesError;

  @override
  void initState() {
    super.initState();
    initPagination();
    _fetchUserGamesCache();

    final externalQuery = ExploreNavigation.targetQuery.value;
    if (externalQuery != null && externalQuery.isNotEmpty) {
      _searchController.text = externalQuery;
      ExploreNavigation.targetQuery.value = null;
      _performSearch(isInitial: true);
    } else if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(isInitial: true);
    } else {
      _fetchPopularGames(isInitial: true);
      _fetchBundles();
    }
    ExploreNavigation.targetQuery.addListener(_onExternalSearch);
    // Solo la instancia raíz del tab Explorar escucha la señal de scroll-al-inicio.
    if (widget.initialQuery == null && !widget.isSelectionMode) {
      tabScrollToTopNotifiers[1].addListener(_onScrollToTop);
    }
  }

  void _onExternalSearch() {
    final query = ExploreNavigation.targetQuery.value;
    if (query == null || query.isEmpty) return;
    _searchController.text = query;
    ExploreNavigation.targetQuery.value = null;
    _performSearch(isInitial: true);
  }

  @override
  Future<void> loadMore() async {
    if (_searchController.text.trim().isEmpty && !_filters.hasFilters) {
      await _fetchPopularGames(isInitial: false);
    } else {
      await _performSearch(isInitial: false);
    }
  }

  @override
  void dispose() {
    ExploreNavigation.targetQuery.removeListener(_onExternalSearch);
    if (widget.initialQuery == null && !widget.isSelectionMode) {
      tabScrollToTopNotifiers[1].removeListener(_onScrollToTop);
    }
    disposePagination();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScrollToTop() {
    if (!mounted) return;
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchPopularGames({required bool isInitial}) async {
    if (!isInitial && (isLoadingMore || !hasMore)) return;

    if (isInitial) {
      _popularOffset = 0;
      _popularGames.clear();
      hasMore = true;
      _popularGamesError = '';
      setState(() {
        _isInitialPopularLoading = true;
      });
    } else {
      setState(() {
        isLoadingMore = true;
      });
    }

    try {
      final games = await IGDBService.getPopularGames(offset: _popularOffset);
      if (mounted) {
        setState(() {
          if (games.isEmpty) {
            hasMore = false;
            _hasMorePopularGamesCache = false;
          } else {
            _popularGames.addAll(games);
            _popularOffset += 35;
          }
          _popularGamesError = '';
          isLoadingMore = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _popularGamesError = e.toString();
          hasMore = false;
          _hasMorePopularGamesCache = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isInitial) _isInitialPopularLoading = false;
          isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchBundles() async {
    setState(() {
      _isBundlesLoading = true;
      _bundlesError = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('active_bundles')
          .select()
          .order('end_date', ascending: true);

      final newBundles = List<Map<String, dynamic>>.from(response);
      final now = DateTime.now();
      newBundles.retainWhere((b) {
        if (b['end_date'] == null) return true;
        final endDate = DateTime.parse(b['end_date']);
        return endDate.isAfter(now);
      });

      newBundles.sort((a, b) {
        final dateA = a['end_date'] != null
            ? DateTime.parse(a['end_date'])
            : DateTime(2100);
        final dateB = b['end_date'] != null
            ? DateTime.parse(b['end_date'])
            : DateTime(2100);
        return dateA.compareTo(dateB);
      });

      if (mounted) {
        setState(() {
          _bundles
            ..clear()
            ..addAll(newBundles);
          _isBundlesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bundlesError = e.toString();
          _isBundlesLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserGamesCache() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _userGamesCache = {};
        });
      }
      return;
    }

    final userId = user.id;
    final response = await Supabase.instance.client
        .from('user_games')
        .select('game_id, rating')
        .eq('user_id', userId);

    final List<dynamic> data = response;

    if (mounted) {
      setState(() {
        _userGamesCache = {
          for (var item in data)
            item['game_id'] as int: (item['rating'] ?? 0).toDouble(),
        };
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Esperamos 500ms después de que el usuario deje de escribir
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty && !_filters.hasFilters) {
        setState(() {
          _results = [];
          _isInitialSearchLoading = false;
          hasMore = _hasMorePopularGamesCache;
        });
      } else {
        _performSearch(isInitial: true);
      }
    });
  }

  void _openFilters() async {
    final result = await Navigator.push<GameFilters>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(initialFilters: _filters),
      ),
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
      _performSearch(isInitial: true);
    }
  }

  int _searchVersion = 0;

  Future<void> _performSearch({required bool isInitial}) async {
    if (!isInitial && (isLoadingMore || !hasMore)) return;

    if (isInitial) {
      _searchOffset = 0;
      _results.clear();
      hasMore = true;
    }

    final int version = ++_searchVersion;
    setState(() {
      if (isInitial) {
        _isInitialSearchLoading = true;
      } else {
        isLoadingMore = true;
      }
    });

    try {
      final query = _searchController.text.trim();
      final games = await IGDBService.searchGames(
        query,
        offset: _searchOffset,
        sortBy: _filters.sortBy,
        sortAscending: _filters.sortAscending,
        genres: _filters.genres.isNotEmpty ? _filters.genres : null,
        themes: _filters.themes.isNotEmpty ? _filters.themes : null,
        gameModes: _filters.gameModes.isNotEmpty ? _filters.gameModes : null,
        playerPerspectives: _filters.playerPerspectives.isNotEmpty
            ? _filters.playerPerspectives
            : null,
        platforms: _filters.platforms.isNotEmpty ? _filters.platforms : null,
        categories: _filters.categories.isNotEmpty ? _filters.categories : null,
      );

      debugPrint('[DEBUG] searchGames devolvió ${games.length} resultados');

      if (mounted && version == _searchVersion) {
        setState(() {
          if (games.isEmpty) {
            hasMore = false;
          } else {
            _results.addAll(games);
            _searchOffset += 35;
          }
        });
      }
    } catch (e, st) {
      debugPrint('[SearchScreen] Error en searchGames: $e\n$st');
      if (mounted && version == _searchVersion) {
        setState(() {
          hasMore = false;
        });
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() {
          if (isInitial) _isInitialSearchLoading = false;
          isLoadingMore = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CorpusScreenTitle('Explorar'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildSearchField(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        autofocus: false,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar juegos...',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: ext.radiusLarge,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: ext.radiusLarge,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: ext.radiusLarge,
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const CorpusTablerIcon.clear(size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
        style: const TextStyle(fontSize: 16),
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
      ),
    );
  }

  Widget _buildFiltersHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const CorpusTablerIcon.tune(size: 20),
          label: Text(
            'Filtros${_filters.hasFilters ? ' (${_filters.filterCount})' : ''}',
          ),
          style: TextButton.styleFrom(
            foregroundColor: _filters.hasFilters
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: _openFilters,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.trim().isEmpty && !_filters.hasFilters) {
      if (_popularGamesError.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersHeader(),
            Expanded(
              child: Center(
                child: Text(
                  'Error cargando tendencias:\n$_popularGamesError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        );
      }
      if (_popularGames.isEmpty && _isInitialPopularLoading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersHeader(),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        );
      }
      return _buildExploreBody();
    }

    if (_results.isEmpty && _isInitialSearchLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFiltersHeader(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_results.isEmpty && !_isInitialSearchLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFiltersHeader(),
          Expanded(
            child: Center(
              child: Text(
                'No se encontraron resultados...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildGrid(_results);
  }

  Future<void> _refreshExplore() async {
    await Future.wait([
      _fetchPopularGames(isInitial: true),
      _fetchBundles(),
      _fetchUserGamesCache(),
    ]);
  }

  Widget _buildExploreBody() {
    return RefreshIndicator(
      onRefresh: _refreshExplore,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildFiltersHeader()),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: CorpusSectionTitle('Tendencias'),
            ),
          ),
          SliverToBoxAdapter(
            child: HorizontalGameRow(
              games: _popularGames,
              userGamesCache: _userGamesCache,
              onReturn: _fetchUserGamesCache,
              onEndReached: hasMore && !isLoadingMore
                  ? () => _fetchPopularGames(isInitial: false)
                  : null,
            ),
          ),
          if (isLoadingMore && _popularGames.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
            sliver: SliverToBoxAdapter(
              child: CorpusSectionTitle('Bundles'),
            ),
          ),
          if (_isBundlesLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else if (_bundlesError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudieron cargar los bundles.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else if (_bundles.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No hay bundles activos en este momento.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    ExploreBundleRow(bundle: _bundles[index]),
                childCount: _bundles.length,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: getBottomSpacer(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<dynamic> gamesList) {
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildFiltersHeader()),
        ValueListenableBuilder<int>(
          valueListenable: mobileGridColumnsNotifier,
          builder: (context, columns, child) {
            return SliverPadding(
              padding: EdgeInsets.only(
                left: 8.0,
                right: 8.0,
                top: 8.0,
                bottom: getBottomSpacer(context),
              ),
              sliver: SliverGrid.builder(
                gridDelegate: getCorpusGridDelegate(
                  context,
                  columns,
                  desktopMaxExtent: 150.0,
                  spacing: 8.0,
                ),
                itemCount: gamesList.length + (hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= gamesList.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final game = Game.fromMap(gamesList[index]);
                  final bool isInLibrary = _userGamesCache.containsKey(
                    game.igdbId,
                  );
                  final double userRating = isInLibrary
                      ? _userGamesCache[game.igdbId]!
                      : 0.0;

                  return GameCard(
                    game: game,
                    isInLibrary: isInLibrary,
                    userRating: userRating,
                    onReturn: _fetchUserGamesCache,
                    onTap: widget.isSelectionMode
                        ? (cleanData) => Navigator.pop(context, cleanData)
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
