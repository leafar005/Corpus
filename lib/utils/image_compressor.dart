import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  /// Compresses an image from an [XFile] and returns it as a [Uint8List]
  /// ready to be uploaded to Supabase.
  /// This approach (using bytes) is safe for Web, iOS, and Android.
  static Future<Uint8List?> compressImage(XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();

      // Para imágenes pequeñas (< 50 KB) mantenemos calidad alta (95), pero
      // pasamos igualmente por FlutterImageCompress con keepExif: false para
      // eliminar siempre metadatos EXIF/GPS antes de subir a Storage (SEC-08).
      final bool isSmallImage = bytes.lengthInBytes < 50 * 1024;

      final Uint8List result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: isSmallImage ? 95 : 75,
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
