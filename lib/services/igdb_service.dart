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

    final words = query.trim().split(RegExp(r'\s+'));
    String whereConditions = 'cover != null';
    
    if (query.trim().isNotEmpty) {
      whereConditions += ' & ${words.map((w) => 'name ~ *"$w"*').join(' & ')}';
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

    String sortClause = 'sort total_rating_count desc';
    if (sortBy != null) {
      final direction = sortAscending ? 'asc' : 'desc';
      sortClause = 'sort $sortBy $direction';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, franchises.name, game_engines.name; where $whereConditions; $sortClause; limit $limit; offset $offset;',
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
}
