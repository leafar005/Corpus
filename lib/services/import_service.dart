import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/utils/stash_json_to_csv_converter.dart';

class CsvGameRow {
  String title;
  int? igdbId;
  int? releaseYear;
  String status;
  double? rating;
  String? comment;
  String? platform;
  double? playTimeHours;
  String? completionType;
  String? dateAdded;

  String matchStatus; // 'matched', 'ambiguous', 'notFound'
  Map<String, dynamic>? igdbData;
  List<dynamic> candidates;

  bool steamOwned;
  int? steamPlaytimeMinutes;
  bool isSteamOnly;
  String? steamLastPlayedAt;

  CsvGameRow({
    required this.title,
    this.igdbId,
    this.releaseYear,
    required this.status,
    this.rating,
    this.comment,
    this.platform,
    this.playTimeHours,
    this.completionType,
    this.dateAdded,
    this.matchStatus = 'notFound',
    this.igdbData,
    this.candidates = const [],
    this.steamOwned = false,
    this.steamPlaytimeMinutes,
    this.isSteamOnly = false,
    this.steamLastPlayedAt,
  });
}

class ImportService {
  /// Repara caracteres UTF-8 rotos (mojibake) típicos de exportaciones de Excel/web
  static String fixEncoding(String text) {
    if (text.isEmpty || !RegExp(r'[ÃÂ][\u0080-\u00BF]').hasMatch(text)) {
      return text;
    }
    try {
      return utf8.decode(latin1.encode(text));
    } catch (_) {
      return text;
    }
  }

  static List<dynamic> getNames(dynamic field) {
    if (field == null) return [];
    if (field is List) {
      return field
          .map((e) => e is Map ? (e['name'] ?? e.toString()) : e)
          .toList();
    }
    return [field.toString()];
  }

  
  static CsvGameRow? _buildRow({
    required String rawTitle,
    String? rawIgdbId,
    String? rawReleaseYear,
    String? rawStatus,
    String? rawRating,
    String? rawComment,
    String? rawPlatform,
    String? rawPlayTimeHours,
    String? rawCompletionType,
    String? rawDateAdded,
  }) {
    final title = fixEncoding(rawTitle.trim());
    if (title.isEmpty) return null;

    int? igdbId;
    if (rawIgdbId != null && rawIgdbId.isNotEmpty) {
      igdbId = int.tryParse(rawIgdbId.split('.').first);
    }

    int? releaseYear;
    if (rawReleaseYear != null && rawReleaseYear.isNotEmpty) {
      releaseYear = int.tryParse(rawReleaseYear.split('.').first);
    }

    final rawStatusClean = (rawStatus ?? 'wishlist').toLowerCase().trim();
    String cleanStatus = 'wishlist';
    if (rawStatusClean == 'beaten' || rawStatusClean == 'completed' ||
        rawStatusClean == 'finished' || rawStatusClean == 'terminado') {
      cleanStatus = 'beaten';
    } else if (rawStatusClean == 'playing' || rawStatusClean == 'jugando' ||
        rawStatusClean == 'in progress') {
      cleanStatus = 'playing';
    } else if (rawStatusClean == 'want' || rawStatusClean == 'wishlist' ||
        rawStatusClean == 'backlog' || rawStatusClean == 'quiero') {
      cleanStatus = 'wishlist';
    } else if (rawStatusClean == 'archived' || rawStatusClean == 'abandoned' ||
        rawStatusClean == 'dropped' || rawStatusClean == 'abandonado') {
      cleanStatus = 'abandoned';
    } else if (rawStatusClean == 'on_hold' || rawStatusClean == 'on hold' ||
        rawStatusClean == 'paused' || rawStatusClean == 'pausado') {
      cleanStatus = 'on_hold';
    }

    double? cleanRating;
    if (rawRating != null && rawRating.isNotEmpty) {
      final parsed = double.tryParse(rawRating);
      if (parsed != null && parsed >= 1.0 && parsed <= 10.0) {
        cleanRating = parsed;
      }
    }

    String? comment;
    if (rawComment != null) {
      final c = fixEncoding(rawComment.trim());
      if (c.isNotEmpty && c != 'nan' && c != 'null') comment = c;
    }

    String? platform;
    if (rawPlatform != null) {
      final p = rawPlatform.trim().toLowerCase();
      if (p.isNotEmpty && p != 'nan' && p != 'null') platform = p;
    }

    double? playTimeHours;
    if (rawPlayTimeHours != null && rawPlayTimeHours.isNotEmpty) {
      final t = double.tryParse(rawPlayTimeHours);
      if (t != null && t > 0) playTimeHours = t;
    }

    String? completionType;
    if (rawCompletionType != null) {
      final ct = rawCompletionType.trim().toLowerCase();
      if (ct.isNotEmpty && ct != 'nan' && ct != 'null') completionType = ct;
    }

    String? dateAdded;
    if (rawDateAdded != null) {
      final d = rawDateAdded.trim();
      if (d.isNotEmpty && d != 'nan' && d != 'null') dateAdded = d;
    }

    return CsvGameRow(
      title: title,
      igdbId: igdbId,
      releaseYear: releaseYear,
      status: cleanStatus,
      rating: cleanRating,
      comment: comment,
      platform: platform,
      playTimeHours: playTimeHours,
      completionType: completionType,
      dateAdded: dateAdded,
    );
  }

