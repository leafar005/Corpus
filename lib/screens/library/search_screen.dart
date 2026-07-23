import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../services/igdb_service.dart';
import '../../widgets/game_card.dart';
import '../../widgets/filter_bottom_sheet.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  
  bool _isLoading = false;
  List<dynamic> _results = [];
  bool _hasMoreSearchResults = true;
  int _searchOffset = 0;

  final List<dynamic> _popularGames = [];
  String _popularGamesError = '';
  bool _isLoadingPopular = false;
  bool _hasMorePopularGames = true;
  int _popularOffset = 0;

  GameFilters _filters = GameFilters();
  
  // Caché de los juegos del usuario (game_id -> nota)
  Map<int, double> _userGamesCache = {};

  @override
  void initState() {
    super.initState();
    _fetchUserGamesCache();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(isInitial: true);
    } else {
      _fetchPopularGames(isInitial: true);
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_searchController.text.trim().isEmpty && !_filters.hasFilters) {
          _fetchPopularGames(isInitial: false);
        } else {
          _performSearch(isInitial: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPopularGames({required bool isInitial}) async {
    if (_isLoadingPopular || !_hasMorePopularGames) return;
    
    if (isInitial) {
      _popularOffset = 0;
      _popularGames.clear();
      _hasMorePopularGames = true;
      _popularGamesError = '';
    }

    setState(() { _isLoadingPopular = true; });

    try {
      final games = await IGDBService.getPopularGames(offset: _popularOffset);
      if (mounted) {
        setState(() {
          if (games.isEmpty) {
            _hasMorePopularGames = false;
          } else {
            _popularGames.addAll(games);
            _popularOffset += 35;
          }
          _popularGamesError = '';
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && 
              _scrollController.position.maxScrollExtent == 0 && 
              _hasMorePopularGames) {
            _fetchPopularGames(isInitial: false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _popularGamesError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() { _isLoadingPopular = false; });
    }
  }

  Future<void> _fetchUserGamesCache() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('user_games')
        .select('game_id, rating')
        .eq('user_id', userId);
        
    final List<dynamic> data = response;
    
    if (mounted) {
      setState(() {
        _userGamesCache = {
          for (var item in data) item['game_id'] as int: (item['rating'] ?? 0).toDouble()
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
          _isLoading = false;
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
    if (!isInitial && (_isLoading || !_hasMoreSearchResults)) return;

    if (isInitial) {
      _searchOffset = 0;
      _results.clear();
      _hasMoreSearchResults = true;
    }

    final int version = ++_searchVersion;
    setState(() { _isLoading = true; });

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
        playerPerspectives: _filters.playerPerspectives.isNotEmpty ? _filters.playerPerspectives : null,
        platforms: _filters.platforms.isNotEmpty ? _filters.platforms : null,
        categories: _filters.categories.isNotEmpty ? _filters.categories : null,
      );
      
      if (mounted && version == _searchVersion) {
        setState(() {
          if (games.isEmpty) {
            _hasMoreSearchResults = false;
          } else {
            _results.addAll(games);
            _searchOffset +=35;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && 
              _scrollController.position.maxScrollExtent == 0 && 
              _hasMoreSearchResults) {
            _performSearch(isInitial: false);
          }
        });
      }
    } catch (e) {
      // Ignorar el error o mostrar en la interfaz si lo deseas
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Buscar juegos...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: _onSearchChanged,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextButton.icon(
              icon: const Icon(Icons.tune, size: 20),
              label: Text('Filtros${_filters.hasFilters ? ' (${_filters.filterCount})' : ''}'),
              style: TextButton.styleFrom(
                foregroundColor: _filters.hasFilters ? Theme.of(context).colorScheme.primary : Colors.grey[400],
              ),
              onPressed: _openFilters,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.trim().isEmpty && !_filters.hasFilters) {
      if (_popularGamesError.isNotEmpty) {
        return Center(
          child: Text('Error cargando tendencias:\n$_popularGamesError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        );
      }
      if (_popularGames.isEmpty && _isLoadingPopular) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Novedades Populares', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(child: _buildGrid(_popularGames, _isLoadingPopular)),
        ],
      );
    }

    if (_results.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty && !_isLoading) {
      return const Center(
        child: Text(
          'No se encontraron resultados...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return _buildGrid(_results, _isLoading);
  }

  Widget _buildGrid(List<dynamic> gamesList, bool isLoadingMore) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150, 
              childAspectRatio: 0.7, 
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: gamesList.length,
            itemBuilder: (context, index) {
              final game = gamesList[index];
              final bool isInLibrary = _userGamesCache.containsKey(game['id']);
              final double userRating = isInLibrary ? _userGamesCache[game['id']]! : 0.0;

              return GameCard(
                game: game,
                isInLibrary: isInLibrary,
                userRating: userRating,
                onReturn: _fetchUserGamesCache,
              );
            },
          ),
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
