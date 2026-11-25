// lib/utils/url_utils.dart
//
// Helper para abrir URLs externas validando esquema seguro en Web (via package:web)
// y en plataformas nativas (via url_launcher).

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'web_js.dart';

/// Esquemas permitidos para enlaces externos (previene `javascript:` / `data:`).
const Set<String> _kAllowedExternalSchemes = <String>{'http', 'https', 'mailto'};

/// Valida y parsea [url] permitiendo únicamente esquemas externos seguros
/// (`http`, `https`, `mailto`). Devuelve `null` si es inválida o peligrosa.
@visibleForTesting
Uri? parseSafeExternalUri(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (!_kAllowedExternalSchemes.contains(scheme)) return null;
  if ((scheme == 'http' || scheme == 'https') && uri.host.isEmpty) {
    return null;
  }
  return uri;
}

/// Abre [url] en el navegador del sistema de forma compatible con todos los
/// navegadores web (Chrome, Firefox, Safari) y plataformas nativas.
///
/// Devuelve `true` si el enlace se pudo abrir, `false` en caso de error o
/// esquema no permitido.
Future<bool> openUrl(String url) async {
  final uri = parseSafeExternalUri(url);
  if (uri == null) return false;
  final safeUrl = uri.toString();

  if (kIsWeb) {
    try {
      if (clickExternalAnchorInWebDom(safeUrl)) {
        return true;
      }
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }

  // Nativo (Android, iOS, Windows, macOS, Linux)
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
