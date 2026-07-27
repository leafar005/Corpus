import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:corpus/services/igdb_service.dart';

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
  });
}

class ImportService {
  /// Repara caracteres UTF-8 rotos (mojibake) típicos de exportaciones de Excel/web
  static String fixEncoding(String text) {
    if (!text.contains('Ã')) return text;
    return text
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã-', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã ', 'à')
        .replaceAll('Ã¨', 'è')
        .replaceAll('Ã¬', 'ì')
        .replaceAll('Ã²', 'ò')
        .replaceAll('Ã¹', 'ù')
        .replaceAll('Ã¼', 'ü')
        .replaceAll('Ã', 'í') // Fallback para í solas
        .replaceAll('Ã±', 'ñ');
  }

  static List<dynamic> getNames(dynamic field) {
    if (field == null) return [];
    if (field is List) {
      return field.map((e) => e is Map ? (e['name'] ?? e.toString()) : e).toList();
    }
    return [field.toString()];
  }

  static List<CsvGameRow> parseCsv(Uint8List fileBytes) {
    final String content = utf8.decode(fileBytes, allowMalformed: true).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<List<dynamic>> rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(content);
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

    final List<CsvGameRow> parsedRows = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length <= titleIdx) continue;

      final title = fixEncoding(row[titleIdx].toString().trim());
      if (title.isEmpty) continue;

      int? igdbId;
      if (idIdx != -1 && idIdx < row.length && row[idIdx] != null) {
        igdbId = int.tryParse(row[idIdx].toString().split('.').first);
      }

      int? releaseYear;
      if (yearIdx != -1 && yearIdx < row.length && row[yearIdx] != null) {
        releaseYear = int.tryParse(row[yearIdx].toString().split('.').first);
      }

      String rawStatus = statusIdx != -1 && statusIdx < row.length ? row[statusIdx].toString().toLowerCase().trim() : 'wishlist';
      String cleanStatus = 'wishlist';
      if (rawStatus == 'beaten' || rawStatus == 'completed' || rawStatus == 'finished' || rawStatus == 'terminado') cleanStatus = 'beaten';
      else if (rawStatus == 'playing' || rawStatus == 'jugando' || rawStatus == 'in progress') cleanStatus = 'playing';
      else if (rawStatus == 'want' || rawStatus == 'wishlist' || rawStatus == 'backlog' || rawStatus == 'quiero') cleanStatus = 'wishlist';
      else if (rawStatus == 'archived' || rawStatus == 'abandoned' || rawStatus == 'dropped' || rawStatus == 'abandonado') cleanStatus = 'abandoned';
      else if (rawStatus == 'on_hold' || rawStatus == 'on hold' || rawStatus == 'paused' || rawStatus == 'pausado') cleanStatus = 'on_hold';

      double? cleanRating;
      if (ratingIdx != -1 && ratingIdx < row.length && row[ratingIdx] != null) {
        final double rawRating = double.tryParse(row[ratingIdx].toString()) ?? 0.0;
        if (rawRating >= 1.0) {
          if (rawRating <= 5.0) {
            cleanRating = rawRating * 2.0;
          } else if (rawRating > 10.0) {
            cleanRating = rawRating / 10.0;
          } else {
            cleanRating = rawRating;
          }
          if (cleanRating < 1.0) cleanRating = null;
        }
      }

      String? comment;
      if (commentIdx != -1 && commentIdx < row.length && row[commentIdx] != null) {
        final c = fixEncoding(row[commentIdx].toString().trim());
        if (c.isNotEmpty && c != 'nan' && c != 'null') comment = c;
      }

      String? platform;
      if (platformIdx != -1 && platformIdx < row.length && row[platformIdx] != null) {
        final p = row[platformIdx].toString().trim().toLowerCase();
        if (p.isNotEmpty && p != 'nan' && p != 'null') platform = p;
      }

      double? playTimeHours;
      if (timeIdx != -1 && timeIdx < row.length && row[timeIdx] != null) {
        final t = double.tryParse(row[timeIdx].toString());
        if (t != null && t > 0) playTimeHours = t;
      }

      String? completionType;
      if (completionIdx != -1 && completionIdx < row.length && row[completionIdx] != null) {
        final ct = row[completionIdx].toString().trim().toLowerCase();
        if (ct.isNotEmpty && ct != 'nan' && ct != 'null') completionType = ct;
      }

      String? dateAdded;
      if (dateIdx != -1 && dateIdx < row.length && row[dateIdx] != null) {
        final d = row[dateIdx].toString().trim();
        if (d.isNotEmpty && d != 'nan' && d != 'null') dateAdded = d;
      }

      parsedRows.add(CsvGameRow(
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
      ));
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

      await Future.wait(chunk.map((row) async {
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
            final exact = results.where((g) => 
                (g['name'] ?? g['title'] ?? '').toString().toLowerCase().trim() == row.title.toLowerCase().trim()
            ).toList();

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
      }));

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

    const int batchSize = 100;
    
    for (int i = 0; i < total; i += batchSize) {
      final int end = (i + batchSize < total) ? i + batchSize : total;
      final batch = matchedRows.sublist(i, end);

      final List<Map<String, dynamic>> gamesPayload = [];
      final List<Map<String, dynamic>> userGamesPayload = [];
      final List<Map<String, dynamic>> reviewsPayload = [];

      for (final row in batch) {
        if (row.igdbData == null && row.igdbId == null) continue;
        
        final gameData = row.igdbData ?? <String, dynamic>{'id': row.igdbId, 'name': row.title};
        final int igdbId = (gameData['id'] ?? gameData['igdb_id'] ?? row.igdbId) as int;

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
          coverUrl = coverUrl.replaceAll('t_cover_big', 't_1080p').replaceAll('t_thumb', 't_1080p');
        }

        // 2. EXTRACCIÓN DE DESARROLLADOR PARA ACTIVAR LOGROS DE COMPAÑÍA:
        String? developer = gameData['developer'] as String?;
        if (developer == null || developer == 'Desconocido' || developer == 'Desarrollador desconocido') {
          if (gameData['involved_companies'] is List && (gameData['involved_companies'] as List).isNotEmpty) {
            final companies = gameData['involved_companies'] as List;
            for (final c in companies) {
              if (c is Map && c['developer'] == true && c['company'] is Map) {
                developer = c['company']['name']?.toString();
                break;
              }
            }
            if (developer == null && companies[0] is Map && companies[0]['company'] is Map) {
              developer = companies[0]['company']['name']?.toString();
            }
          }
        }

        // 3. FORMATEO DE FECHA DE LANZAMIENTO:
        String? releaseDate;
        final rawReleaseDate = gameData['first_release_date'];
        if (rawReleaseDate is num && rawReleaseDate > 0) {
          try {
            releaseDate = DateTime.fromMillisecondsSinceEpoch(rawReleaseDate.toInt() * 1000).toIso8601String().split('T')[0];
          } catch (e) {
            if (kDebugMode) print('[ImportService] Error formateando fecha: $e');
          }
        }


        final double? cleanRating = (row.rating != null && row.rating! >= 1.0) ? row.rating : null;
        final String dateAddedStr = row.dateAdded ?? DateTime.now().toUtc().toIso8601String();

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
          'collection': gameData['collection'] != null ? {'name': (gameData['collection'] is Map ? gameData['collection']['name'] : gameData['collection']).toString()} : null,
          'franchises': getNames(gameData['franchises']),
          'game_engines': getNames(gameData['game_engines']),
        });

        userGamesPayload.add({
          'user_id': userId,
          'game_id': igdbId,
          'status': row.status,
          'rating': cleanRating,
          'comment': row.comment?.isNotEmpty == true ? row.comment : null,
          'play_time_hours': (row.playTimeHours ?? 0) > 0 ? row.playTimeHours : null,
          'last_played_at': dateAddedStr,
          'updated_at': dateAddedStr,
        });

        if (cleanRating != null || (row.comment?.isNotEmpty == true) || row.status == 'beaten') {
          reviewsPayload.add({
            'user_id': userId,
            'game_id': igdbId,
            'rating': cleanRating,
            'comment': row.comment?.isNotEmpty == true ? row.comment : null,
            'status': row.status,
            'completion_type': row.completionType ?? (row.status == 'beaten' ? 'story' : 'none'),
            'platform': row.platform,
            'play_time_hours': (row.playTimeHours ?? 0) > 0 ? row.playTimeHours : null,
            'is_replay': false,
            'created_at': dateAddedStr,
          });
        }
      }

      try {
        if (gamesPayload.isNotEmpty) {
          await supabase.from('games').upsert(gamesPayload, onConflict: 'igdb_id');
        }
        if (userGamesPayload.isNotEmpty) {
          await supabase.from('user_games').upsert(userGamesPayload, onConflict: 'user_id, game_id');
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