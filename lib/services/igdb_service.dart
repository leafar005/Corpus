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
    List<int>? involvedCompanies,
    List<int>? collections,
    List<int>? franchises,
  }) async {
    await _authenticate();

    if (query.trim().isEmpty &&
        genres == null &&
        themes == null &&
        gameModes == null &&
        playerPerspectives == null &&
        platforms == null &&
        categories == null &&
        involvedCompanies == null &&
        collections == null &&
        franchises == null) {
      return [];
    }
    
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

    // CORRECCIÓN NULLS FIRST: Solo aplicar cuando hay búsqueda de texto libre,
    // no en búsquedas por logros (compañía/saga) donde los juegos sin votos son válidos.
    final bool isTextSearch = cleanQuery.isNotEmpty && involvedCompanies == null && collections == null && franchises == null;
    if (isTextSearch) {
      if (sortClause.contains('total_rating_count') && sortClause.contains('desc')) {
        whereConditions += ' & total_rating_count != null';
      } else if (sortClause.contains('rating') && sortClause.contains('desc')) {
        whereConditions += ' & rating != null';
      }
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
          return '(name ~ *"$w"* | name ~ *"$romanEquivalent"* | alternative_names.name ~ *"$w"* | alternative_names.name ~ *"$romanEquivalent"*)';
        } else {
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
    } else if (involvedCompanies != null || collections != null || franchises != null) {
      // Si estamos buscando por logro temático (estudio o saga), excluimos DLCs, mods, y hardware
      whereConditions += ' & game_type = (0, 8, 9, 10, 11)';
      // Y también excluimos juegos que aún no han salido
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      whereConditions += ' & first_release_date <= $now';
    }

    if (involvedCompanies != null && involvedCompanies.isNotEmpty) {
      whereConditions += ' & involved_companies.company = (${involvedCompanies.join(',')})';
    }
    if (collections != null && collections.isNotEmpty) {
      final ids = collections.join(',');
      whereConditions += ' & ((collection = ($ids)) | (collections = ($ids)))';
    }
    if (franchises != null && franchises.isNotEmpty) {
      whereConditions += ' & franchises = (${franchises.join(',')})';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $whereConditions; $sortClause limit $limit; offset $offset;',
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

  // 4b. Obtener varios juegos por sus IDs de IGDB en una sola consulta
  static Future<List<dynamic>> getGamesByIds(List<int> igdbIds) async {
    if (igdbIds.isEmpty) return [];
    await _authenticate();

    final String url = kIsWeb 
        ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
        : 'https://api.igdb.com/v4/games';

    final idsString = igdbIds.join(',');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Client-ID': Env.igdbClientId,
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      },
      body: 'fields name, screenshots.image_id; where id = ($idsString); limit 50;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
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

  // 12. Obtener juegos de una Colección, Franquicia o Compañía para la pantalla de logros
  // Usa paginación para cargar todos los juegos disponibles.
  // Ordena: primero por popularidad (total_rating_count desc).
  // Filtra: solo juegos base/remakes/remasters/ports/expansiones ya lanzados.
  static Future<List<dynamic>> getAchievementGames({
    int? companyId,
    int? collectionId,
    int? franchiseId,
    int? collectionId2, // ID alternativo (colección Y franquicia para el mismo logro)
    int? franchiseId2,
    int offset = 0,
    int limit = 35,
  }) async {
    try {
      await _authenticate();
      final String url = kIsWeb
          ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
          : 'https://api.igdb.com/v4/games';

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Construir la condición principal del logro (compañía OR saga)
      List<String> mainConditions = [];
      if (companyId != null) {
        if ([37, 129, 1012, 26, 56, 305, 401, 908, 170, 769].contains(companyId)) {
          mainConditions.add('(involved_companies.company = ($companyId) & involved_companies.developer = true)');
        } else {
          mainConditions.add('involved_companies.company = ($companyId)');
        }
      }
      if (collectionId != null && franchiseId != null) {
        // Si tenemos AMBOS (colección Y franquicia del mismo logro), los unimos con OR
        mainConditions.add('((collection = ($collectionId)) | (collections = ($collectionId)) | (franchises = ($franchiseId)))');
      } else {
        if (collectionId != null) {
          mainConditions.add('((collection = ($collectionId)) | (collections = ($collectionId)))');
        }
        if (franchiseId != null) {
          mainConditions.add('franchises = ($franchiseId)');
        }
      }
      if (collectionId2 != null) {
        mainConditions.add('((collection = ($collectionId2)) | (collections = ($collectionId2)))');
      }
      if (franchiseId2 != null) {
        mainConditions.add('franchises = ($franchiseId2)');
      }

      if (mainConditions.isEmpty) return [];

      // OR entre todas las condiciones principales, AND con los filtros globales
      final mainWhere = mainConditions.length == 1
          ? mainConditions.first
          : '(${mainConditions.join(' | ')})';

      final body = 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $mainWhere & cover != null & game_type = (0, 8, 9, 10, 11) & first_release_date <= $now; sort total_rating_count desc; limit $limit; offset $offset;';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Client-ID': Env.igdbClientId,
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching achievement games: $e');
      return [];
    }
  }

  // 13. Obtener juegos de una Colección o Franquicia (método legacy)
  static Future<List<dynamic>> getGamesByCollection(int collectionId, {bool isFranchise = false}) async {
    try {
      await _authenticate();
      final String url = kIsWeb
          ? 'https://corsproxy.io/?https://api.igdb.com/v4/games'
          : 'https://api.igdb.com/v4/games';

      final String filterCondition = isFranchise 
          ? 'franchises = ($collectionId)' 
          : '((collection = ($collectionId)) | (collections = ($collectionId)))';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Client-ID': Env.igdbClientId,
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
        body: 'fields name, cover.image_id, first_release_date, total_rating, category, game_type, parent_game, platforms.name, genres.name, themes.name, game_modes.name, player_perspectives.name, involved_companies.developer, involved_companies.company.name, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $filterCondition & cover != null; sort first_release_date asc; limit 50;',
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
