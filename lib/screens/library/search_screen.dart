import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../services/igdb_service.dart';
import 'game_details_screen.dart';
import 'package:corpus/widgets/game_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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

  List<dynamic> _popularGames = [];
  String _popularGamesError = '';
  bool _isLoadingPopular = false;
  bool _hasMorePopularGames = true;
  int _popularOffset = 0;
  
  // Caché de los juegos del usuario (game_id -> nota)
  Map<int, double> _userGamesCache = {};

  @override
  void initState() {
    super.initState();
    _fetchUserGamesCache();
    _fetchPopularGames(isInitial: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_searchController.text.trim().isEmpty) {
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
      if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      } else {
        _performSearch(isInitial: true);
      }
    });
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
      final games = await IGDBService.searchGames(query, offset: _searchOffset);
      
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
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searchController.text.trim().isEmpty) {
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
