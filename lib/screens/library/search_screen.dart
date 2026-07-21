import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/igdb_service.dart';
import 'game_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  
  bool _isLoading = false;
  List<dynamic> _results = [];
  String _errorMessage = '';
  
  // Caché de los juegos del usuario (game_id -> nota)
  Map<int, double> _userGamesCache = {};

  @override
  void initState() {
    super.initState();
    _fetchUserGamesCache();
  }

  Future<void> _fetchUserGamesCache() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final response = await Supabase.instance.client
          .from('user_games')
          .select('game_id, rating')
          .eq('user_id', userId);
      
      if (mounted) {
        setState(() {
          _userGamesCache.clear();
          for (var row in response) {
            _userGamesCache[row['game_id'] as int] = (row['rating'] ?? 0).toDouble();
          }
        });
      }
    } catch (e) {
      // Si falla, simplemente no mostraremos las notas encima de las carátulas
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Lo bajamos a 300ms para que reaccione más rápido a las pulsaciones
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _errorMessage = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await IGDBService.searchGames(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Hubo un error al buscar el juego.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openGameDetails(dynamic gameData) async {
    // Traducción en tiempo real: Convertimos los datos "sucios" de IGDB al formato limpio de Supabase
    
    // Convertimos la fecha
    String? releaseDate;
    if (gameData['first_release_date'] != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(gameData['first_release_date'] * 1000);
      releaseDate = date.toIso8601String();
    }

    // Extraemos géneros
    List<String> genres = [];
    if (gameData['genres'] != null) {
      for (var genre in gameData['genres']) {
        if (genre['name'] != null) genres.add(genre['name']);
      }
    }

    // Extraemos plataformas
    List<String> platforms = [];
    if (gameData['platforms'] != null) {
      for (var platform in gameData['platforms']) {
        if (platform['name'] != null) platforms.add(platform['name']);
      }
    }

    // Extraemos desarrollador
    String? developer;
    if (gameData['involved_companies'] != null) {
      for (var company in gameData['involved_companies']) {
        if (company['developer'] == true && company['company'] != null) {
          developer = company['company']['name'];
          break;
        }
      }
    }

    // Creamos el diccionario con el mismo molde que usamos en Supabase
    final cleanData = {
      'igdb_id': gameData['id'],
      'title': gameData['name'],
      'cover_url': IGDBService.getCoverUrl(gameData['cover']?['image_id']),
      'release_date': releaseDate,
      'summary': gameData['summary'],
      'genres': genres,
      'platforms': platforms,
      'developer': developer,
    };

    // Viajamos a la Ficha del Juego
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailsScreen(gameData: cleanData),
      ),
    );

    // Cuando el usuario vuelva de la ficha, actualizamos la caché por si ha añadido o puntuado el juego
    _fetchUserGamesCache();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar juego (ej: Zelda)...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Empieza a escribir para buscar en el catálogo mundial...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150, // Anchura máxima ideal de cada carátula
        childAspectRatio: 0.7, 
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final game = _results[index];
        final coverImageId = game['cover'] != null ? game['cover']['image_id'] : null;
        final coverUrl = IGDBService.getCoverUrl(coverImageId);

        return InkWell(
          onTap: () => _openGameDetails(game), // <-- Abrir ficha traducida
          borderRadius: BorderRadius.circular(8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen de fondo (portada real)
                coverUrl.isNotEmpty
                    ? Image.network(coverUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.deepPurple.shade900,
                        child: const Center(child: Icon(Icons.videogame_asset, size: 40, color: Colors.white54)),
                      ),
                // Título con degradado oscuro abajo
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Text(
                      game['name'] ?? 'Desconocido',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Icono visual: Nota si lo tienes, o un tic si lo tienes pero sin nota
                if (_userGamesCache.containsKey(game['id']))
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        _userGamesCache[game['id']]! > 0 
                            ? _userGamesCache[game['id']]!.toStringAsFixed(1) 
                            : '✓',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
