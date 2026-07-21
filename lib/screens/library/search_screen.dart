import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/igdb_service.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Esperamos 500ms después de que dejes de teclear para no saturar a Twitch con peticiones
    _debounce = Timer(const Duration(milliseconds: 500), () {
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

  Future<void> _addGameToLibrary(dynamic gameData) async {
    // 1. Extraemos los datos útiles que nos dio IGDB
    final igdbId = gameData['id'];
    final title = gameData['name'];
    final coverImageId = gameData['cover'] != null ? gameData['cover']['image_id'] : null;
    final coverUrl = IGDBService.getCoverUrl(coverImageId);
    
    // Convertimos la fecha (Unix timestamp numérico) a texto ISO 8601
    String? releaseDate;
    if (gameData['first_release_date'] != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(gameData['first_release_date'] * 1000);
      releaseDate = date.toIso8601String();
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // 2. Guardamos la "Ficha del Juego" en la tabla pública 'games'.
      // Upsert: Si alguien en el mundo ya había guardado el "Zelda", simplemente lo actualiza sin dar error.
      await Supabase.instance.client.from('games').upsert({
        'igdb_id': igdbId,
        'title': title,
        'cover_url': coverUrl,
        'release_date': releaseDate,
      });

      // 3. Creamos el vínculo de "Rafa posee este juego" en 'user_games'
      await Supabase.instance.client.from('user_games').upsert({
        'user_id': userId,
        'game_id': igdbId,
        'status': 'playing', // Por defecto lo ponemos en "Jugando"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡$title añadido a tu biblioteca!'), backgroundColor: Colors.green),
        );
        // Cerramos la ventana de búsqueda para que el usuario vuelva a su biblioteca
        Navigator.pop(context); 
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $error'), backgroundColor: Colors.red),
        );
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
          onTap: () => _addGameToLibrary(game), // <-- Guardar juego
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
                // Icono visual de "+" arriba a la derecha
                const Positioned(
                  top: 4, right: 4,
                  child: Icon(Icons.add_circle, color: Colors.deepPurpleAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
