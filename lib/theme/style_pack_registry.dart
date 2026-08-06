import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'style_pack.dart';

/// Central catalogue of every [StylePack] the app knows about.
///
/// Built-in packs ship with the binary; imported packs are persisted in
/// [SharedPreferences] so they survive restarts.
class StylePackRegistry {
  static final List<StylePack> _builtIn = [StylePack.defaultPack()];
  static List<StylePack> _imported = [];

  static const String _prefsKey = 'imported_style_packs';

  StylePackRegistry._();

  /// All available packs (built-in first, then user-imported).
  static List<StylePack> get all => [..._builtIn, ..._imported];

  /// Look up a pack by [id].  Falls back to the default pack if not found.
  static StylePack getById(String id) {
    for (final pack in _builtIn) {
      if (pack.id == id) return pack;
    }
    for (final pack in _imported) {
      if (pack.id == id) return pack;
    }
    return _builtIn.first;
  }

  /// Register additional built-in packs (call before [loadImported]).
  static void registerBuiltIn(StylePack pack) {
    if (_builtIn.every((p) => p.id != pack.id)) {
      _builtIn.add(pack);
    }
  }

  // ── Import / persistence ─────────────────────────────────────────────────

  /// Import a pack from a decoded JSON map (e.g. from a file the user picked).
  static StylePack importFromJson(Map<String, dynamic> json) {
    final pack = StylePack.fromJson(json);
    _imported.removeWhere((p) => p.id == pack.id);
    _imported.add(pack);
    _persist();
    return pack;
  }

  /// Remove an imported pack by [id].  Built-in packs cannot be removed.
  static void removeImported(String id) {
    _imported.removeWhere((p) => p.id == id);
    _persist();
  }

  /// Load previously imported packs from local storage.
  /// Call once at app start (before `runApp`).
  static Future<void> loadImported() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _imported = list
          .map((e) => StylePack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _imported = [];
    }
  }

  /// Persist imported packs to local storage.
  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_imported.map((p) => p.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}
