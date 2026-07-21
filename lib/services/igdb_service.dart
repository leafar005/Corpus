import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';

class IGDBService {
  static String? _accessToken;

  // 1. Obtener el token de seguridad de Twitch (Autenticación)
  static Future<void> _authenticate() async {
    // Si ya tenemos la llave maestra, no la pedimos otra vez
    if (_accessToken != null) return; 

    final response = await http.post(
      Uri.parse(
        'https://id.twitch.tv/oauth2/token?client_id=${Env.igdbClientId}&client_secret=${Env.igdbClientSecret}&grant_type=client_credentials'
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Error al autenticar con Twitch: ${response.body}');
    }
  }

  static Future<List<dynamic>> searchGames(String query, {int offset = 0}) async {
    if (query.trim().isEmpty) return [];
    
    await _authenticate();

    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      // Usamos coincidencia parcial (substring) y ordenamos por popularidad
      // Esto soluciona el problema de que "zel" no encontraba cosas y asegura que los resultados sean siempre los más populares
      body: 'fields name, cover.image_id, first_release_date, summary, category, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name; where name ~ *"$query"* & cover != null; sort total_rating_count desc; limit 20; offset $offset;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la lista de juegos en crudo
    } else {
      throw Exception('Error al buscar juegos: ${response.body}');
    }
  }

  // 3. Obtener los juegos más esperados o populares (Tendencias)
  static Future<List<dynamic>> getPopularGames({int offset = 0}) async {
    await _authenticate();
    
    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      // Option B: Novedades Recientes (últimos lanzamientos populares)
      body: 'fields name, cover.image_id, first_release_date, summary, category, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name; where cover != null & total_rating_count > 10; sort first_release_date desc; limit 20; offset $offset;',
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

    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name; where id = $igdbId;',
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
}
