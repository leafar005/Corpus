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

  static Future<List<dynamic>> searchGames(String query, {int offset = 0, int limit =35}) async {
    if (query.trim().isEmpty) return [];
    
    await _authenticate();

    final String url = kIsWeb 
        ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
        : 'https://api.igdb.com/v4/games';

    final words = query.trim().split(RegExp(r'\s+'));
    final whereConditions = words.map((w) => 'name ~ *"$w"*').join(' & ');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      // Dividimos la búsqueda por palabras para encontrar coincidencias parciales sin importar el orden o los guiones (ej. "half life" encuentra "Half-Life")
      body: 'fields name, cover.image_id, first_release_date, summary, category, parent_game, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id; where $whereConditions & cover != null; sort total_rating_count desc; limit $limit; offset $offset;',
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
      // Option B: Novedades Recientes (últimos lanzamientos populares)
      body: 'fields name, cover.image_id, first_release_date, summary, category, parent_game, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id; where cover != null & total_rating_count > 10; sort first_release_date desc; limit $limit; offset $offset;',
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
      body: 'fields name, cover.image_id, first_release_date, summary, category, parent_game, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id; where id = $igdbId;',
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
}
