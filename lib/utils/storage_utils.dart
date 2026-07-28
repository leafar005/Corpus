import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageUtils {
  /// Delete multiple images from Supabase Storage using their public URLs
  static Future<void> deleteImagesFromUrls(List<String> urls) async {
    final paths = urls
        .map((url) {
          final parts = url.split('/user_uploads/');
          if (parts.length > 1) {
            String path = parts[1];
            if (path.contains('?')) {
              path = path.split('?').first;
            }
            try {
              return Uri.decodeComponent(path);
            } catch (_) {
              return path;
            }
          }
          return null;
        })
        .whereType<String>()
        .toList();

    if (paths.isNotEmpty) {
      try {
        await Supabase.instance.client.storage
            .from('user_uploads')
            .remove(paths);
        debugPrint(
          '[StorageUtils] Eliminadas ${paths.length} imágenes del bucket user_uploads.',
        );
      } catch (e) {
        debugPrint('Error deleting images from storage: $e');
      }
    }
  }
}
