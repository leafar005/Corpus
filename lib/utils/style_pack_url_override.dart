import '../theme/style_pack_registry.dart';

/// Debug helper: apply a style pack from the page URL without opening settings.
///
/// Supported forms (web):
/// - `?style=persona5` / `?style=corpus`
/// - `/style/persona5` (path segment)
/// - `?=persona5` (empty query key, as in `/style?=persona5`)
class StylePackUrlOverride {
  StylePackUrlOverride._();

  static const Map<String, String> _aliases = {
    'corpus': 'default',
    'default': 'default',
    'classic': 'default',
    'persona5': 'persona_5_royal',
    'persona_5_royal': 'persona_5_royal',
    'p5r': 'persona_5_royal',
  };

  /// Returns a registered pack id, or null if the URL has no style override.
  static String? packIdFromUri(Uri uri) {
    final fromQuery = uri.queryParameters['style'];
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return _resolvePackId(fromQuery);
    }

    if (uri.query.startsWith('=') && uri.query.length > 1) {
      final id = _resolvePackId(uri.query.substring(1));
      if (id != null) return id;
    }

    for (final entry in uri.queryParameters.entries) {
      if (entry.key.isEmpty && entry.value.isNotEmpty) {
        final id = _resolvePackId(entry.value);
        if (id != null) return id;
      }
    }

    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'style') {
      return _resolvePackId(segments[1]);
    }

    return null;
  }

  static String? _resolvePackId(String raw) {
    final key = raw.trim().toLowerCase();
    final id = _aliases[key] ?? key;
    final exists = StylePackRegistry.all.any((p) => p.id == id);
    return exists ? id : null;
  }
}
