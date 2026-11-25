import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/utils/achievement_utils.dart';
import 'package:corpus/utils/corpus_logger.dart';
import 'package:corpus/utils/isolate_runner.dart';

class IGDBService {
  static final _log = CorpusLogger('IGDBService');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');
  static final RegExp _decimalEntityRegex = RegExp(r'&#(\d+);');
  static final RegExp _hexEntityRegex = RegExp(r'&#x([a-fA-F0-9]+);');
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _maxCacheEntries = 150;
  static final LinkedHashMap<String, ({DateTime expiresAt, dynamic data})>
      _queryCache = LinkedHashMap<String, ({DateTime expiresAt, dynamic data})>();
  static final Map<String, Future<dynamic>> _inFlightQueries = {};

  /// Limpia la caché LRU en memoria y las consultas en curso.
  static void clearCache() {
    _queryCache.clear();
    _inFlightQueries.clear();
  }

  /// Cuantiza un epoch UNIX en segundos al bucket [bucketSeconds] (5 min por defecto)
  /// para maximizar aciertos de caché entre consultas recientes.
  @visibleForTesting
  static int quantizeUnixTimestamp(int epochSeconds, [int bucketSeconds = 300]) {
    if (bucketSeconds <= 1) return epochSeconds;
    return (epochSeconds ~/ bucketSeconds) * bucketSeconds;
  }

