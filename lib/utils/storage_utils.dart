import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageUtils {
  /// Delete multiple images from Supabase Storage using their public URLs
  static Future<void> deleteImagesFromUrls(List<String> urls) async {
    final paths = urls.map((url) {
      final parts = url.split('/user_uploads/');
      return parts.length > 1 ? parts[1] : null;
    }).whereType<String>().toList();

    if (paths.isNotEmpty) {
      try {
        await Supabase.instance.client.storage.from('user_uploads').remove(paths);
      } catch (e) {
        debugPrint('Error deleting images from storage: $e');
      }
    }
  }
}
