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

  const ImportedStylePackEntry({required this.pack, this.installDir});

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
  static final List<StylePack> _debugBuiltIn = [];
  static List<ImportedStylePackEntry> _imported = [];

  static const String _prefsKey = 'imported_style_packs';

  StylePackRegistry._();

  static Iterable<StylePack> get _debugIterable =>
      kDebugMode ? _debugBuiltIn : const <StylePack>[];

  /// Packs available in pickers (built-in, debug-only when debugging, imported).
  static List<StylePack> get selectable {
    final seen = <String>{};
    final out = <StylePack>[];
    for (final pack in [
      ..._builtIn,
      ..._debugIterable,
      ..._imported.map((e) => e.pack),
    ]) {
      if (seen.add(pack.id)) out.add(pack);
    }
    return out;
  }

  /// Debug-only built-in packs (empty outside [kDebugMode]).
  static List<StylePack> get debugBuiltIn =>
      kDebugMode ? List.unmodifiable(_debugBuiltIn) : const [];

  /// Whether [id] is a dev-only pack (not shipped in release).
  static bool isDebugOnly(String id) =>
      kDebugMode && _debugBuiltIn.any((p) => p.id == id);

  /// All available packs (built-in first, then user-imported).
  static List<StylePack> get all => selectable;

  /// Only packs the user imported (addons).
  static List<ImportedStylePackEntry> get imported =>
      List.unmodifiable(_imported);

  /// Whether [id] refers to a user-imported pack.
  static bool isImported(String id) =>
      _imported.any((entry) => entry.pack.id == id);

  /// Look up a pack by [id].  Falls back to the default pack if not found.
  static StylePack getById(String id) {
    for (final pack in _builtIn) {
      if (pack.id == id) return pack;
    }
    for (final pack in _debugIterable) {
      if (pack.id == id) return pack;
    }
    for (final entry in _imported) {
      if (entry.pack.id == id) return entry.pack;
    }
    return _builtIn.first;
  }

  /// Whether a pack with [id] is registered (built-in, debug, or imported).
  static bool exists(String id) =>
      _builtIn.any((p) => p.id == id) ||
      _debugIterable.any((p) => p.id == id) ||
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

  /// Register a pack only available while running in debug mode (e.g. P5R dev preview).
  static void registerDebugBuiltIn(StylePack pack) {
    if (!kDebugMode) return;
    if (_debugBuiltIn.every((p) => p.id != pack.id)) {
      _debugBuiltIn.add(pack);
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
      throw UnsupportedError(
        'Los addons .corpuspack solo se importan en móvil/escritorio.',
      );
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.files.firstWhere(
      (f) => p.basename(f.name).toLowerCase() == 'manifest.json',
      orElse: () =>
          throw const FormatException('Falta manifest.json en el paquete'),
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
      // Rechazar symlinks: podrían apuntar fuera del installDir (Auditoría I-02)
      if (_isSymlink(file)) {
        throw const FormatException(
          'El paquete contiene enlaces simbólicos, que no están permitidos',
        );
      }
      if (file.isFile && !isSafeArchivePath(file.name)) {
        throw const FormatException('Ruta no segura en el paquete');
      }
    }

    for (final file in archive.files) {
      if (!file.isFile || !isSafeArchivePath(file.name)) continue;
      final outPath = p.join(installDir, file.name);
      await File(outPath).create(recursive: true);
      await File(outPath).writeAsBytes(file.content as List<int>);
    }

    _imported.removeWhere((e) => e.pack.id == pack.id);
    _imported.add(ImportedStylePackEntry(pack: pack, installDir: installDir));
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
        return ImportedStylePackEntry(pack: StylePack.fromJson(map));
      }).toList();
    } catch (_) {
      _imported = [];
    }
  }

  static Future<String> _installDirFor(String packId) async {
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, 'style_packs', packId);
  }

  /// Nombres reservados de Windows que no se pueden usar como nombres de
  /// archivo/directorio (sin extensión). Un archivo llamado "CON.txt" en
  /// Windows abre el dispositivo de consola en vez del archivo real.
  static const _windowsReservedNames = {
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Valida que una ruta de archivo dentro de un archivo .corpuspack/.zip sea
  /// segura para extraer en el directorio de instalación.
  ///
  /// Protege contra:
  /// - Directory traversal (`../`, `..\\`)
  /// - Rutas absolutas
  /// - Archivos ocultos (`.ssh/`, `.env`)
  /// - Nombres reservados de Windows (`CON`, `PRN`, `NUL`, etc.)
  /// - Null bytes en la ruta
  /// - Separadores mixtos (`\` y `/`)
  ///
  /// (Auditoría I-02)
  @visibleForTesting
  static bool isSafeArchivePath(String name) {
    if (name.isEmpty) return false;

    // Rechazar null bytes (podrían truncar la ruta en APIs C subyacentes)
    if (name.contains('\x00')) return false;

    // Normalizar separadores mixtos antes de validar
    final cleaned = name.replaceAll('\\', '/');
    final normalized = p.normalize(cleaned);

    // Rechazar rutas absolutas
    if (p.isAbsolute(normalized)) return false;

    // Rechazar cualquier forma de traversal (../ al inicio, /../ en medio, o \..\ en medio)
    if (normalized.startsWith('..') ||
        normalized.contains('/../') ||
        normalized.contains('\\..\\') ||
        normalized == '..') {
      return false;
    }

    // Rechazar archivos/directorios ocultos (empiezan con .)
    for (final segment in p.split(normalized)) {
      if (segment.startsWith('.')) return false;
    }

    // Rechazar nombres reservados de Windows (sin extensión)
    final baseName = p.basenameWithoutExtension(normalized).toUpperCase();
    if (_windowsReservedNames.contains(baseName)) return false;

    return true;
  }

  /// Verifica que un [ArchiveFile] extraído NO sea un symlink.
  /// Las librerías de zip pueden contener symlinks que apuntan fuera del
  /// directorio de instalación, evadiendo `_isSafeArchivePath`.
  /// (Auditoría I-02)
  static bool _isSymlink(ArchiveFile file) {
    return file.isSymbolicLink;
  }

  /// Persist imported packs to local storage.
  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_imported.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}
