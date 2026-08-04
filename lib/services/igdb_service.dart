import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:supabase_flutter/supabase_flutter.dart';

class IGDBService {
  // 1. Helper centralizado: Llama a la Edge Function igdb-proxy de Supabase.
  // Ya no hacemos fallback directo a la API de Twitch desde el cliente
  // porque expondría el Client Secret. Toda llamada pasa por el proxy.
  static Future<http.Response> _postQuery(String endpoint, String query) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('igdb-proxy', body: {'endpoint': endpoint, 'query': query})
          .timeout(const Duration(seconds: 15));
          
      if (res.status == 200 && res.data != null) {
        final bodyString = res.data is String ? res.data : jsonEncode(res.data);
        return http.Response.bytes(
          utf8.encode(bodyString),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } else {
        throw Exception('Error del proxy IGDB: status ${res.status}, data: ${res.data}');
      }
    } catch (e) {
      debugPrint('[IGDB Proxy] Error de conexión: $e');
      rethrow;
    }
  }

  /// Obtiene los juegos más anticipados ordenados por 'hype'
  static Future<List<dynamic>> getMostAnticipatedGames({int limit = 4}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Traemos nombre, fecha de lanzamiento, el arte de fondo y la carátula por si acaso
    final query =
        '''
      fields name, first_release_date, artworks.image_id, cover.image_id;
      where first_release_date > $now & hypes != null;
      sort hypes desc;
      limit $limit;
    ''';

    try {
      final response = await _postQuery('games', query);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        debugPrint('Error IGDB Anticipated: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception IGDB Anticipated: $e');
      return [];
    }
  }

  /// Obtiene juegos por ID que aún no han salido, ordenados por fecha de salida
  static Future<List<dynamic>> getUpcomingGamesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final nowSeconds = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final query =
        '''
      fields name, first_release_date, artworks.image_id, cover.image_id;
      where id = (${ids.join(',')}) & first_release_date > $nowSeconds;
      sort first_release_date asc;
    ''';

    try {
      final response = await _postQuery('games', query);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        debugPrint('Error IGDB Upcoming: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception IGDB Upcoming: $e');
      return [];
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

    final String cleanQuery = query.trim();
    String whereConditions = 'cover != null';
    String sortClause = 'sort total_rating_count desc;';

    if (sortBy != null) {
      final direction = sortAscending ? 'asc' : 'desc';
      sortClause = 'sort $sortBy $direction;';
    }

    // CORRECCIÓN NULLS FIRST: Solo aplicar cuando hay búsqueda de texto libre,
    // no en búsquedas por logros (compañía/saga) donde los juegos sin votos son válidos.
    final bool isTextSearch =
        cleanQuery.isNotEmpty &&
        involvedCompanies == null &&
        collections == null &&
        franchises == null;
    if (isTextSearch) {
      if (sortClause.contains('total_rating_count') &&
          sortClause.contains('desc')) {
        // Truco de IGDB: Si ordenamos por un campo, IGDB excluye automáticamente los nulos.
        // Añadiendo esta condición OR explícita evitamos que los excluya,
        // ordenando primero los populares y dejando los juegos indie sin votos (null) al final.
        whereConditions +=
            ' & (total_rating_count != null | total_rating_count = null)';
      } else if (sortClause.contains('rating') && sortClause.contains('desc')) {
        whereConditions += ' & (rating != null | rating = null)';
      } else if (sortClause.contains('aggregated_rating') &&
          sortClause.contains('desc')) {
        whereConditions +=
            ' & (aggregated_rating != null | aggregated_rating = null)';
      }
    }

    if (cleanQuery.isNotEmpty) {
      // Diccionario de conversión mutua entre números árabes y romanos (del 1 al 10)
      const romanMap = {
        '1': 'i',
        '2': 'ii',
        '3': 'iii',
        '4': 'iv',
        '5': 'v',
        '6': 'vi',
        '7': 'vii',
        '8': 'viii',
        '9': 'ix',
        '10': 'x',
        'i': '1',
        'ii': '2',
        'iii': '3',
        'iv': '4',
        'v': '5',
        'vi': '6',
        'vii': '7',
        'viii': '8',
        'ix': '9',
        'x': '10',
      };

      final words = cleanQuery
          .toLowerCase()
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();

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
      whereConditions +=
          ' & player_perspectives = (${playerPerspectives.join(',')})';
    }
    if (platforms != null && platforms.isNotEmpty) {
      whereConditions += ' & platforms = (${platforms.join(',')})';
    }
    if (categories != null && categories.isNotEmpty) {
      whereConditions += ' & game_type = (${categories.join(',')})';
    } else if (involvedCompanies != null ||
        collections != null ||
        franchises != null) {
      // Si estamos buscando por logro temático (estudio o saga), excluimos DLCs, mods, y hardware
      whereConditions += ' & game_type = (0, 8, 9, 10, 11)';
      // Y también excluimos juegos que aún no han salido
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      whereConditions += ' & first_release_date <= $now';
    }

    if (involvedCompanies != null && involvedCompanies.isNotEmpty) {
      whereConditions +=
          ' & involved_companies.company = (${involvedCompanies.join(',')})';
    }
    if (collections != null && collections.isNotEmpty) {
      final ids = collections.join(',');
      whereConditions += ' & ((collection = ($ids)) | (collections = ($ids)))';
    }
    if (franchises != null && franchises.isNotEmpty) {
      whereConditions += ' & franchises = (${franchises.join(',')})';
    }

    final response = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $whereConditions; $sortClause limit $limit; offset $offset;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la lista de juegos en crudo
    } else {
      throw Exception('Error al buscar juegos: ${response.body}');
    }
  }

  // 3. Obtener los juegos más esperados o populares (Tendencias)
  static Future<List<dynamic>> getPopularGames({
    int offset = 0,
    int limit = 35,
  }) async {
    final response = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, franchises.name, game_engines.name; where cover != null & total_rating_count > 10; sort first_release_date desc; limit $limit; offset $offset;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener juegos populares: ${response.body}');
    }
  }

  // 4. Obtener un juego concreto por su ID de IGDB (para enriquecer datos que faltan)
  static Future<Map<String, dynamic>?> getGameById(int igdbId) async {
    final response = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, version_parent, remakes, remasters, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, collection.id, franchise.id, franchise.name, franchises.id, franchises.name, game_engines.name, websites.url, websites.category, websites.type, aggregated_rating; where id = $igdbId;',
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
    final idsString = igdbIds.join(',');
    final response = await _postQuery(
      'games',
      'fields name, screenshots.image_id; where id = ($idsString); limit 50;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  // Cache del ID de "Steam" en external_game_sources (no cambia, se resuelve una sola vez por sesión)
  static int? _steamSourceId;

  static Future<int?> _getSteamSourceId() async {
    if (_steamSourceId != null) return _steamSourceId;
    try {
      final response = await _postQuery(
        'external_game_sources',
        'fields id, name; limit 50;',
      );
      if (response.statusCode == 200) {
        final List<dynamic> sources = jsonDecode(response.body);
        final steamSource = sources.firstWhere(
          (s) => (s['name'] as String?)?.toLowerCase() == 'steam',
          orElse: () => null,
        );
        if (steamSource != null) {
          _steamSourceId = steamSource['id'] as int;
        }
      }
    } catch (e) {
      if (kDebugMode) print('[IGDB] Error resolviendo Steam source ID: $e');
    }
    return _steamSourceId;
  }

  /// Convierte un único Steam App ID en la ficha de IGDB.
  static Future<Map<String, dynamic>?> getGameBySteamId(int steamAppId) async {
    try {
      final steamSourceId = await _getSteamSourceId();
      final sourceFilter = steamSourceId != null
          ? 'external_game_source = $steamSourceId'
          : 'category = 1';
      final response = await _postQuery(
        'external_games',
        'fields game; where $sourceFilter & uid = "$steamAppId"; limit 1;',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data.first['game'] != null) {
          final int igdbId = data.first['game'] is Map
              ? data.first['game']['id']
              : data.first['game'];
          return await getGameById(igdbId);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[IGDB ERROR] Fallo al convertir SteamID $steamAppId: $e');
      }
      return null;
    }
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
      final response = await _postQuery(
        'game_time_to_beats',
        'fields *; where game_id = $gameId; limit 1;',
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
      final response = await _postQuery(
        'games',
        'fields name, cover.image_id, first_release_date, game_type, genres.name, total_rating; where (parent_game = $igdbId) | (version_parent = $igdbId) | (bundles = $igdbId); sort first_release_date asc; limit 100;',
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
    int?
    collectionId2, // ID alternativo (colección Y franquicia para el mismo logro)
    int? franchiseId2,
    int offset = 0,
    int limit = 35,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Construir la condición principal del logro (compañía OR saga)
      List<String> mainConditions = [];
      if (companyId != null) {
        if ([
          37,
          129,
          1012,
          26,
          56,
          305,
          401,
          908,
          170,
          769,
        ].contains(companyId)) {
          mainConditions.add(
            '(involved_companies.company = ($companyId) & involved_companies.developer = true)',
          );
        } else {
          mainConditions.add('involved_companies.company = ($companyId)');
        }
      }
      if (collectionId != null && franchiseId != null) {
        // Si tenemos AMBOS (colección Y franquicia del mismo logro), los unimos con OR
        mainConditions.add(
          '((collection = ($collectionId)) | (collections = ($collectionId)) | (franchise = $franchiseId) | (franchises = ($franchiseId)))',
        );
      } else {
        if (collectionId != null) {
          mainConditions.add(
            '((collection = ($collectionId)) | (collections = ($collectionId)))',
          );
        }
        if (franchiseId != null) {
          mainConditions.add(
            '(franchise = $franchiseId | franchises = ($franchiseId))',
          );
        }
      }
      if (collectionId2 != null) {
        mainConditions.add(
          '((collection = ($collectionId2)) | (collections = ($collectionId2)))',
        );
      }
      if (franchiseId2 != null) {
        mainConditions.add(
          '(franchise = $franchiseId2 | franchises = ($franchiseId2))',
        );
      }

      if (mainConditions.isEmpty) return [];

      // OR entre todas las condiciones principales, AND con los filtros globales
      final mainWhere = mainConditions.length == 1
          ? mainConditions.first
          : '(${mainConditions.join(' | ')})';

      final body =
          'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $mainWhere & cover != null & game_type = (0, 8, 9, 10, 11) & first_release_date <= $now; sort total_rating_count desc; limit $limit; offset $offset;';

      final response = await _postQuery('games', body);

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
  static Future<List<dynamic>> getGamesByCollection(
    int collectionId, {
    bool isFranchise = false,
  }) async {
    try {
      // IGDB tiene dos campos de franquicia:
      // - 'franchise' (singular, campo legacy usado en juegos anteriores a ~2015)
      // - 'franchises' (plural array, campo moderno)
      // Hay que consultar ambos para no perder juegos como Mario Kart 7, 8, DS, etc.
      final String filterCondition = isFranchise
          ? '(franchise = $collectionId | franchises = ($collectionId))'
          : '((collection = ($collectionId)) | (collections = ($collectionId)))';

      final response = await _postQuery(
        'games',
        'fields name, cover.image_id, first_release_date, total_rating, category, game_type, parent_game, platforms.name, genres.name, themes.name, game_modes.name, player_perspectives.name, involved_companies.developer, involved_companies.company.name, collection.id, collection.name, franchises.id, franchises.name, game_engines.name; where $filterCondition & cover != null; sort first_release_date asc; limit 50;',
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

  /// Decodifica entidades HTML (&amp;, &#039;, &quot;, etc.) que a veces
  /// vienen crudas desde fuentes externas como barter.vg
  static String decodeHtmlEntities(String text) {
    return parse(text).body?.text ?? text;
  }

  /// Búsqueda "permisiva" pensada para resolver títulos de bundles/DLCs
  /// que no tienen cover propia ni rating en IGDB, pero sí existen.
  static Future<List<dynamic>> searchGameLenient(String rawQuery) async {
    final query = decodeHtmlEntities(rawQuery).trim();
    if (query.isEmpty) return [];

    final words = query
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final wordConditions = words
        .map((w) => '(name ~ *"$w"* | alternative_names.name ~ *"$w"*)')
        .join(' & ');

    // Sin exigir cover != null ni total_rating_count != null.
    // Ordenamos por total_rating_count desc pero sin filtrarlo.
    final response = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, category, game_type, parent_game, genres.name, platforms.name; where $wordConditions; sort total_rating_count desc; limit 5;',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }

    return [];
  }

  /// Consulta masiva en lotes a IGDB usando Steam App IDs con reporte de progreso.
  static Future<Map<String, Map<String, dynamic>>> getGamesBySteamIds(
    List<int> steamAppIds, {
    Function(int processed, int total, String step)? onProgress,
  }) async {
    if (steamAppIds.isEmpty) return {};

    final steamSourceId = await _getSteamSourceId();
    final sourceFilter = steamSourceId != null
        ? 'external_game_source = $steamSourceId'
        : 'category = 1'; // fallback deprecado, solo si no se pudo resolver el ID dinámico

    final Map<int, int> steamIdToIgdbId = {};
    const chunkSize = 50;

    for (var i = 0; i < steamAppIds.length; i += chunkSize) {
      final chunk = steamAppIds.skip(i).take(chunkSize).toList();
      final orConditions = chunk.map((id) => 'uid = "$id"').join(' | ');
      // OJO: no limitar a chunk.length. Un mismo Steam AppID puede tener
      // varias filas en external_games (duplicados, distintas categorías),
      // así que con limit = chunk.length algunos juegos del lote se quedan
      // fuera de la respuesta sin ningún error. 500 es el máximo por petición.
      final body =
          'fields uid, game; where $sourceFilter & ($orConditions); limit 500;';

      try {
        final response = await _postQuery('external_games', body);

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          for (final entry in data) {
            final uidStr = entry['uid']?.toString();
            final uid = int.tryParse(uidStr ?? '');
            final rawGame = entry['game'];
            final gameId = rawGame is Map ? rawGame['id'] : rawGame;

            if (uid != null && gameId != null) {
              steamIdToIgdbId[uid] = gameId is int
                  ? gameId
                  : int.parse(gameId.toString());
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('[IGDB BATCH ERROR] Chunk $i: $e');
      }

      // Notificamos el progreso a la barra (del 0% al 100% de esta fase)
      if (onProgress != null) {
        final current = (i + chunk.length < steamAppIds.length)
            ? i + chunk.length
            : steamAppIds.length;
        onProgress(
          current,
          steamAppIds.length,
          'Identificando juegos en IGDB ($current de ${steamAppIds.length})...',
        );
      }
    }

    if (steamIdToIgdbId.isEmpty) return {};

    if (onProgress != null) {
      onProgress(
        steamAppIds.length,
        steamAppIds.length,
        'Descargando portadas en alta resolución...',
      );
    }

    final igdbIds = steamIdToIgdbId.values.toSet().toList();
    final games = await getGamesByIdsFull(igdbIds);

    final Map<int, Map<String, dynamic>> gamesById = {
      for (final g in games)
        (g['id'] as num).toInt(): g as Map<String, dynamic>,
    };

    final Map<String, Map<String, dynamic>> result = {};
    steamIdToIgdbId.forEach((steamId, igdbId) {
      final game = gamesById[igdbId];
      if (game != null) result['steam:$steamId'] = game;
    });

    return result;
  }

  /// Datos completos (con cover, para GameCard) de una lista de IGDB IDs,
  /// en lotes para no exceder los límites de IGDB.
  static Future<List<dynamic>> getGamesByIdsFull(List<int> igdbIds) async {
    if (igdbIds.isEmpty) return [];

    final List<dynamic> allResults = [];
    const chunkSize = 200;

    for (var i = 0; i < igdbIds.length; i += chunkSize) {
      final chunk = igdbIds.skip(i).take(chunkSize).toList();
      final idsString = chunk.join(',');
      final body =
          'fields name, cover.image_id, first_release_date, category, game_type, parent_game, genres.name, platforms.name; where id = ($idsString); limit ${chunk.length};';

      final response = await _postQuery('games', body);

      if (kDebugMode) {
        print('[IGDB BATCH getGamesByIdsFull] status=${response.statusCode}');
        if (response.statusCode != 200) {
          print(
            '[IGDB BATCH getGamesByIdsFull] Error response: ${response.body}',
          );
        }
      }

      if (response.statusCode == 200) {
        allResults.addAll(jsonDecode(response.body) as List);
      }
    }

    return allResults;
  }
}
