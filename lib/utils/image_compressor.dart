import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageCompressor {
  /// Compresses an image from an [XFile] and returns it as a [Uint8List]
  /// ready to be uploaded to Supabase.
  /// This approach (using bytes) is safe for Web, iOS, and Android.
  static Future<Uint8List?> compressImage(XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();

      // Skip compression for very small images (e.g. < 50KB)
      if (bytes.lengthInBytes < 50 * 1024) {
        return bytes;
      }

      final Uint8List result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
        keepExif: false, // Ensure EXIF data like GPS is removed
      );

      debugPrint(
        '[ImageCompressor] Compressed from ${bytes.lengthInBytes / 1024} KB '
        'to ${result.lengthInBytes / 1024} KB',
      );

      return result;
    } catch (e) {
      debugPrint('[ImageCompressor] Error compressing image: $e');
      // If compression fails, fallback to the original bytes so the upload doesn't break
      return await file.readAsBytes();
    }
  }
}
