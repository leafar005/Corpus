import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CompressedImage {
  final Uint8List bytes;
  final String extension;
  final String contentType;

  const CompressedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });
}

class ImageCompressor {
  static const List<int> _pngSig = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  static const Set<String> _pngMetadataChunkTypes = <String>{
    'eXIf',
    'tEXt',
    'zTXt',
    'iTXt',
    'tIME',
  };

  /// Detecta si [bytes] representa un PNG con canal alfa (`colorType` 4, 6 o `tRNS`).
  @visibleForTesting
  static bool hasPngAlpha(Uint8List bytes) {
    if (!_isPngSignature(bytes) || bytes.length < 33) return false;
    final ihdrType = String.fromCharCodes(bytes.sublist(12, 16));
    if (ihdrType != 'IHDR') return false;

    final colorType = bytes[25];
    if (colorType == 4 || colorType == 6) return true;
    if (colorType != 3) return false;

    var offset = 33;
    while (offset + 12 <= bytes.length) {
      final chunkLen = _readUint32BE(bytes, offset);
      final totalLen = 12 + chunkLen;
      if (chunkLen < 0 || offset + totalLen > bytes.length) break;
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (type == 'tRNS') return true;
      if (type == 'IDAT' || type == 'IEND') break;
      offset += totalLen;
    }
    return false;
  }

  /// Elimina metadatos EXIF/XMP/COM en JPEG y chunks auxiliares (`eXIf`, `tEXt`,
  /// `zTXt`, `iTXt`, `tIME`) en PNG para no filtrar ubicación ni metadatos en
  /// plataformas donde falla o no existe `FlutterImageCompress`.
  @visibleForTesting
  static Uint8List stripMetadataFallback(Uint8List bytes) {
    if (_isJpegSignature(bytes)) {
      return _stripJpegMetadata(bytes);
    }
    if (_isPngSignature(bytes)) {
      return _stripPngMetadata(bytes);
    }
    return bytes;
  }

  static bool _isPngSignature(Uint8List bytes) {
    if (bytes.length < _pngSig.length) return false;
    for (var i = 0; i < _pngSig.length; i++) {
      if (bytes[i] != _pngSig[i]) return false;
    }
    return true;
  }

  static bool _isJpegSignature(Uint8List bytes) =>
      bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  static int _readUint32BE(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static Uint8List _stripJpegMetadata(Uint8List bytes) {
    final out = BytesBuilder(copy: false)..add(<int>[0xFF, 0xD8]);
    var pos = 2;

    while (pos < bytes.length) {
      if (bytes[pos] != 0xFF) {
        return bytes;
      }
      while (pos < bytes.length && bytes[pos] == 0xFF) {
        pos++;
      }
      if (pos >= bytes.length) break;

      final marker = bytes[pos++];
      if (marker == 0xDA || marker == 0xD9) {
        // Start of Scan (SOS) / End of Image (EOI): copiar datos comprimidos íntegros.
        out.add(<int>[0xFF, marker]);
        if (pos < bytes.length) {
          out.add(bytes.sublist(pos));
        }
        return out.toBytes();
      }

      if (marker == 0x00 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD8)) {
        out.add(<int>[0xFF, marker]);
        continue;
      }

      if (pos + 2 > bytes.length) return bytes;
      final segLen = (bytes[pos] << 8) | bytes[pos + 1];
      if (segLen < 2 || pos + segLen > bytes.length) {
        return bytes;
      }

      final isMetadataSegment =
          (marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE;
      if (!isMetadataSegment) {
        out.add(<int>[0xFF, marker]);
        out.add(bytes.sublist(pos, pos + segLen));
      }
      pos += segLen;
    }

    return out.toBytes();
  }

  static Uint8List _stripPngMetadata(Uint8List bytes) {
    final out = BytesBuilder(copy: false)..add(_pngSig);
    var offset = 8;

    while (offset + 12 <= bytes.length) {
      final chunkLen = _readUint32BE(bytes, offset);
      final totalLen = 12 + chunkLen;
      if (chunkLen < 0 || offset + totalLen > bytes.length) {
        return bytes;
      }
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (!_pngMetadataChunkTypes.contains(type)) {
        out.add(bytes.sublist(offset, offset + totalLen));
      }
      offset += totalLen;
      if (type == 'IEND') {
        if (offset < bytes.length) {
          out.add(bytes.sublist(offset));
        }
        return out.toBytes();
      }
    }

    return bytes;
  }

  /// Comprime una imagen desde [file] en una sola lectura y devuelve los bytes
  /// resultantes junto con su extensión y `contentType` reales.
  static Future<CompressedImage> compressImageWithMeta(
    XFile file, {
    int maxWidth = 1080,
    int maxHeight = 1080,
    int? quality,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final preservePng = hasPngAlpha(bytes);
    try {
      final bool isSmallImage = bytes.lengthInBytes < 50 * 1024;
      final int effectiveQuality = quality ?? (isSmallImage ? 95 : 75);

      final Uint8List result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: effectiveQuality,
        format: preservePng ? CompressFormat.png : CompressFormat.jpeg,
        keepExif: false,
      );

      debugPrint(
        '[ImageCompressor] Compressed from ${bytes.lengthInBytes / 1024} KB '
        'to ${result.lengthInBytes / 1024} KB (${preservePng ? 'png' : 'jpg'})',
      );

      return CompressedImage(
        bytes: result,
        extension: preservePng ? 'png' : 'jpg',
        contentType: preservePng ? 'image/png' : 'image/jpeg',
      );
    } catch (e) {
      debugPrint('[ImageCompressor] Error compressing image: $e');
      final sanitized = stripMetadataFallback(bytes);
      final detected = _detectFormat(sanitized, fallbackName: file.name);
      return CompressedImage(
        bytes: sanitized,
        extension: detected.extension,
        contentType: detected.contentType,
      );
    }
  }

  /// Comprime una imagen desde [file] y devuelve sus bytes, o `null` si falla la lectura.
  static Future<Uint8List?> compressImage(XFile file) async {
    try {
      final result = await compressImageWithMeta(file);
      return result.bytes;
    } catch (e) {
      debugPrint('[ImageCompressor] Error reading image: $e');
      return null;
    }
  }

  static ({String extension, String contentType}) _detectFormat(
    Uint8List bytes, {
    String? fallbackName,
  }) {
    if (_isPngSignature(bytes)) {
      return (extension: 'png', contentType: 'image/png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return (extension: 'webp', contentType: 'image/webp');
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return (extension: 'gif', contentType: 'image/gif');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return (extension: 'jpg', contentType: 'image/jpeg');
    }

    if (fallbackName != null && fallbackName.contains('.')) {
      final ext = fallbackName.split('.').last.toLowerCase().trim();
      switch (ext) {
        case 'png':
          return (extension: 'png', contentType: 'image/png');
        case 'webp':
          return (extension: 'webp', contentType: 'image/webp');
        case 'gif':
          return (extension: 'gif', contentType: 'image/gif');
        case 'jpeg':
        case 'jpg':
          return (extension: 'jpg', contentType: 'image/jpeg');
      }
    }

    return (extension: 'jpg', contentType: 'image/jpeg');
  }
}
