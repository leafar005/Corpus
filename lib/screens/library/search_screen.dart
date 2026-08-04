import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'dart:async';
import '../../services/igdb_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/filter_bottom_sheet.dart';

import '../../widgets/paginated_scroll_mixin.dart';

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

  GameFilters _filters = GameFilters();

  // Caché de los juegos del usuario (game_id -> nota)
  Map<int, double> _userGamesCache = {};

  @override
  void initState() {
    super.initState();
    initPagination();
    _fetchUserGamesCache();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(isInitial: true);
    } else {
      _fetchPopularGames(isInitial: true);
    }
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
    disposePagination();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
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
    final result = await showModalBottomSheet<GameFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FilterBottomSheet(initialFilters: _filters),
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
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            autofocus: true,
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
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: _onSearchChanged,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildFiltersHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.tune, size: 20),
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
      return _buildGrid(_popularGames);
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

  Widget _buildGrid(List<dynamic> gamesList) {
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildFiltersHeader()),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            top: 8.0,
            bottom: getBottomSpacer(context),
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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

              final game = gamesList[index];
              final bool isInLibrary = _userGamesCache.containsKey(game['id']);
              final double userRating = isInLibrary
                  ? _userGamesCache[game['id']]!
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
        ),
      ],
    );
  }
}