  static int _quantizedNowUnix([int bucketSeconds = 300]) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return quantizeUnixTimestamp(nowSeconds, bucketSeconds);
  }

  /// Devuelve la cláusula `where` auxiliar para no excluir nulos al ordenar en IGDB.
  @visibleForTesting
  static String nullOrderWorkaroundForSort(String sortClause) {
    final lower = sortClause.toLowerCase();
    if (!RegExp(r'\bdesc\b').hasMatch(lower)) return '';

    if (RegExp(r'\btotal_rating_count\b').hasMatch(lower)) {
      return ' & (total_rating_count != null | total_rating_count = null)';
    }
    if (RegExp(r'\baggregated_rating\b').hasMatch(lower)) {
      return ' & (aggregated_rating != null | aggregated_rating = null)';
    }
    if (RegExp(r'\brating\b').hasMatch(lower)) {
      return ' & (rating != null | rating = null)';
    }
    return '';
  }

  /// Sanitiza términos libres antes de interpolarlos en expresiones Apicalypse.
  static String sanitizeApicalypseTerm(String term) {
    return term
        .replaceAll(r'\', '')
        .replaceAll('"', '')
        .replaceAll(';', '')
        .trim();
  }

  static dynamic _cloneCached(dynamic data) {
    if (data is List) {
      return List<dynamic>.from(data);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return data;
  }

  // 1. Helper centralizado: Llama a la Edge Function igdb-proxy de Supabase.
  // Cachea datos ya decodificados en memoria (LRU + in-flight dedup) y reintenta HTTP 429.
  static Future<dynamic> _postQuery(String endpoint, String query) async {
    final cacheKey = '$endpoint::$query';
    final now = DateTime.now();

    final cached = _queryCache[cacheKey];
    if (cached != null) {
      if (now.isBefore(cached.expiresAt)) {
        _queryCache.remove(cacheKey);
        _queryCache[cacheKey] = cached;
        return _cloneCached(cached.data);
      }
      _queryCache.remove(cacheKey);
    }

    final existingFuture = _inFlightQueries[cacheKey];
    if (existingFuture != null) {
      return _cloneCached(await existingFuture);
    }

    late final Future<dynamic> future;
    future = () async {
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          final res = await Supabase.instance.client.functions
              .invoke('igdb-proxy', body: {'endpoint': endpoint, 'query': query})
              .timeout(const Duration(seconds: 15));

          if (res.status == 429 && attempt < 2) {
            final delayMs = attempt == 0 ? 400 : 900;
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            continue;
          }

          if (res.status == 200 && res.data != null) {
            final dynamic raw = res.data;
            final dynamic decoded;
            if (raw is String) {
              decoded = raw.length > 10000
                  ? await runInBackgroundIsolate(() => jsonDecode(raw))
                  : jsonDecode(raw);
            } else {
              decoded = raw;
            }
            _queryCache.remove(cacheKey);
            _queryCache[cacheKey] = (
              expiresAt: DateTime.now().add(_cacheTtl),
              data: decoded,
            );
            while (_queryCache.length > _maxCacheEntries) {
              _queryCache.remove(_queryCache.keys.first);
            }
            return _cloneCached(decoded);
          }

          throw Exception(
            'Error del proxy IGDB: status ${res.status}, data: ${res.data}',
          );
        }
      } catch (e) {
        debugPrint('[IGDB Proxy] Error de conexión: $e');
        rethrow;
      }
    }().whenComplete(() {
      if (identical(_inFlightQueries[cacheKey], future)) {
        _inFlightQueries.remove(cacheKey);
      }
    });

    _inFlightQueries[cacheKey] = future;
    return future;
  }

  /// Obtiene los juegos más anticipados ordenados por 'hype'
  static Future<List<dynamic>> getMostAnticipatedGames({int limit = 4}) async {
    final now = _quantizedNowUnix();

    // Traemos nombre, fecha de lanzamiento, el arte de fondo y la carátula por si acaso
    final query =
        '''
      fields name, first_release_date, summary, artworks.image_id, cover.image_id, genres.name, platforms.name;
      where first_release_date > $now & hypes != null;
      sort hypes desc;
      limit $limit;
    ''';

    try {
      final data = await _postQuery('games', query);
      return data is List ? List<dynamic>.from(data) : <dynamic>[];
    } catch (e) {
      debugPrint('Exception IGDB Anticipated: $e');
      return [];
    }
  }

  /// Obtiene juegos por ID que aún no han salido, ordenados por fecha de salida
  static Future<List<dynamic>> getUpcomingGamesByIds(List<int> ids) async {
    final uniqueIds = ids.where((id) => id > 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    final nowSeconds = _quantizedNowUnix();
    const chunkSize = 500;
    final allResults = <dynamic>[];

    try {
      for (var i = 0; i < uniqueIds.length; i += chunkSize) {
        final chunk = uniqueIds.skip(i).take(chunkSize).toList();
        final query =
            '''
      fields name, first_release_date, summary, artworks.image_id, cover.image_id, genres.name, platforms.name;
      where id = (${chunk.join(',')}) & first_release_date > $nowSeconds;
      sort first_release_date asc;
      limit ${chunk.length};
    ''';
        final data = await _postQuery('games', query);
        if (data is List) {
          allResults.addAll(data);
        }
      }
      if (uniqueIds.length > chunkSize && allResults.length > 1) {
        allResults.sort((a, b) {
          final da = (a is Map ? (a['first_release_date'] as num?)?.toInt() : null) ?? 0;
          final db = (b is Map ? (b['first_release_date'] as num?)?.toInt() : null) ?? 0;
          return da.compareTo(db);
        });
      }
      return allResults;
    } catch (e) {
      debugPrint('Exception IGDB Upcoming: $e');
      return allResults;
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
      whereConditions += nullOrderWorkaroundForSort(sortClause);
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
          .split(_whitespaceRegex)
          .map(sanitizeApicalypseTerm)
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isNotEmpty) {
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
      final now = _quantizedNowUnix();
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

    final data = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, collections.id, collections.name, franchises.id, franchises.name, game_engines.name; where $whereConditions; $sortClause limit $limit; offset $offset;',
    );

    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  // 3. Obtener los juegos más esperados o populares (Tendencias)
  static Future<List<dynamic>> getPopularGames({
    int offset = 0,
    int limit = 35,
  }) async {
    final now = _quantizedNowUnix();
    final data = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, collections.name, franchises.name, game_engines.name; where cover != null & total_rating_count > 10 & first_release_date <= $now; sort first_release_date desc; limit $limit; offset $offset;',
    );

    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  // 4. Obtener un juego concreto por su ID de IGDB (para enriquecer datos que faltan)
  static Future<Map<String, dynamic>?> getGameById(int igdbId) async {
    final data = await _postQuery(
      'games',
      'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, version_parent, remakes, remasters, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.name, collection.id, collections.name, collections.id, franchise.id, franchise.name, franchises.id, franchises.name, game_engines.name, url, websites.url, websites.category, websites.type, aggregated_rating; where id = $igdbId;',
    );

    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  // 4b. Obtener varios juegos por sus IDs de IGDB en lotes acotados
  static Future<List<dynamic>> getGamesByIds(List<int> igdbIds) async {
    final uniqueIds = igdbIds.where((id) => id > 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    const chunkSize = 200;
    final allResults = <dynamic>[];
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final chunk = uniqueIds.skip(i).take(chunkSize).toList();
      final idsString = chunk.join(',');
      final data = await _postQuery(
        'games',
        'fields name, screenshots.image_id; where id = ($idsString); limit ${chunk.length};',
      );
      if (data is List) {
        allResults.addAll(data);
      }
    }
    return allResults;
  }

  // Cache del ID de "Steam" en external_game_sources (no cambia, se resuelve una sola vez por sesión)
  static int? _steamSourceId;

  static Future<int?> _getSteamSourceId() async {
    if (_steamSourceId != null) return _steamSourceId;
    try {
      final data = await _postQuery(
        'external_game_sources',
        'fields id, name; limit 50;',
      );
      if (data is List) {
        final steamSource = data.firstWhere(
          (s) => s is Map && (s['name'] as String?)?.toLowerCase() == 'steam',
          orElse: () => null,
        );
        if (steamSource is Map && steamSource['id'] is num) {
          _steamSourceId = (steamSource['id'] as num).toInt();
        }
      }
    } catch (e) {
      _log.warning('Error resolviendo Steam source ID: $e');
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
      final data = await _postQuery(
        'external_games',
        'fields game; where $sourceFilter & uid = "$steamAppId"; limit 1;',
      );

      if (data is List && data.isNotEmpty && data.first is Map) {
        final rawGame = (data.first as Map)['game'];
        final igdbId = rawGame is Map
            ? (rawGame['id'] as num?)?.toInt()
            : (rawGame is num
                  ? rawGame.toInt()
                  : int.tryParse(rawGame?.toString() ?? ''));
        if (igdbId != null && igdbId > 0) {
          return await getGameById(igdbId);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IGDB ERROR] Fallo al convertir SteamID $steamAppId: $e');
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
      final data = await _postQuery(
        'game_time_to_beats',
        'fields *; where game_id = $gameId; limit 1;',
      );

      if (data is List && data.isNotEmpty && data.first is Map) {
        return Map<String, dynamic>.from(data.first as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching time to beat: $e');
      }
      return null;
    }
  }

  // 11. Obtener contenido relacionado (DLCs, remakes, ports, etc.) de un juego
  static Future<List<dynamic>> getRelatedGames(int igdbId) async {
    try {
      final data = await _postQuery(
        'games',
        'fields name, cover.image_id, first_release_date, game_type, genres.name, total_rating; where (parent_game = $igdbId) | (version_parent = $igdbId) | (bundles = $igdbId); sort first_release_date asc; limit 100;',
      );

      return data is List ? List<dynamic>.from(data) : <dynamic>[];
    } catch (e) {
      _log.warning('Error fetching related games: $e');
      return [];
    }
  }

  // 12. Obtener juegos de una Colección, Franquicia o Compañía para la pantalla de logros
  // Usa paginación para cargar todos los juegos disponibles.
  // Ordena: primero por popularidad (total_rating_count desc).
  // Filtra: solo juegos base/remakes/remasters/ports/expansiones ya lanzados.
  static Future<List<dynamic>> getAchievementGames({
    int? companyId,
    bool asPublisher = false,
    int? collectionId,
    int? franchiseId,
    int?
    collectionId2, // ID alternativo (colección Y franquicia para el mismo logro)
    int? franchiseId2,
    int offset = 0,
    int limit = 35,
  }) async {
    try {
      final now = _quantizedNowUnix();

      // Construir la condición principal del logro (compañía OR saga)
      List<String> mainConditions = [];
      if (companyId != null) {
        if (asPublisher) {
          // Vista "Publisher": queremos los juegos que esta compañía publicó,
          // sin la restricción especial de developer=true de más abajo (que
          // existe para logros de estudio, no para explorar catálogo editorial).
          mainConditions.add(
            '(involved_companies.company = ($companyId) & involved_companies.publisher = true)',
          );
        } else if (AchievementUtils.developerOnlyCompanyIds.contains(
          companyId,
        )) {
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
          'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, collections.id, collections.name, franchises.id, franchises.name, game_engines.name; where $mainWhere & cover != null & game_type = (0, 8, 9, 10, 11) & first_release_date <= $now; sort total_rating_count desc; limit $limit; offset $offset;';

      final data = await _postQuery('games', body);
      return data is List ? List<dynamic>.from(data) : <dynamic>[];
    } catch (e) {
      _log.warning('Error fetching achievement games: $e');
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

      final data = await _postQuery(
        'games',
        'fields name, cover.image_id, first_release_date, total_rating, category, game_type, parent_game, platforms.name, genres.name, themes.name, game_modes.name, player_perspectives.name, involved_companies.developer, involved_companies.publisher, involved_companies.company.name, collection.id, collection.name, collections.id, collections.name, franchises.id, franchises.name, game_engines.name; where $filterCondition & cover != null; sort first_release_date asc; limit 50;',
      );

      return data is List ? List<dynamic>.from(data) : <dynamic>[];
    } catch (e) {
      _log.warning('Error fetching franchise/collection games: $e');
      return [];
    }
  }

  /// Decodifica entidades HTML (&amp;, &#039;, &quot;, etc.) que a veces
  /// vienen crudas desde fuentes externas como barter.vg
  static String decodeHtmlEntities(String text) {
    String decoded = text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    decoded = decoded.replaceAllMapped(_decimalEntityRegex, (match) {
      final codePoint = int.tryParse(match.group(1)!);
      return codePoint != null
          ? String.fromCharCode(codePoint)
          : match.group(0)!;
    });
    decoded = decoded.replaceAllMapped(_hexEntityRegex, (match) {
      final codePoint = int.tryParse(match.group(1)!, radix: 16);
      return codePoint != null
          ? String.fromCharCode(codePoint)
          : match.group(0)!;
    });
    return decoded;
  }

  /// Construye la query Apicalypse sanitizada para [searchGameLenient].
  /// Devuelve `null` si no quedan términos válidos tras sanitizar.
  @visibleForTesting
  static String? buildLenientSearchQuery(String rawQuery) {
    final query = decodeHtmlEntities(rawQuery).trim();
    if (query.isEmpty) return null;

    final words = query
        .toLowerCase()
        .split(_whitespaceRegex)
        .map(sanitizeApicalypseTerm)
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    final wordConditions = words
        .map((w) => '(name ~ *"$w"* | alternative_names.name ~ *"$w"*)')
        .join(' & ');

    // Sin exigir cover != null; la disyunción mantiene juegos sin votos cuando
    // ordenamos por total_rating_count desc.
    return 'fields name, cover.image_id, first_release_date, category, '
        'game_type, parent_game, genres.name, platforms.name, url; '
        'where ($wordConditions) & (total_rating_count != null | total_rating_count = null); '
        'sort total_rating_count desc; limit 5;';
  }

  /// Búsqueda "permisiva" pensada para resolver títulos de bundles/DLCs
  /// que no tienen cover propia ni rating en IGDB, pero sí existen.
  static Future<List<dynamic>> searchGameLenient(String rawQuery) async {
    final body = buildLenientSearchQuery(rawQuery);
    if (body == null) return [];

    final data = await _postQuery('games', body);
    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  /// Consulta masiva en lotes a IGDB usando Steam App IDs con reporte de progreso.
  static Future<Map<String, Map<String, dynamic>>> getGamesBySteamIds(
    List<int> steamAppIds, {
    Function(int processed, int total, String step)? onProgress,
  }) async {
    final uniqueSteamIds = steamAppIds.where((id) => id > 0).toSet().toList();
    if (uniqueSteamIds.isEmpty) return {};

    final steamSourceId = await _getSteamSourceId();
    final sourceFilter = steamSourceId != null
        ? 'external_game_source = $steamSourceId'
        : 'category = 1'; // fallback deprecado, solo si no se pudo resolver el ID dinámico

    final Map<int, int> steamIdToIgdbId = {};
    const chunkSize = 50;

    for (var i = 0; i < uniqueSteamIds.length; i += chunkSize) {
      final chunk = uniqueSteamIds.skip(i).take(chunkSize).toList();
      final orConditions = chunk.map((id) => 'uid = "$id"').join(' | ');
      // OJO: no limitar a chunk.length. Un mismo Steam AppID puede tener
      // varias filas en external_games (duplicados, distintas categorías),
      // así que con limit = chunk.length algunos juegos del lote se quedan
      // fuera de la respuesta sin ningún error. 500 es el máximo por petición.
      final body =
          'fields uid, game; where $sourceFilter & ($orConditions); limit 500;';

      try {
        final data = await _postQuery('external_games', body);
        if (data is List) {
          for (final entry in data) {
            if (entry is! Map) continue;
            final uidStr = entry['uid']?.toString();
            final uid = int.tryParse(uidStr ?? '');
            final rawGame = entry['game'];
            final gameIdRaw = rawGame is Map ? rawGame['id'] : rawGame;
            final gameId = gameIdRaw is num
                ? gameIdRaw.toInt()
                : int.tryParse(gameIdRaw?.toString() ?? '');

            if (uid != null && gameId != null && gameId > 0) {
              steamIdToIgdbId.putIfAbsent(uid, () => gameId);
            }
          }
        }
      } catch (e) {
        _log.warning('[IGDB BATCH ERROR] Chunk $i: $e');
      }

      final processed = (i + chunk.length < uniqueSteamIds.length)
          ? i + chunk.length
          : uniqueSteamIds.length;
      if (onProgress != null) {
        onProgress(
          processed,
          uniqueSteamIds.length,
          'Identificando juegos en IGDB ($processed de ${uniqueSteamIds.length})...',
        );
      }

      if (i + chunkSize < uniqueSteamIds.length && !kDisableIsolatesForTests) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    if (steamIdToIgdbId.isEmpty) return {};

    if (onProgress != null) {
      onProgress(
        uniqueSteamIds.length,
        uniqueSteamIds.length,
        'Descargando portadas en alta resolución...',
      );
    }

    final igdbIds = steamIdToIgdbId.values.toSet().toList();
    final games = await getGamesByIdsFull(igdbIds);

    final Map<int, Map<String, dynamic>> gamesById = {
      for (final g in games.whereType<Map>())
        if (g['id'] is num)
          (g['id'] as num).toInt(): Map<String, dynamic>.from(g),
    };

    final Map<String, Map<String, dynamic>> result = {};
    steamIdToIgdbId.forEach((steamId, igdbId) {
      final game = gamesById[igdbId];
      if (game != null) result['steam:$steamId'] = game;
    });

    return result;
  }

  /// Datos completos (con cover, para GameCard) de una lista de IGDB IDs,
  /// en lotes concurrentes para no exceder los límites de IGDB.
  static Future<List<dynamic>> getGamesByIdsFull(List<int> igdbIds) async {
    final uniqueIds = igdbIds.where((id) => id > 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    final List<dynamic> allResults = [];
    const chunkSize = 200;
    const concurrency = 3;

    final chunks = <List<int>>[];
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      chunks.add(uniqueIds.skip(i).take(chunkSize).toList());
    }

    for (var i = 0; i < chunks.length; i += concurrency) {
      final batch = chunks.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(
        batch.map((chunk) async {
          final idsString = chunk.join(',');
          final body =
              'fields name, cover.image_id, first_release_date, category, game_type, parent_game, genres.name, platforms.name, url; where id = ($idsString); limit ${chunk.length};';
          try {
            final res = await _postQuery('games', body);
            return res is List ? res : const <dynamic>[];
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[IGDB BATCH getGamesByIdsFull] Error lote: $e');
            }
            return const <dynamic>[];
          }
        }),
      );

      for (final list in batchResults) {
        allResults.addAll(list);
      }

      if (i + concurrency < chunks.length && !kDisableIsolatesForTests) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    return allResults;
  }
}
