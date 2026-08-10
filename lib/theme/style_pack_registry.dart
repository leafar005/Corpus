import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'style_pack.dart';

/// Persisted metadata for a user-imported style pack (JSON or `.corpuspack`).
@immutable
class ImportedStylePackEntry {
  final StylePack pack;
  final String? installDir;

  const ImportedStylePackEntry({
    required this.pack,
    this.installDir,
  });

  Map<String, dynamic> toJson() => {
    'pack': pack.toJson(),
    if (installDir != null) 'installDir': installDir,
  };

  factory ImportedStylePackEntry.fromJson(Map<String, dynamic> json) {
    return ImportedStylePackEntry(
      pack: StylePack.fromJson(json['pack'] as Map<String, dynamic>),
      installDir: json['installDir'] as String?,
    );
  }
}

/// Central catalogue of every [StylePack] the app knows about.
///
/// Built-in packs ship with the binary; imported packs are persisted in
/// [SharedPreferences] so they survive restarts.
class StylePackRegistry {
  static final List<StylePack> _builtIn = [StylePack.defaultPack()];
  static List<ImportedStylePackEntry> _imported = [];

  static const String _prefsKey = 'imported_style_packs';

  StylePackRegistry._();

  /// All available packs (built-in first, then user-imported).
  static List<StylePack> get all =>
      [..._builtIn, ..._imported.map((e) => e.pack)];

  /// Only packs the user imported (addons).
  static List<ImportedStylePackEntry> get imported => List.unmodifiable(_imported);

  /// Whether [id] refers to a user-imported pack.
  static bool isImported(String id) =>
      _imported.any((entry) => entry.pack.id == id);

  /// Look up a pack by [id].  Falls back to the default pack if not found.
  static StylePack getById(String id) {
    for (final pack in _builtIn) {
      if (pack.id == id) return pack;
    }
    for (final entry in _imported) {
      if (entry.pack.id == id) return entry.pack;
    }
    return _builtIn.first;
  }

  /// Whether a pack with [id] is registered (built-in or imported).
  static bool exists(String id) =>
      _builtIn.any((p) => p.id == id) ||
      _imported.any((e) => e.pack.id == id);

  /// Absolute path to background music for [packId], if bundled in an addon.
  static String? resolveMusicFilePath(String packId) {
    for (final entry in _imported) {
      if (entry.pack.id != packId) continue;
      final musicFile = entry.pack.musicFile;
      final installDir = entry.installDir;
      if (musicFile == null || installDir == null) return null;
      return p.normalize(p.join(installDir, musicFile));
    }
    return null;
  }

  /// Register additional built-in packs (call before [loadImported]).
  static void registerBuiltIn(StylePack pack) {
    if (_builtIn.every((p) => p.id != pack.id)) {
      _builtIn.add(pack);
    }
  }

  // ── Import / persistence ─────────────────────────────────────────────────

  /// Import a pack from a decoded JSON map (legacy `.json` import).
  static Future<StylePack> importFromJson(Map<String, dynamic> json) async {
    final pack = StylePack.fromJson(json);
    _imported.removeWhere((e) => e.pack.id == pack.id);
    _imported.add(ImportedStylePackEntry(pack: pack));
    await _persist();
    return pack;
  }

  /// Import a `.corpuspack` / `.zip` bundle with `manifest.json` at the root.
  static Future<StylePack> importFromBundle(Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError('Los addons .corpuspack solo se importan en móvil/escritorio.');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.files.firstWhere(
      (f) => p.basename(f.name).toLowerCase() == 'manifest.json',
      orElse: () => throw const FormatException('Falta manifest.json en el paquete'),
    );

    final manifestJson =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    final pack = StylePack.fromJson(manifestJson);
    final installDir = await _installDirFor(pack.id);

    final dir = Directory(installDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    for (final file in archive.files) {
      if (file.isFile && !_isSafeArchivePath(file.name)) {
        throw const FormatException('Ruta no segura en el paquete');
      }
    }

    for (final file in archive.files) {
      if (!file.isFile || !_isSafeArchivePath(file.name)) continue;
      final outPath = p.join(installDir, file.name);
      await File(outPath).create(recursive: true);
      await File(outPath).writeAsBytes(file.content as List<int>);
    }

    _imported.removeWhere((e) => e.pack.id == pack.id);
    _imported.add(
      ImportedStylePackEntry(pack: pack, installDir: installDir),
    );
    await _persist();
    return pack;
  }

  /// Remove an imported pack by [id]. Built-in packs cannot be removed.
  static Future<void> removeImported(String id) async {
    ImportedStylePackEntry? entry;
    for (final e in _imported) {
      if (e.pack.id == id) {
        entry = e;
        break;
      }
    }
    if (entry == null) return;

    final installDir = entry.installDir;
    if (installDir != null && !kIsWeb) {
      final dir = Directory(installDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }

    _imported.removeWhere((e) => e.pack.id == id);
    await _persist();
  }

  /// Load previously imported packs from local storage.
  /// Call once at app start (before `runApp`).
  static Future<void> loadImported() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _imported = list.map((e) {
        final map = e as Map<String, dynamic>;
        if (map.containsKey('pack')) {
          return ImportedStylePackEntry.fromJson(map);
        }
        // Legacy: array of bare StylePack JSON objects.
        return ImportedStylePackEntry(
          pack: StylePack.fromJson(map),
        );
      }).toList();
    } catch (_) {
      _imported = [];
    }
  }

  static Future<String> _installDirFor(String packId) async {
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, 'style_packs', packId);
  }

  static bool _isSafeArchivePath(String name) {
    final normalized = p.normalize(name);
    if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
      return false;
    }
    return true;
  }

  /// Persist imported packs to local storage.
  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_imported.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}
