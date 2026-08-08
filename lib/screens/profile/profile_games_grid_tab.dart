import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';
import '../../utils/igdb_constants.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../theme/corpus_theme_extension.dart';

/// Pestaña "Juegos" del perfil: feed de juegos del usuario
/// con scroll infinito y carga paginada.
///
/// Uso:
/// ```dart
/// ProfileGamesGridTab(userId: profileUserId, filters: _filters, status: 'beaten')
/// ```
class ProfileGamesGridTab extends StatefulWidget {
  final String userId;
  final String? status; // null para todos, o 'beaten', 'playing', 'wishlist'
  final VoidCallback onReturn;
  final ScrollController scrollController;

  const ProfileGamesGridTab({
    super.key,
    required this.userId,
    this.status,
    required this.onReturn,
    required this.scrollController,
  });

  @override
  State<ProfileGamesGridTab> createState() => _ProfileGamesGridTabState();
}

class _ProfileGamesGridTabState extends State<ProfileGamesGridTab>
    with PaginatedScrollMixin {
  static const int _pageSize = 30;

  final List<Map<String, dynamic>> _games = [];
  int _page = 0;
  bool _isInitialLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  GameFilters _filters = GameFilters(
    sortBy: 'updated_at',
    sortAscending: false,
  );

  @override
  void initState() {
    super.initState();
    initPagination(externalController: widget.scrollController);
    loadMore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    disposePagination();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _games.clear();
      _page = 0;
      hasMore = true;
      _isInitialLoading = true;
      _error = null;
    });
    await loadMore();
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = Supabase.instance.client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', widget.userId);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('games.title', '%$_searchQuery%');
      }

      if (_filters.genres.isNotEmpty) {
        for (var id in _filters.genres) {
          final name = IgdbConstants.genres.firstWhere(
            (e) => e['id'] == id,
            orElse: () => {'name': ''},
          )['name'];
          if (name != '') query = query.contains('games.genres', '["$name"]');
        }
      }
      if (_filters.themes.isNotEmpty) {
        for (var id in _filters.themes) {
          final name = IgdbConstants.themes.firstWhere(
            (e) => e['id'] == id,
            orElse: () => {'name': ''},
          )['name'];
          if (name != '') query = query.contains('games.themes', '["$name"]');
        }
      }
      if (_filters.gameModes.isNotEmpty) {
        for (var id in _filters.gameModes) {
          final name = IgdbConstants.gameModes.firstWhere(
            (e) => e['id'] == id,
            orElse: () => {'name': ''},
          )['name'];
          if (name != '') {
            query = query.contains('games.game_modes', '["$name"]');
          }
        }
      }
      if (_filters.playerPerspectives.isNotEmpty) {
        for (var id in _filters.playerPerspectives) {
          final name = IgdbConstants.playerPerspectives.firstWhere(
            (e) => e['id'] == id,
            orElse: () => {'name': ''},
          )['name'];
          if (name != '') {
            query = query.contains('games.player_perspectives', '["$name"]');
          }
        }
      }
      if (_filters.platforms.isNotEmpty) {
        for (var id in _filters.platforms) {
          final name = IgdbConstants.popularPlatforms.firstWhere(
            (e) => e['id'] == id,
            orElse: () => {'name': ''},
          )['name'];
          if (name != '') {
            query = query.contains('games.platforms', '["$name"]');
          }
        }
      }

      query = query.eq('status', widget.status ?? 'beaten');
      if (widget.status == 'wishlist') {
        query = query.neq('is_steam_only', true);
      }

      // Ordenar según los filtros (usando referencedTable y evitando reasignar el FilterBuilder a TransformBuilder)
      PostgrestTransformBuilder<List<Map<String, dynamic>>> orderQuery;

      switch (_filters.sortBy) {
        case 'title':
          orderQuery = query.order(
            'games(title)',
            ascending: _filters.sortAscending,
          );
          break;
        case 'release_date':
          orderQuery = query.order(
            'games(release_date)',
            ascending: _filters.sortAscending,
          );
          break;
        case 'rating':
          orderQuery = query.order('rating', ascending: _filters.sortAscending);
          break;
        case 'metacritic_score':
          orderQuery = query.order(
            'games(metacritic_score)',
            ascending: _filters.sortAscending,
            nullsFirst: _filters
                .sortAscending, // nulls al final cuando ordenamos desc (mayor nota primero)
          );
          break;
        case 'updated_at':
        default:
          orderQuery = query.order(
            'updated_at',
            ascending: _filters.sortAscending,
          );
          break;
      }

      final res = await orderQuery.range(from, to);

      final newItems = List<Map<String, dynamic>>.from(
        res,
      ).where((r) => r['games'] != null).toList();

      if (mounted) {
        setState(() {
          _games.addAll(newItems);
          _page++;
          hasMore =
              res.length ==
              _pageSize; // Comparar con los devueltos originalmente
          isLoadingMore = false;
          _isInitialLoading = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      debugPrint('[CORPUS] Error cargando juegos: $e');
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los juegos.';
          isLoadingMore = false;
          _isInitialLoading = false;
          hasMore = false;
        });
      }
    }
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<GameFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FilterBottomSheet(
        initialFilters: _filters,
        showSort: true,
        isProfileMode: true,
      ),
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSearchBar(),
          ),
        ),
        _buildGridSliver(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar juego...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _refresh();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusMedium,
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                setState(() => _searchQuery = value.trim());
                _refresh();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: _filters.hasFilters,
          label: Text(_filters.filterCount.toString()),
          offset: const Offset(0, 0),
          child: FilledButton.icon(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
            label: const Text('Filtros'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusMedium,
              ),
              minimumSize: const Size(
                0,
                56,
              ), // Matches default TextField height
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridSliver() {
    if (_isInitialLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_games.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              _error ?? 'No hay juegos para mostrar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _games.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final item = _games[index];
          final gameData = item['games'] as Map<String, dynamic>;
          final rating = (item['rating'] ?? 0).toDouble();
          gameData['user_rating'] = rating;
          gameData['is_steam_only'] = item['is_steam_only'];

          return GameCard(
            game: Game.fromMap(gameData),
            isInLibrary: true,
            userRating: rating,
            showMetacriticBadge: _filters.sortBy == 'metacritic_score',
            onReturn: () {
              widget.onReturn();
              _refresh();
            },
          );
        }, childCount: _games.length + (hasMore ? 1 : 0)),
      ),
    );
  }
}
