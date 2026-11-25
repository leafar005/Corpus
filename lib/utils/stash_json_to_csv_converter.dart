import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Una fila ya extraída y "aplanada" de un juego+review de Stash.
/// Los campos se guardan como String (igual que acabarían en una celda CSV)
/// para que el mismo código de limpieza/parseo de ImportService.parseCsv
/// sirva sin duplicar lógica, venga la fila de un CSV o directamente de JSON.
class StashExtractedGame {
  final String title;
  final String? igdbId;
  final String? releaseYear;
  final String status; // valor crudo de Stash, ej. "BEATEN"
  final String? rating;
  final String? comment;
  final String? platform;
  final String? playTimeHours;
  final String completionType;
  final String? dateAdded;

  const StashExtractedGame({
    required this.title,
    this.igdbId,
    this.releaseYear,
    required this.status,
    this.rating,
    this.comment,
    this.platform,
    this.playTimeHours,
    required this.completionType,
    this.dateAdded,
  });
}

class StashJsonToCsvConverter {
  /// Tabla inversa Windows-1252 para bytes `0x80`–`0x9F` (mojibake típico de Excel/HAR).
  static const Map<int, int> _cp1252ToByte = {
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  /// Decodifica una cadena que puede provenir de bytes Windows-1252/Latin-1 rotos.
  static String decodeCp1252Bytes(List<int> bytes) {
    final buffer = StringBuffer();
    // Si hay runes Unicode de CP1252 o bytes Latin-1, aquí convertimos bytes crudos [0..255]
    const cp1252Upper = <int, String>{
      0x80: '€', 0x81: '\u0081', 0x82: '‚', 0x83: 'ƒ', 0x84: '„', 0x85: '…',
      0x86: '†', 0x87: '‡', 0x88: 'ˆ', 0x89: '‰', 0x8A: 'Š', 0x8B: '‹',
      0x8C: 'Œ', 0x8D: '\u008D', 0x8E: 'Ž', 0x8F: '\u008F', 0x90: '\u0090',
      0x91: '‘', 0x92: '’', 0x93: '“', 0x94: '”', 0x95: '•', 0x96: '–',
      0x97: '—', 0x98: '˜', 0x99: '™', 0x9A: 'š', 0x9B: '›', 0x9C: 'œ',
      0x9D: '\u009D', 0x9E: 'ž', 0x9F: 'Ÿ',
    };
    for (final b in bytes) {
      if (b >= 0x80 && b <= 0x9F) {
        buffer.write(cp1252Upper[b] ?? String.fromCharCode(b));
      } else {
        buffer.writeCharCode(b & 0xFF);
      }
    }
    return fixEncoding(buffer.toString());
  }

  /// Fixes mojibake in strings coming from Stash HAR / Windows-1252 exports.
  static String fixEncoding(String text) {
    if (text.isEmpty ||
        !RegExp(r'(Ã.|Â.|â[\u0080-\u00BF\u20AC\u2018-\u2026\u2122]|ðŸ)').hasMatch(text)) {
      return text;
    }

    int? toByte(int rune) {
      if (rune <= 0xFF) return rune;
      return _cp1252ToByte[rune];
    }

    // Reconstruye segmentos contiguos representables como bytes CP1252 y preserva emojis u otros runes > 255.
    final out = StringBuffer();
    final runBytes = <int>[];

    void flushRun() {
      if (runBytes.isEmpty) return;
      try {
        out.write(utf8.decode(runBytes, allowMalformed: false));
      } catch (_) {
        for (final b in runBytes) {
          out.writeCharCode(b);
        }
      }
      runBytes.clear();
    }

    for (final rune in text.runes) {
      final b = toByte(rune);
      if (b != null) {
        runBytes.add(b);
      } else {
        flushRun();
        out.writeCharCode(rune);
      }
    }
    flushRun();
    return out.toString();
  }

  /// Escapes a string for CSV format.
  static String escapeCsv(String text) {
    if (text.isEmpty) return '';
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  /// Punto de entrada para uso EXTERNO a la app (script manual, herramienta de línea
  /// de comandos, etc.): convierte un HAR/JSON de Stash directamente a texto CSV.
  static String convertJsonToCsv(String jsonString) {
    final dynamic data = jsonDecode(jsonString);
    return convertDataToCsv(data);
  }

  static String convertDataToCsv(dynamic data) {
    final rows = extractRows(data);

    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln(
      'title,igdb_id,release_year,status,rating,comment,platform,play_time_hours,completion_type,date_added',
    );

    for (final r in rows) {
      csvBuffer.writeln(
        [
          escapeCsv(r.title),
          escapeCsv(r.igdbId ?? ''),
          escapeCsv(r.releaseYear ?? ''),
          escapeCsv(r.status),
          escapeCsv(r.rating ?? ''),
          escapeCsv(r.comment ?? ''),
          escapeCsv(r.platform ?? ''),
          escapeCsv(r.playTimeHours ?? ''),
          escapeCsv(r.completionType),
          escapeCsv(r.dateAdded ?? ''),
        ].join(','),
      );
    }

    return csvBuffer.toString();
  }

  /// Núcleo de extracción, compartido entre el exportador a CSV y el importador
  /// directo a la app (ImportService.parseStashJson). Toda la lógica de "cómo
  /// leer un HAR/JSON de Stash" vive SOLO aquí.
  static List<StashExtractedGame> extractRows(dynamic data) {
    final List<Map<String, dynamic>> allReviews = [];

    List<dynamic> entriesToProcess = [];

    if (data is Map &&
        data.containsKey('log') &&
        data['log']['entries'] is List) {
      final entries = data['log']['entries'] as List;
      for (final entry in entries) {
        if (entry is Map &&
            entry.containsKey('response') &&
            entry['response']['content'] is Map) {
          final content = entry['response']['content'];
          String? text = content['text'];
          if (text != null) {
            try {
              if (content['encoding'] == 'base64') {
                text = utf8.decode(base64.decode(text));
              }
              final parsed = jsonDecode(text);
              entriesToProcess.add(parsed);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[StashJsonToCsvConverter] Entrada HAR ignorada: $e');
              }
            }
          }
        }
      }
    } else if (data is List) {
      entriesToProcess = data;
    } else {
      entriesToProcess = [data];
    }

    for (final pageObj in entriesToProcess) {
      if (pageObj is! Map) continue;

      final items = pageObj['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map && item.containsKey('review')) {
            allReviews.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (pageObj.containsKey('review')) {
        allReviews.add(Map<String, dynamic>.from(pageObj));
      }
    }

    // Deduplicar por igdb_id, quedándonos con la revisión más reciente.
    final Map<int, Map<String, dynamic>> dedupedByGameId = {};
    for (final entry in allReviews) {
      final game = entry['game'];
      final review = entry['review'];
      if (game is! Map || review is! Map) continue;

      final gameIdRaw = game['id'] ?? game['igdb_id'];
      final gameId = int.tryParse(gameIdRaw?.toString() ?? '');
      if (gameId == null) continue;

      final modDate =
          num.tryParse(review['modificationDate']?.toString() ?? '') ?? 0;
      final existing = dedupedByGameId[gameId];
      if (existing == null) {
        dedupedByGameId[gameId] = entry;
      } else {
        final existingModDate =
            num.tryParse(
              existing['review']?['modificationDate']?.toString() ?? '',
            ) ??
            0;
        if (modDate > existingModDate) {
          dedupedByGameId[gameId] = entry;
        }
      }
    }

    final List<StashExtractedGame> result = [];

    for (final entry in dedupedByGameId.values) {
      final game = entry['game'];
      final review = entry['review'];
      if (game is! Map || review is! Map) continue;

      final title = fixEncoding(
        game['name']?.toString() ?? game['title']?.toString() ?? 'Desconocido',
      );
      final igdbId =
          game['id']?.toString() ?? game['igdb_id']?.toString() ?? '';

      String releaseYear = '';
      final rawDate = game['firstReleaseDate'] ?? game['first_release_date'];
      if (rawDate != null) {
        final timestamp = num.tryParse(rawDate.toString());
        if (timestamp != null) {
          final ms = timestamp > 9999999999
              ? timestamp.toInt()
              : timestamp.toInt() * 1000;
          final date = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          releaseYear = date.year.toString();
        }
      }

      final status = review['status']?.toString() ?? 'abandoned';
      final rating =
          review['ratingFloat']?.toString() ??
          review['rating']?.toString() ??
          review['score']?.toString() ??
          '';
      final comment = fixEncoding(
        review['comment']?.toString() ?? review['review']?.toString() ?? '',
      );

      String platformName = '';
      if (review['platform'] is Map && review['platform']['name'] != null) {
        platformName = fixEncoding(review['platform']['name'].toString());
      }

      String playTimeHours = '';
      if (review['detailInfo'] is List) {
        for (final detail in review['detailInfo']) {
          if (detail is Map &&
              detail['type'] == 'playingTime' &&
              detail['seconds'] != null) {
            final secs = num.tryParse(detail['seconds'].toString()) ?? 0;
            if (secs > 0) {
              playTimeHours = (secs / 3600.0).toStringAsFixed(1);
            }
          }
        }
      }
      if (playTimeHours.isEmpty) {
        playTimeHours = review['played_time']?.toString() ?? '';
      }

      String completionType = 'none';
      if (review['markers'] is List) {
        final markers = (review['markers'] as List)
            .map((e) => e.toString())
            .toList();
        if (markers.contains('completionists')) {
          completionType = '100_percent';
        } else if (markers.contains('beaten')) {
          completionType = 'story';
        }
      }
      if (completionType == 'none') {
        completionType = review['completion_type']?.toString() ?? 'none';
      }

      String dateAdded = '';
      final rawModDate = review['modificationDate'] ?? review['created_at'];
      if (rawModDate != null) {
        DateTime? dateObj;
        if (rawModDate is num) {
          final ms = rawModDate > 9999999999
              ? rawModDate.toInt()
              : rawModDate.toInt() * 1000;
          dateObj = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        } else {
          dateObj = DateTime.tryParse(rawModDate.toString())?.toUtc();
        }
        if (dateObj != null) {
          dateAdded =
              '${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}';
        }
      }

      result.add(
        StashExtractedGame(
          title: title,
          igdbId: igdbId.isEmpty ? null : igdbId,
          releaseYear: releaseYear.isEmpty ? null : releaseYear,
          status: status,
          rating: rating.isEmpty ? null : rating,
          comment: comment.isEmpty ? null : comment,
          platform: platformName.isEmpty ? null : platformName,
          playTimeHours: playTimeHours.isEmpty ? null : playTimeHours,
          completionType: completionType,
          dateAdded: dateAdded.isEmpty ? null : dateAdded,
        ),
      );
    }

    return result;
  }
}