  static List<CsvGameRow> parseCsv(Uint8List fileBytes) {
    final String content = utf8
        .decode(fileBytes, allowMalformed: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final List<List<dynamic>> rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);
    if (rows.isEmpty) return [];

    final List<String> headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();

    int titleIdx = headers.indexOf('title');
    if (titleIdx == -1) titleIdx = headers.indexOf('name');
    if (titleIdx == -1) titleIdx = 0;
    int idIdx = headers.indexOf('igdb_id');
    if (idIdx == -1) idIdx = headers.indexOf('id');
    int yearIdx = headers.indexOf('release_year');
    if (yearIdx == -1) yearIdx = headers.indexOf('year');
    int statusIdx = headers.indexOf('status');
    if (statusIdx == -1) statusIdx = headers.indexOf('estado');
    int ratingIdx = headers.indexOf('rating');
    if (ratingIdx == -1) ratingIdx = headers.indexOf('nota');
    if (ratingIdx == -1) ratingIdx = headers.indexOf('score');
    int commentIdx = headers.indexOf('comment');
    if (commentIdx == -1) commentIdx = headers.indexOf('review');
    if (commentIdx == -1) commentIdx = headers.indexOf('reseña');
    int platformIdx = headers.indexOf('platform');
    if (platformIdx == -1) platformIdx = headers.indexOf('plataforma');
    int timeIdx = headers.indexOf('play_time_hours');
    if (timeIdx == -1) timeIdx = headers.indexOf('hours');
    if (timeIdx == -1) timeIdx = headers.indexOf('time');
    if (timeIdx == -1) timeIdx = headers.indexOf('horas');
    int completionIdx = headers.indexOf('completion_type');
    if (completionIdx == -1) completionIdx = headers.indexOf('completion');
    int dateIdx = headers.indexOf('date_added');
    if (dateIdx == -1) dateIdx = headers.indexOf('created_at');
    if (dateIdx == -1) dateIdx = headers.indexOf('date');

    String? cell(List<dynamic> row, int idx) =>
        (idx != -1 && idx < row.length && row[idx] != null) ? row[idx].toString() : null;

    final List<CsvGameRow> parsedRows = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length <= titleIdx) continue;

      final built = _buildRow(
        rawTitle: row[titleIdx].toString(),
        rawIgdbId: cell(row, idIdx),
        rawReleaseYear: cell(row, yearIdx),
        rawStatus: cell(row, statusIdx),
        rawRating: cell(row, ratingIdx),
        rawComment: cell(row, commentIdx),
        rawPlatform: cell(row, platformIdx),
        rawPlayTimeHours: cell(row, timeIdx),
        rawCompletionType: cell(row, completionIdx),
        rawDateAdded: cell(row, dateIdx),
      );
      if (built != null) parsedRows.add(built);
    }

    return parsedRows;
  }

  static List<CsvGameRow> parseStashJson(Uint8List fileBytes) {
    final String jsonString = utf8.decode(fileBytes, allowMalformed: true);
    final dynamic data = jsonDecode(jsonString);
    final extracted = StashJsonToCsvConverter.extractRows(data);

    final List<CsvGameRow> parsedRows = [];
    for (final e in extracted) {
      final built = _buildRow(
        rawTitle: e.title,
        rawIgdbId: e.igdbId,
        rawReleaseYear: e.releaseYear,
        rawStatus: e.status,
        rawRating: e.rating,
        rawComment: e.comment,
        rawPlatform: e.platform,
        rawPlayTimeHours: e.playTimeHours,
        rawCompletionType: e.completionType,
        rawDateAdded: e.dateAdded,
      );
      if (built != null) parsedRows.add(built);
    }
    return parsedRows;
  }

