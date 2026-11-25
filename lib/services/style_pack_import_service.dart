import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../theme/style_pack.dart';
import '../theme/style_pack_registry.dart';
import '../utils/isolate_runner.dart';

/// Result of picking and importing a style pack file.
class StylePackImportResult {
  final StylePack pack;
  final bool isBundle;

  const StylePackImportResult({required this.pack, required this.isBundle});
}

/// Picks and imports `.corpuspack`, `.zip` or `.json` style pack files.
class StylePackImportService {
  StylePackImportService._();

  static const int maxPackFileBytes = 50 * 1024 * 1024;

  static Future<StylePackImportResult?> pickAndImport() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'La importación de addons no está disponible en web.',
      );
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['corpuspack', 'zip', 'json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.size > maxPackFileBytes) {
      throw const FormatException(
        'El paquete supera el tamaño máximo permitido de 50 MB.',
      );
    }

    final Uint8List? bytes =
        file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return null;
    if (bytes.length > maxPackFileBytes) {
      throw const FormatException(
        'El paquete supera el tamaño máximo permitido de 50 MB.',
      );
    }

    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'json') {
      final decoded = await runInBackgroundIsolate(
        () => jsonDecode(utf8.decode(bytes)),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El JSON del paquete no es un objeto válido.');
      }
      final rawId = decoded['id']?.toString() ?? '';
      if (!StylePackRegistry.isValidPackId(rawId)) {
        throw FormatException('ID de style pack no válido: "$rawId"');
      }
      final pack = await StylePackRegistry.importFromJson(decoded);
      return StylePackImportResult(pack: pack, isBundle: false);
    }

    final pack = await StylePackRegistry.importFromBundle(bytes);
    return StylePackImportResult(pack: pack, isBundle: true);
  }
}
