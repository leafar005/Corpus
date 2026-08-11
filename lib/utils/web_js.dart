// lib/utils/web_js.dart
//
// Helper para interactuar con el DOM / window desde Dart en Flutter Web.
// En plataformas nativas estas funciones son no-ops.

import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.io) 'url_utils_stub.dart';

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
