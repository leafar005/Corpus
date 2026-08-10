import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';
import '../../utils/igdb_constants.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../../widgets/filter_bottom_sheet.dart';

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
  String? _currentStatus;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  GameFilters _filters = GameFilters(
    sortBy: 'updated_at',
    sortAscending: false,
  );

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status ?? 'beaten';
    initPagination(externalController: widget.scrollController);
    loadMore();
  }

  @override
  void didUpdateWidget(ProfileGamesGridTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      _currentStatus = widget.status ?? 'beaten';
      _refresh();
    }
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

      if (_currentStatus == 'completed') {
        // Platino: filtramos buscando los game_ids en reviews que tengan completion_type = '100_percent'
        final platinoReviews = await Supabase.instance.client
            .from('reviews')
            .select('game_id')
            .eq('user_id', widget.userId)
            .eq('completion_type', '100_percent');

        final platinoGameIds = platinoReviews
            .map((r) => r['game_id'] as int)
            .toList();
        if (platinoGameIds.isEmpty) {
          query = query.inFilter('game_id', [-1]); // Forzar lista vacía
        } else {
          query = query.inFilter('game_id', platinoGameIds);
        }
      } else if (_currentStatus != null) {
        query = query.eq('status', _currentStatus!);
        if (_currentStatus == 'wishlist') {
          query = query.neq('is_steam_only', true);
        }
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusChips(),
                    const SizedBox(height: 12),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
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
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
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

  IconData _getIconForStatus(GameStatus status) {
    switch (status) {
      case GameStatus.wishlist:
        return Icons.bookmark;
      case GameStatus.playing:
        return Icons.sports_esports;
      case GameStatus.beaten:
        return Icons.check_circle;
      case GameStatus.completed:
        return Icons.emoji_events;
      case GameStatus.abandoned:
        return Icons.cancel;
      case GameStatus.paused:
        return Icons.pause;
    }
  }

  Widget _buildStatusChips() {
    final validStatuses = GameStatus.values.where(
      (s) => s != GameStatus.paused,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: validStatuses.map((status) {
          final isSelected = _currentStatus == status.dbValue;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                _getIconForStatus(status),
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              label: Text(status.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _currentStatus = status.dbValue);
                  _refresh();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridSliver() {
    if (_isInitialLoading) {
      return SliverToBoxAdapter(
        child: Container(
          height: MediaQuery.of(context).size.height,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_games.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: MediaQuery.of(context).size.height,
          alignment: Alignment.center,
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

    final grid = SliverPadding(
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

    if (_games.length < 20) {
      return SliverMainAxisGroup(
        slivers: [
          grid,
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).size.height),
          ),
        ],
      );
    }

    return grid;
  }
}
