import '../../utils/debouncer.dart';
import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/globals.dart';
import '../../utils/igdb_constants.dart';
import '../../utils/postgrest_utils.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../library/filter_screen.dart';
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
  final bool hideStatusChips;
  final VoidCallback onReturn;
  final ScrollController scrollController;

  const ProfileGamesGridTab({
    super.key,
    required this.userId,
    this.status,
    this.hideStatusChips = false,
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
  Map<int, String> _completionTypeMap = {};
  List<int>? _cachedPlatinoGameIds;
  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer();
  GameFilters _filters = const GameFilters(
    sortBy: 'last_played_at',
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
    if (widget.userId != oldWidget.userId) {
      _cachedPlatinoGameIds = null;
    }
    if (widget.status != oldWidget.status || widget.userId != oldWidget.userId) {
      _currentStatus = widget.status ?? 'beaten';
      _refresh();
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
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
      _completionTypeMap = {};
      _cachedPlatinoGameIds = null;
    });
    await loadMore();
  }

  Future<PostgrestTransformBuilder<List<Map<String, dynamic>>>>
  _buildQuery() async {
    var query = Supabase.instance.client
        .from('user_games')
        .select('$kUserGameColumns, games!inner($kGameDetailColumns)')
        .eq('user_id', widget.userId);

    final trimmedSearch = _searchQuery.trim();
    if (trimmedSearch.isNotEmpty) {
      query = query.ilike(
        'games.title',
        '%${escapeLikePattern(trimmedSearch)}%',
      );
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
      if (_cachedPlatinoGameIds == null) {
        final platinoFutures = await Future.wait<dynamic>([
          Supabase.instance.client
              .from('user_games')
              .select('game_id, status')
              .eq('user_id', widget.userId)
              .inFilter('status', ['beaten', 'completed'])
              .limit(5000),
          Supabase.instance.client
              .from('reviews')
              .select('game_id, completion_type, created_at')
              .eq('user_id', widget.userId)
              .order('created_at', ascending: true)
              .limit(5000),
        ]);
        final ugRows = (platinoFutures[0] as List).whereType<Map>();
        final revRows = (platinoFutures[1] as List).whereType<Map>();

        final latestCtByGame = <int, String>{};
        for (final r in revRows) {
          final gid = (r['game_id'] as num?)?.toInt();
          final ct = r['completion_type']?.toString();
          if (gid != null && ct != null && ct.isNotEmpty) {
            latestCtByGame[gid] = ct;
          }
        }

        final ids = <int>{};
        for (final ug in ugRows) {
          final gid = (ug['game_id'] as num?)?.toInt();
          final status = ug['status']?.toString();
          if (gid == null) continue;
          if (status == 'completed' ||
              (status == 'beaten' && latestCtByGame[gid] == '100_percent')) {
            ids.add(gid);
          }
        }
        _cachedPlatinoGameIds = ids.toList();
      }

      if (_cachedPlatinoGameIds!.isEmpty) {
        query = query.inFilter('game_id', [-1]);
      } else {
        query = query.inFilter('game_id', _cachedPlatinoGameIds!);
      }
    } else if (_currentStatus == 'beaten') {
      query = query.eq('status', 'beaten');
    } else if (_currentStatus == 'dropped') {
      query = query.inFilter('status', ['abandoned', 'on_hold']);
    } else if (_currentStatus != null) {
      query = query.eq('status', _currentStatus!);
      if (_currentStatus == 'wishlist') {
        query = query.neq('is_steam_only', true);
      }
    }

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
          nullsFirst: _filters.sortAscending,
        );
        break;
      case 'last_played_at':
      default:
        orderQuery = query.order(
          'last_played_at',
          ascending: _filters.sortAscending,
          nullsFirst: _filters.sortAscending,
        );
        break;
    }
    return orderQuery;
  }

  @override
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;
      final orderQuery = await _buildQuery();
      final res = await orderQuery.range(from, to);

      final newItems = List<Map<String, dynamic>>.from(
        res,
      ).where((r) => r['games'] != null).toList();

      // Si es la primera página y el filtro admite reseñas finalizadas, cargar completion_type
      final skipCompletionMap =
          _currentStatus == 'wishlist' || _currentStatus == 'to_play';
      if (_page == 0 && !skipCompletionMap) {
        final reviewsRes = await Supabase.instance.client
            .from('reviews')
            .select('game_id, completion_type')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: true)
            .limit(5000);
        final map = <int, String>{};
        for (final row in (reviewsRes as List).whereType<Map>()) {
          final gameId = (row['game_id'] as num?)?.toInt();
          final ct = row['completion_type']?.toString();
          if (gameId != null && ct != null && ct.isNotEmpty) {
            map[gameId] = ct;
          }
        }
        if (mounted) setState(() => _completionTypeMap = map);
      }

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
    final result = await Navigator.push<GameFilters>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialFilters: _filters,
          showSort: true,
          isProfileMode: true,
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.hideStatusChips) ...[
                  _buildStatusChips(),
                  const SizedBox(height: 12),
                ],
                _buildSearchBar(),
              ],
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
              prefixIcon: const CorpusTablerIcon(CorpusIconKind.Search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const CorpusTablerIcon(CorpusIconKind.Clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _refresh();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: CorpusThemeExtension.of(context).radiusMedium,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CorpusThemeExtension.of(context).radiusMedium,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CorpusThemeExtension.of(context).radiusMedium,
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) {
              _debouncer.run(() {
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
            icon: const CorpusTablerIcon(CorpusIconKind.Tune),
            label: const Text('Filtros'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: CorpusThemeExtension.of(context).radiusMedium,
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

  CorpusIconKind _getIconForStatus(GameStatus status) => status.icon;

  Widget _buildStatusChips() {
    final validStatuses = GameStatus.pickerOrder.where(
      (s) => s != GameStatus.onHold,
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
              label: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CorpusTablerIcon(_getIconForStatus(status),
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(status.label),
                ],
              ),
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

    final grid = ValueListenableBuilder<int>(
      valueListenable: mobileGridColumnsNotifier,
      builder: (context, columns, child) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, getBottomSpacer(context)),
          sliver: SliverGrid(
            gridDelegate: getCorpusGridDelegate(
              context,
              columns,
              desktopMaxExtent: 120.0,
              spacing: 12.0,
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

              // Extraer completion_type del mapa cargado en loadMore
              final gameId = item['game_id'] as int?;
              final completionType = gameId != null
                  ? _completionTypeMap[gameId]
                  : null;

              return GameCard(
                game: Game.fromMap(gameData),
                isInLibrary: true,
                userRating: rating,
                showMetacriticBadge: _filters.sortBy == 'metacritic_score',
                completionType: completionType,
                onReturn: () {
                  widget.onReturn();
                  _refresh();
                },
              );
            }, childCount: _games.length + (hasMore ? 1 : 0)),
          ),
        );
      },
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
