// lib/utils/web_js.dart
//
// Helper para interactuar con el DOM / window desde Dart en Flutter Web.
// En plataformas nativas estas funciones son no-ops.

import 'dart:async';

import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'url_utils_stub.dart' if (dart.library.html) 'dart:html' as html;

/// Dispara el evento 'corpus-ready' en el window del navegador.
/// Esto le indica al splash screen HTML que ya puede desvanecerse.
///
/// Solo tiene efecto en Flutter Web; en nativo es una no-op.
void dispatchCorpusReady() {
  if (!kIsWeb) return;
  try {
    html.window.dispatchEvent(html.Event('corpus-ready'));
  } catch (e) {
    debugPrint('[WebJs] Error disparando corpus-ready: $e');
  }
}

/// Pathname actual del navegador (ej. `/actividad`). Null fuera de web.
String? getWebPathname() {
  if (!kIsWeb) return null;
  try {
    return html.window.location.pathname;
  } catch (e) {
    debugPrint('[WebJs] Error leyendo pathname: $e');
    return null;
  }
}

/// Actualiza la URL del navegador sin recargar la página.
/// Conserva los query params actuales (p.ej. `?style=persona5`).
void setWebPath(String path, {bool replace = false}) {
  if (!kIsWeb) return;
  Future.microtask(() {
    try {
      final search = html.window.location.search;
      final url = '$path$search';
      if (replace) {
        html.window.history.replaceState(null, '', url);
      } else {
        html.window.history.pushState(null, '', url);
      }
    } catch (e) {
      debugPrint('[WebJs] Error actualizando path: $e');
    }
  });
}

/// Escucha el botón atrás/adelante del navegador.
Stream<void> webPopStateStream() {
  if (!kIsWeb) return const Stream.empty();
  return html.window.onPopState.map((_) {});
}
