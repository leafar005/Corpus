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

  // 2. Buscar juegos en el catálogo gigante de IGDB
  static Future<List<dynamic>> searchGames(String query) async {
    if (query.trim().isEmpty) return [];
    
    await _authenticate();

    // Le pedimos datos a IGDB usando su lenguaje llamado APICALYPSE
    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/games'),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      // Buscamos el texto. Pedimos (fields): nombre, id de portada, fecha. 
      // Exigimos (where) que tenga portada para que quede bonito. Límite: 20 resultados.
      // Ampliado en Fase 3: pedimos también sinopsis (summary), géneros, plataformas e info de desarrolladores
      body: 'search "$query"; fields name, cover.image_id, first_release_date, summary, genres.name, platforms.name, involved_companies.developer, involved_companies.company.name; where cover != null; limit 20;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la lista de juegos en crudo
    } else {
      throw Exception('Error al buscar juegos: ${response.body}');
    }
  }

  // 3. Traductor: Convertir la ID de la imagen en un enlace URL real de internet
  static String getCoverUrl(String? imageId) {
    if (imageId == null) return '';
    // 't_cover_big' es un tamaño oficial de IGDB para móviles (alta resolución)
    return 'https://images.igdb.com/igdb/image/upload/t_cover_big/$imageId.jpg';
  }
}
