// lib/utils/web_js.dart
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║                    ⚠️ CRITICAL NAVIGATION CODE                     ║
// ║                                                                      ║
// ║ This file participates directly in the browser history / Flutter     ║
// ║ Web navigation integration.                                          ║
// ║                                                                      ║
// ║ DO NOT refactor, modernize or change history.state representation    ║
// ║ without understanding Flutter Web's internal history handling.       ║
// ║                                                                      ║
// ║ A seemingly harmless change to history.state previously caused       ║
// ║ DOUBLE BACK NAVIGATION and Navigator history corruption.             ║
// ║                                                                      ║
// ║ Before changing this file, reproduce and verify Back navigation on   ║
// ║ Edge + iPhone/Safari and compare against the known-good implementation║
// ║ from commit 809aa8023ad57c186c7c513e62f467fd3ca460fc.                ║
// ╚══════════════════════════════════════════════════════════════════════╝
//
// ============================================================================
// FLUJO COMPLETO DE NAVEGACIÓN "ATRÁS" EN WEB
// ============================================================================
// Usuario pulsa Back en el navegador
//        ↓
// Browser genera popstate event
//        ↓
// webPopStateStream() lo captura
//        ↓
// AppNavigationController procesa el evento
//        ↓
// Actualiza la navegación interna (removeRoute o pop)
//
// No queremos que el router interno nativo de Flutter Web interprete 
// simultáneamente ese mismo historial como una navegación propia independiente, 
// lo cual provocaría dos acciones de navegación (doble pop) por una sola 
// pulsación del usuario. 
//
// `goBackInBrowserHistory()` es el mecanismo utilizado para delegar el 
// retroceso al historial del navegador.
// ============================================================================
//
// Helper para interactuar con el DOM / window desde Dart en Flutter Web.
// En plataformas nativas estas funciones son no-ops.

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'js_util_stub.dart' if (dart.library.js_util) 'dart:js_util' as js_util;

import 'dart:convert';
import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'url_utils_stub.dart' if (dart.library.html) 'dart:html' as html;

void dispatchCorpusReady() {
  if (!kIsWeb) return;
  try {
    html.window.dispatchEvent(html.Event('corpus-ready'));
  } catch (e) {
    debugPrint('[WebJs] Error disparando corpus-ready: $e');
  }
}

String? getWebPathname() {
  if (!kIsWeb) return null;
  try {
    return html.window.location.pathname;
  } catch (e) {
    debugPrint('[WebJs] Error leyendo pathname: $e');
    return null;
  }
}

/// Modifica el historial del navegador insertando o reemplazando una entrada.
/// `pushState` y `replaceState` forman parte de nuestro mecanismo de navegación
/// personalizado.
///
/// ⚠️ WARNING / DO NOT MODIFY CASUALLY
///
/// This code intentionally stores history.state as a JSON String.
///
/// Do NOT change this to a JavaScript object / jsify(), and do NOT add
/// Flutter navigation metadata such as serialCount without first
/// understanding and testing the interaction with Flutter Web's internal
/// Router/Navigator history handling.
///
/// A previous change doing this caused a severe navigation regression:
/// one browser Back action was processed by both Flutter Web and
/// AppNavigationController, resulting in two pops for a single user action.
///
/// This implementation is intentionally fragile and depends on the
/// current interaction between browser history and Flutter Web routing.
///
/// If this code must be changed:
/// 1. Compare against commit 809aa8023ad57c186c7c513e62f467fd3ca460fc.
/// 2. Understand how Flutter Web handles history.state.
/// 3. Verify that Flutter's internal router does not start processing
///    our custom history entries.
/// 4. Test browser Back on Edge and iPhone/Safari.
/// 5. Verify that one Back action produces exactly one navigation.
/// 6. Verify that the Navigator history never reaches an invalid state.
///
/// DO NOT refactor or "modernize" this code just for stylistic reasons.
void setWebPath(
  String path, {
  bool replace = false,
  Map<String, Object?>? state,
}) {
  if (!kIsWeb) return;
  try {
    final search = html.window.location.search;
    final url = '$path$search';
    final jsState = state == null ? null : jsonEncode(state);
    if (replace) {
      html.window.history.replaceState(jsState, '', url);
    } else {
      html.window.history.pushState(jsState, '', url);
    }
  } catch (e) {
    debugPrint('[WebJs] Error actualizando path: $e');
  }
}

/// Lee el estado del historial del navegador.
///
/// Debe ser absolutamente compatible con el formato que escribimos en
/// `setWebPath()`. Actualmente esperamos principalmente un String JSON.
/// Existe el manejo adicional (dartify) por si el estado llegara como objeto
/// (p. ej. modificado por extensiones del navegador o comportamientos legados).
/// Cambiar el formato escrito por `setWebPath()` puede afectar directamente
/// a la navegación.
Map<String, Object?>? readWebHistoryState(Object? rawState) {
  if (rawState == null) return null;
  try {
    if (rawState is String) {
      final decoded = jsonDecode(rawState);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } else {
      final dynamic decoded = js_util.dartify(rawState);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      if (decoded is String) {
        final parsed = jsonDecode(decoded);
        if (parsed is Map) return Map<String, Object?>.from(parsed);
      }
    }
  } catch (e) {
    debugPrint('[WebJs] Error leyendo history.state: $e');
  }
  return null;
}

/// Escucha `window.onPopState`, que representa el evento back/forward del 
/// historial del navegador.
///
/// Este stream es una pieza crítica de la comunicación entre Browser History
/// y `AppNavigationController`. Duplicar listeners aquí o añadir otro 
/// consumidor que también haga `pop()` sobre el Navigator de Flutter provocará 
/// una doble navegación errónea.
Stream<Map<String, Object?>?> webPopStateStream() {
  if (!kIsWeb) return const Stream.empty();
  return html.window.onPopState.map(
    (event) => readWebHistoryState(event.state),
  );
}

/// Llama directamente a `window.history.back()`.
///
/// Esto provoca de forma asíncrona que el navegador dispare un evento `popstate`.
/// NO debe combinarse NUNCA con un `Navigator.pop()` adicional para la misma
/// acción del usuario, ya que el evento asíncrono cerrará la pantalla de 
/// todas formas. Hacer ambos causaría un doble pop.
void goBackInBrowserHistory() {
  if (!kIsWeb) return;
  html.window.history.back();
}
