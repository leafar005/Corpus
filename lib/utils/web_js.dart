// lib/utils/web_js.dart
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║                    ⚠️ CRITICAL NAVIGATION CODE                     ║
// ║                                                                      ║
// ║ This file participates directly in the browser history / Flutter     ║
// ║ Web navigation integration using package:web + dart:js_interop.      ║
// ║                                                                      ║
// ║ history.state MUST stay stored as a plain JSON String so Flutter     ║
// ║ Web's internal router never double-pops a single Back action.        ║
// ╚══════════════════════════════════════════════════════════════════════╝

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'web_js_stub.dart' if (dart.library.js_interop) 'web_js_web.dart' as impl;

const Set<String> _kPreservedQueryKeys = <String>{
  'style',
  'code',
  'token',
  'token_hash',
  'type',
  'access_token',
  'refresh_token',
  'state',
  'error',
  'error_code',
  'error_description',
  'provider_token',
};

void dispatchCorpusReady() {
  if (!kIsWeb) return;
  impl.dispatchCorpusReadyImpl();
}

/// Carga bajo demanda CropperJS en Web cuando el usuario abre el recorte.
/// Devuelve `true` si `window.Cropper` quedó disponible, `false` si falló CDN/red.
Future<bool> ensureCropperJsLoaded() {
  if (!kIsWeb) return Future.value(true);
  return impl.ensureCropperJsLoadedImpl();
}

String? getWebPathname() {
  if (!kIsWeb) return null;
  return impl.getWebPathnameImpl();
}

/// Preserva parámetros de estilo y de autenticación/deep-link (`code`, `token_hash`, etc.)
/// al actualizar la URL con `history.pushState` / `history.replaceState`.
@visibleForTesting
String buildPreservedWebSearch(String? rawSearch) {
  if (rawSearch == null || rawSearch.isEmpty) return '';
  if (rawSearch.startsWith('?=')) return rawSearch;

  final queryStr = rawSearch.startsWith('?') ? rawSearch.substring(1) : rawSearch;
  if (queryStr.isEmpty) return '';

  final uri = Uri(query: queryStr);
  final preserved = <String>[];
  uri.queryParametersAll.forEach((key, values) {
    if (!_kPreservedQueryKeys.contains(key)) return;
    for (final v in values) {
      if (v.isEmpty) continue;
      preserved.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(v)}',
      );
    }
  });
  return preserved.isEmpty ? '' : '?${preserved.join('&')}';
}

/// Preserva fragmentos `#access_token=...` / `#type=recovery` usados en flujos de auth implícitos.
@visibleForTesting
String buildPreservedWebHash(String? rawHash) {
  if (rawHash == null || rawHash.isEmpty || rawHash == '#') return '';
  final lower = rawHash.toLowerCase();
  if (lower.contains('access_token=') ||
      lower.contains('refresh_token=') ||
      lower.contains('type=recovery') ||
      lower.contains('error=')) {
    return rawHash.startsWith('#') ? rawHash : '#$rawHash';
  }
  return '';
}

void setWebPath(
  String path, {
  bool replace = false,
  Map<String, Object?>? state,
}) {
  if (!kIsWeb) return;
  final preservedSearch = buildPreservedWebSearch(impl.getWebSearchImpl());
  final preservedHash = buildPreservedWebHash(impl.getWebHashImpl());
  final url = '$path$preservedSearch$preservedHash';
  final jsState = state == null ? null : jsonEncode(state);
  impl.setWebHistoryStateImpl(url, replace: replace, jsonState: jsState);
}

/// Lee el estado del historial del navegador preservando compatibilidad con JSON Strings.
Map<String, Object?>? readWebHistoryState(Object? rawState) {
  if (rawState == null) return null;
  try {
    if (rawState is String) {
      final decoded = jsonDecode(rawState);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } else if (rawState is Map) {
      return Map<String, Object?>.from(rawState);
    }
  } catch (e) {
    debugPrint('[WebJs] Error leyendo history.state: $e');
  }
  return null;
}

/// Escucha `window.onPopState` como stream normalizado de mapas.
Stream<Map<String, Object?>?> webPopStateStream() {
  if (!kIsWeb) return const Stream.empty();
  return impl.webPopStateRawStreamImpl().map(readWebHistoryState);
}

/// Llama directamente a `window.history.back()`.
void goBackInBrowserHistory() {
  if (!kIsWeb) return;
  impl.goBackInBrowserHistoryImpl();
}

/// Abre un enlace creando un `<a>` temporal en el DOM para evitar popup blockers.
bool clickExternalAnchorInWebDom(String safeUrl) {
  if (!kIsWeb) return false;
  return impl.clickExternalAnchorImpl(safeUrl);
}

/// Stream de clics sobre notificaciones enviados por `firebase-messaging-sw.js`.
Stream<Map<String, dynamic>> webNotificationClickStream() {
  if (!kIsWeb) return const Stream.empty();
  return impl.webNotificationClickStreamImpl();
}
