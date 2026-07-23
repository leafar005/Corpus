import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Añadido para kIsWeb
import '../env.dart';

class IGDBService {
  static String? _accessToken;

  // 1. Obtener el token de seguridad de Twitch (Autenticación)
  static Future<void> _authenticate() async {
    // Si ya tenemos la llave maestra, no la pedimos otra vez
    if (_accessToken != null) return; 

    final url = kIsWeb 
        ? 'https://corsproxy.io/?https://id.twitch.tv/oauth2/token?client_id=${Env.igdbClientId}&client_secret=${Env.igdbClientSecret}&grant_type=client_credentials'
        : 'https://id.twitch.tv/oauth2/token?client_id=${Env.igdbClientId}&client_secret=${Env.igdbClientSecret}&grant_type=client_credentials';

    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Error al autenticar con Twitch: ${response.body}');
    }
  }

  static Future<List<dynamic>> searchGames(
    String query, {
    int offset = 0,
    int limit = 35,
    String? sortBy,
    bool sortAscending = true,
    List<int>? genres,
    List<int>? themes,
    List<int>? gameModes,
    List<int>? playerPerspectives,
    List<int>? platforms,
    List<int>? categories,
  }) async {
    if (query.trim().isEmpty && genres == null && themes == null && gameModes == null && playerPerspectives == null && platforms == null && categories == null) return [];
    
    await _authenticate();

    final String url = kIsWeb 
        ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
        : 'https://api.igdb.com/v4/games';

    final String cleanQuery = query.trim();
    String whereConditions = 'cover != null';
    String sortClause = 'sort total_rating_count desc;';
    
    if (sortBy != null) {
      final direction = sortAscending ? 'asc' : 'desc';
      sortClause = 'sort $sortBy $direction;';
    }

    if (cleanQuery.isNotEmpty) {
      // Diccionario de conversión mutua entre números árabes y romanos (del 1 al 10)
      const romanMap = {
        '1': 'i', '2': 'ii', '3': 'iii', '4': 'iv', '5': 'v',
        '6': 'vi', '7': 'vii', '8': 'viii', '9': 'ix', '10': 'x',
        'i': '1', 'ii': '2', 'iii': '3', 'iv': '4', 'v': '5',
        'vi': '6', 'vii': '7', 'viii': '8', 'ix': '9', 'x': '10'
      };

      final words = cleanQuery.toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
      
      final wordConditions = words.map((w) {
        final romanEquivalent = romanMap[w];
        if (romanEquivalent != null) {
          // Si la palabra es un número (ej: "3"), buscamos tanto "3" como "iii" 
          // en el título oficial y en los títulos alternativos
          return '(name ~ *"$w"* | name ~ *"$romanEquivalent"* | alternative_names.name ~ *"$w"* | alternative_names.name ~ *"$romanEquivalent"*)';
        } else {
          // Si es una palabra normal (ej: "dark", "souls", "gta"), 
          // buscamos en el título oficial y en los alternativos
          return '(name ~ *"$w"* | alternative_names.name ~ *"$w"*)';
        }
      });

      whereConditions += ' & ${wordConditions.join(' & ')}';
    }
    
    if (genres != null && genres.isNotEmpty) {
      whereConditions += ' & genres = (${genres.join(',')})';
    }
    if (themes != null && themes.isNotEmpty) {
      whereConditions += ' & themes = (${themes.join(',')})';
    }
    if (gameModes != null && gameModes.isNotEmpty) {
      whereConditions += ' & game_modes = (${gameModes.join(',')})';
    }
    if (playerPerspectives != null && playerPerspectives.isNotEmpty) {
      whereConditions += ' & player_perspectives = (${playerPerspectives.join(',')})';
    }
    if (platforms != null && platforms.isNotEmpty) {
      whereConditions += ' & platforms = (${platforms.join(',')})';
    }
    if (categories != null && categories.isNotEmpty) {
      whereConditions += ' & game_type = (${categories.join(',')})';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $whereConditions; $sortClause limit $limit; offset $offset;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la lista de juegos en crudo
    } else {
      throw Exception('Error al buscar juegos: ${response.body}');
    }
  }

  // 3. Obtener los juegos más esperados o populares (Tendencias)
  static Future<List<dynamic>> getPopularGames({int offset = 0, int limit = 35}) async {
    await _authenticate();
    
    final String url = kIsWeb 
        ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
        : 'https://api.igdb.com/v4/games';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, franchises.name, game_engines.name; where cover != null & total_rating_count > 10; sort first_release_date desc; limit $limit; offset $offset;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener juegos populares: ${response.body}');
    }
  }

  // 4. Obtener un juego concreto por su ID de IGDB (para enriquecer datos que faltan)
  static Future<Map<String, dynamic>?> getGameById(int igdbId) async {
    await _authenticate();

    final String url = kIsWeb 
        ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
        : 'https://api.igdb.com/v4/games';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, franchises.name, game_engines.name; where id = $igdbId;',
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.isNotEmpty ? list[0] as Map<String, dynamic> : null;
    }
    return null;
  }

  // 5. Traductor: Convertir la ID de la imagen en un enlace URL real de internet
  static String getCoverUrl(String? imageId) {
    if (imageId == null) return '';
    // 't_cover_big' es un tamaño oficial de IGDB para móviles (alta resolución)
    return 'https://images.igdb.com/igdb/image/upload/t_cover_big/$imageId.jpg';
  }

  // 6. Obtener URL de una captura de pantalla a 1080p
  static String getScreenshotUrl(String? imageId) {
    if (imageId == null) return '';
    return 'https://images.igdb.com/igdb/image/upload/t_1080p/$imageId.jpg';
  }

  // 7. Obtener URL de un artwork a 1080p
  static String getArtworkUrl(String? imageId) {
    if (imageId == null) return '';
    return 'https://images.igdb.com/igdb/image/upload/t_1080p/$imageId.jpg';
  }

  // 8. Obtener URL de la miniatura de un vídeo de YouTube
  static String getVideoThumbnailUrl(String? videoId) {
    if (videoId == null) return '';
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  // 9. Obtener enlace directo a YouTube
  static String getVideoUrl(String? videoId) {
    if (videoId == null) return '';
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  // 10. Obtener tiempo de juego (HowLongToBeat)
  static Future<Map<String, dynamic>?> getTimeToBeat(int gameId) async {
    try {
      await _authenticate();
      final String url = kIsWeb 
          ? 'https://corsproxy.io/?https://api.igdb.com/v4/game_time_to_beats'
          : 'https://api.igdb.com/v4/game_time_to_beats';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Client-ID': Env.igdbClientId,
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: 'fields *; where game_id = $gameId; limit 1;',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data[0];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching time to beat: $e');
      }
      return null;
    }
  }


  // 11. Obtener contenido relacionado (DLCs, remakes, ports, etc.) de un juego
  static Future<List<dynamic>> getRelatedGames(int igdbId) async {
    try {
      await _authenticate();
      final String url = kIsWeb
          ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
          : 'https://api.igdb.com/v4/games';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Client-ID': Env.igdbClientId,
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: 'fields name, cover.image_id, first_release_date, game_type, genres.name, total_rating; where (parent_game = $igdbId) | (version_parent = $igdbId) | (bundles = $igdbId); sort first_release_date asc; limit 100;',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching related games: $e');
      return [];
    }
  }
  // 12. Obtener juegos de una Colección o Franquicia
  static Future<List<dynamic>> getGamesByCollection(int collectionId, {bool isFranchise = false}) async {
    try {
      await _authenticate();
      final String url = kIsWeb
          ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
          : 'https://api.igdb.com/v4/games';

      final String filterField = isFranchise ? 'franchises' : 'collection';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Client-ID': Env.igdbClientId,
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: 'fields name, cover.image_id, first_release_date, total_rating, category, game_type, parent_game, platforms.name, genres.name, themes.name, game_modes.name, player_perspectives.name, involved_companies.developer, involved_companies.company.name, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $filterField = ($collectionId) & cover != null; sort first_release_date asc; limit 50;',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching franchise/collection games: $e');
      return [];
    }
  }
}
