import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../theme/style_pack.dart';
import '../theme/style_pack_registry.dart';

/// Result of picking and importing a style pack file.
class StylePackImportResult {
  final StylePack pack;
  final bool isBundle;

  const StylePackImportResult({required this.pack, required this.isBundle});
}

/// Picks and imports `.corpuspack`, `.zip` or `.json` style pack files.
class StylePackImportService {
  StylePackImportService._();

  static Future<StylePackImportResult?> pickAndImport() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'La importación de addons no está disponible en web.',
      );
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['corpuspack', 'zip', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'json') {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final pack = await StylePackRegistry.importFromJson(json);
      return StylePackImportResult(pack: pack, isBundle: false);
    }

    final pack = await StylePackRegistry.importFromBundle(bytes);
    return StylePackImportResult(pack: pack, isBundle: true);
  }
}
