import 'dart:typed_data';

import 'package:corpus/utils/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _makeMinimalPng({required int colorType, bool includeMetadata = false}) {
  final builder = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    // IHDR (len = 13)
    ..add(const [0x00, 0x00, 0x00, 0x0D])
    ..add('IHDR'.codeUnits)
    ..add([
      0x00, 0x00, 0x00, 0x01, // width 1
      0x00, 0x00, 0x00, 0x01, // height 1
      0x08, colorType, 0x00, 0x00, 0x00,
    ])
    ..add(const [0x00, 0x00, 0x00, 0x00]); // dummy CRC

  if (includeMetadata) {
    // eXIf chunk (len = 4)
    builder
      ..add(const [0x00, 0x00, 0x00, 0x04])
      ..add('eXIf'.codeUnits)
      ..add('GPS1'.codeUnits)
      ..add(const [0x00, 0x00, 0x00, 0x00]);
  }

  if (colorType == 3) {
    // tRNS chunk (len = 1)
    builder
      ..add(const [0x00, 0x00, 0x00, 0x01])
      ..add('tRNS'.codeUnits)
      ..add(const [0x00])
      ..add(const [0x00, 0x00, 0x00, 0x00]);
  }

  // IEND (len = 0)
  builder
    ..add(const [0x00, 0x00, 0x00, 0x00])
    ..add('IEND'.codeUnits)
    ..add(const [0xAE, 0x42, 0x60, 0x82]);
  return builder.toBytes();
}

Uint8List _makeMinimalJpegWithExif() {
  final builder = BytesBuilder()
    // SOI
    ..add(const [0xFF, 0xD8])
    // APP0 JFIF (len = 6 including length bytes)
    ..add(const [0xFF, 0xE0, 0x00, 0x06, 0x4A, 0x46, 0x49, 0x46])
    // APP1 EXIF with GPS marker (len = 10 including length bytes)
    ..add(const [0xFF, 0xE1, 0x00, 0x0A])
    ..add('ExifGPS1'.codeUnits)
    // SOS + scan data + EOI
    ..add(const [0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9]);
  return builder.toBytes();
}

void main() {
  group('ImageCompressor (BUG-102)', () {
    test('detecta canal alfa PNG RGBA y paleta con tRNS', () {
      expect(ImageCompressor.hasPngAlpha(_makeMinimalPng(colorType: 6)), isTrue);
      expect(ImageCompressor.hasPngAlpha(_makeMinimalPng(colorType: 3)), isTrue);
      expect(ImageCompressor.hasPngAlpha(_makeMinimalPng(colorType: 2)), isFalse);
      expect(ImageCompressor.hasPngAlpha(_makeMinimalJpegWithExif()), isFalse);
    });

    test('stripMetadataFallback elimina segmentos EXIF/eXIf en JPEG y PNG', () {
      final jpegWithExif = _makeMinimalJpegWithExif();
      final strippedJpeg = ImageCompressor.stripMetadataFallback(jpegWithExif);
      expect(String.fromCharCodes(strippedJpeg).contains('ExifGPS1'), isFalse);
      expect(strippedJpeg.sublist(0, 2), [0xFF, 0xD8]);
      // Mantiene APP0 JFIF
      expect(String.fromCharCodes(strippedJpeg).contains('JFIF'), isTrue);

      final pngWithExif = _makeMinimalPng(colorType: 6, includeMetadata: true);
      final strippedPng = ImageCompressor.stripMetadataFallback(pngWithExif);
      expect(String.fromCharCodes(strippedPng).contains('eXIf'), isFalse);
      expect(String.fromCharCodes(strippedPng).contains('GPS1'), isFalse);
      expect(String.fromCharCodes(strippedPng).contains('IHDR'), isTrue);
      expect(String.fromCharCodes(strippedPng).contains('IEND'), isTrue);
    });
  });
}