static Future<void> matchGamesWithIGDB(
    List<CsvGameRow> rows,
    Function(int processed, int total) onProgress, {
    bool Function()? isCancelled,
  }) async {
    final int total = rows.length;
    int processed = 0;

    const int chunkSize = 5;
    for (int i = 0; i < total; i += chunkSize) {
      if (isCancelled != null && isCancelled()) return;

      final int end = (i + chunkSize < total) ? i + chunkSize : total;
      final chunk = rows.sublist(i, end);

      await Future.wait(
        chunk.map((row) async {
          try {
            if (row.igdbId != null && row.igdbId! > 0) {
              final game = await IGDBService.getGameById(row.igdbId!);
              if (game != null) {
                row.igdbData = game;
                row.matchStatus = 'matched';
                return;
              }
            }

            final results = await IGDBService.searchGames(row.title);
            if (results.isEmpty) {
              row.matchStatus = 'notFound';
            } else if (results.length == 1) {
              row.igdbData = results.first as Map<String, dynamic>;
              row.matchStatus = 'matched';
            } else {
              final exact = results
                  .where(
                    (g) =>
                        (g['name'] ?? g['title'] ?? '')
                            .toString()
                            .toLowerCase()
                            .trim() ==
                        row.title.toLowerCase().trim(),
                  )
                  .toList();

              if (exact.length == 1) {
                row.igdbData = exact.first as Map<String, dynamic>;
                row.matchStatus = 'matched';
              } else {
                row.candidates = results;
                row.matchStatus = 'ambiguous';
              }
            }
          } catch (e) {
            if (kDebugMode) print('Error matching game ${row.title}:$e');
            row.matchStatus = 'notFound';
          }
        }),
      );

      processed = end;
      onProgress(processed, total);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  static Future<void> saveImportedGames(
    List<CsvGameRow> matchedRows, {
    required Function(int current, int total) onProgress,
  }) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final int total = matchedRows.length;

    const int batchSize = 25;

    for (int i = 0; i < total; i += batchSize) {
      final int end = (i + batchSize < total) ? i + batchSize : total;
      final batch = matchedRows.sublist(i, end);

      final List<Map<String, dynamic>> gamesPayload = [];
      final List<Map<String, dynamic>> userGamesPayload = [];
      final List<Map<String, dynamic>> reviewsPayload = [];

      for (final row in batch) {
        if (row.igdbData == null && row.igdbId == null) continue;

        final gameData =
            row.igdbData ??
            <String, dynamic>{'id': row.igdbId, 'name': row.title};
        final int igdbId =
            (gameData['id'] ?? gameData['igdb_id'] ?? row.igdbId) as int;

        // 1. TRADUCCIÓN ROBUSTA DE CARÁTULA A ALTA RESOLUCIÓN:
        String? coverUrl = gameData['cover_url'] as String?;
        if (coverUrl == null || coverUrl.isEmpty) {
          final coverObj = gameData['cover'];
          if (coverObj is Map && coverObj['image_id'] != null) {
            coverUrl = IGDBService.getCoverUrl(coverObj['image_id'].toString());
          } else if (coverObj is String) {
            coverUrl = IGDBService.getCoverUrl(coverObj);
          }
        }
        if (coverUrl != null && coverUrl.isNotEmpty) {
          coverUrl = coverUrl
              .replaceAll('t_cover_big', 't_1080p')
              .replaceAll('t_thumb', 't_1080p');
        }

        // 2. EXTRACCIÓN DE DESARROLLADOR PARA ACTIVAR LOGROS DE COMPAÑÍA:
        String? developer = gameData['developer'] as String?;
        if (developer == null ||
            developer == 'Desconocido' ||
            developer == 'Desarrollador desconocido') {
          if (gameData['involved_companies'] is List &&
              (gameData['involved_companies'] as List).isNotEmpty) {
            final companies = gameData['involved_companies'] as List;
            for (final c in companies) {
              if (c is Map && c['developer'] == true && c['company'] is Map) {
                developer = c['company']['name']?.toString();
                break;
              }
            }
            if (developer == null &&
                companies[0] is Map &&
                companies[0]['company'] is Map) {
              developer = companies[0]['company']['name']?.toString();
            }
          }
        }

        // 3. FORMATEO DE FECHA DE LANZAMIENTO:
        String? releaseDate;
        final rawReleaseDate = gameData['first_release_date'];
        if (rawReleaseDate is num && rawReleaseDate > 0) {
          try {
            releaseDate = DateTime.fromMillisecondsSinceEpoch(
              rawReleaseDate.toInt() * 1000,
            ).toIso8601String().split('T')[0];
          } catch (e) {
            if (kDebugMode) {
              print('[ImportService] Error formateando fecha: $e');
            }
          }
        }

        final double? cleanRating = (row.rating != null && row.rating! >= 1.0)
            ? row.rating
            : null;
        final String dateAddedStr =
            row.steamLastPlayedAt ?? row.dateAdded ?? DateTime.now().toUtc().toIso8601String();

        gamesPayload.add({
          'igdb_id': igdbId,
          'title': gameData['name'] ?? gameData['title'] ?? row.title,
          'cover_url': coverUrl,
          'release_date': releaseDate,
          'genres': getNames(gameData['genres']),
          'platforms': getNames(gameData['platforms']),
          'developer': developer,
          'summary': gameData['summary'],
          'category': gameData['category'] ?? gameData['game_type'] ?? 0,
          'collection': gameData['collection'] != null
              ? {
                  'name':
                      (gameData['collection'] is Map
                              ? gameData['collection']['name']
                              : gameData['collection'])
                          .toString(),
                }
              : null,
          'franchises': getNames(gameData['franchises']),
          'game_engines': getNames(gameData['game_engines']),
          if (gameData['metacritic_score'] != null)
            'metacritic_score': gameData['metacritic_score'],
          if (gameData['metacritic_url'] != null)
            'metacritic_url': gameData['metacritic_url'],
        });

        userGamesPayload.add({
          'user_id': userId,
          'game_id': igdbId,
          'status': row.status,
          'rating': cleanRating,
          'comment': row.comment?.isNotEmpty == true ? row.comment : null,
          'play_time_hours': (row.playTimeHours ?? 0) > 0
              ? row.playTimeHours
              : null,
          'last_played_at': dateAddedStr,
          'updated_at': dateAddedStr,
          if (row.steamOwned) 'steam_owned': true,
          if (row.steamPlaytimeMinutes != null) 'steam_playtime_minutes': row.steamPlaytimeMinutes,
          if (row.isSteamOnly) 'is_steam_only': true,
          if (row.steamLastPlayedAt != null) 'steam_last_played_at': row.steamLastPlayedAt,
        });

        reviewsPayload.add({
          'user_id': userId,
          'game_id': igdbId,
          'rating': cleanRating,
          'comment': row.comment?.isNotEmpty == true ? row.comment : null,
          'status': row.status,
          'completion_type':
              row.completionType ??
              (row.status == 'beaten' ? 'story' : 'none'),
          'platform': row.platform,
          'play_time_hours': (row.playTimeHours ?? 0) > 0
              ? row.playTimeHours
              : null,
          'is_replay': false,
          'created_at': dateAddedStr,
        });
      }

      try {
        if (gamesPayload.isNotEmpty) {
          await supabase
              .from('games')
              .upsert(gamesPayload, onConflict: 'igdb_id');
        }
        if (userGamesPayload.isNotEmpty) {
          await supabase
              .from('user_games')
              .upsert(userGamesPayload, onConflict: 'user_id, game_id');
        }
        if (reviewsPayload.isNotEmpty) {
          await supabase.from('reviews').insert(reviewsPayload);
        }

        onProgress(end, total);
      } catch (e) {
        debugPrint('[CORPUS IMPORT ERROR] Fallo en el lote $i a $end:$e');
        rethrow;
      }
    }
  }
}
