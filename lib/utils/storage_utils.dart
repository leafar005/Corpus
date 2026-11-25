import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'corpus_logger.dart';

class StorageUtils {
  static final _log = CorpusLogger('StorageUtils');

  /// Extrae el path relativo dentro del bucket `user_uploads` a partir de su URL
  /// pública (eliminando query params y `#fragment` y rechazando rutas inseguras).
  @visibleForTesting
  static String? extractUserUploadPath(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    var pathCandidate = parsed != null && parsed.path.isNotEmpty
        ? parsed.path
        : trimmed.split('#').first.split('?').first;

    final marker = '/user_uploads/';
    final idx = pathCandidate.indexOf(marker);
    if (idx == -1) return null;

    var rawPath = pathCandidate.substring(idx + marker.length);
    final qIdx = rawPath.indexOf('?');
    if (qIdx != -1) rawPath = rawPath.substring(0, qIdx);
    final hIdx = rawPath.indexOf('#');
    if (hIdx != -1) rawPath = rawPath.substring(0, hIdx);

    String decoded;
    try {
      decoded = Uri.decodeComponent(rawPath);
    } catch (_) {
      decoded = rawPath;
    }

    final clean = decoded.trim();
    if (clean.isEmpty ||
        clean.startsWith('/') ||
        clean.split('/').any((seg) => seg == '..' || seg.isEmpty)) {
      return null;
    }
    return clean;
  }

  /// Elimina múltiples imágenes del bucket `user_uploads` usando sus URLs públicas.
  ///
  /// Devuelve `true` si no había archivos válidos que borrar o si el borrado
  /// concluyó sin errores; `false` si falló la operación en Storage.
  static Future<bool> deleteImagesFromUrls(
    List<String> urls, {
    @visibleForTesting SupabaseClient? client,
  }) async {
    final paths = urls
        .map(extractUserUploadPath)
        .whereType<String>()
        .toSet()
        .toList();

    if (paths.isEmpty) return true;

    try {
      final db = client ?? Supabase.instance.client;
      await db.storage.from('user_uploads').remove(paths);
      _log.debug('Eliminadas ${paths.length} imágenes de user_uploads.');
      return true;
    } catch (e) {
      _log.warning('Error deleting images from storage: $e');
      return false;
    }
  }
}
