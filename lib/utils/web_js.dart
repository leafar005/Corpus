// lib/utils/web_js.dart
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

void setWebPath(
  String path, {
  bool replace = false,
  Map<String, Object?>? state,
}) {
  if (!kIsWeb) return;
  try {
    final search = html.window.location.search;
    final url = '$path$search';
    // Flutter Web requiere que el objeto history.state tenga la propiedad
    // 'serialCount' para su router interno, de lo contrario da un assertion error.
    dynamic currentState = html.window.history.state;
    int serialCount = 0;
    if (currentState != null &&
        js_util.hasProperty(currentState, 'serialCount')) {
      final dynamic rawSerial = js_util.getProperty(currentState, 'serialCount');
      if (rawSerial is num) {
        serialCount = rawSerial.toInt();
      } else if (rawSerial is String) {
        serialCount = int.tryParse(rawSerial) ?? 0;
      }
    }

    if (!replace) {
      serialCount += 1;
    }

    final stateMap = <String, dynamic>{'serialCount': serialCount};
    if (state != null) {
      stateMap.addAll(state);
    }

    final jsState = js_util.jsify(stateMap);

    if (replace) {
      html.window.history.replaceState(jsState, '', url);
    } else {
      html.window.history.pushState(jsState, '', url);
    }
  } catch (e) {
    debugPrint('[WebJs] Error actualizando path: $e');
  }
}

Map<String, Object?>? readWebHistoryState(Object? rawState) {
  if (rawState == null) return null;
  try {
    if (rawState is String) {
      final decoded = jsonDecode(rawState);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } else {
      final dynamic decoded = js_util.dartify(rawState);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
      
      // Fallback: Si dartify no devuelve un Map (por temas de prototipos de JS), 
      // leemos las propiedades directamente.
      if (js_util.hasProperty(rawState, 'tab')) {
        return {
          'tab': js_util.getProperty(rawState, 'tab'),
          'depth': js_util.getProperty(rawState, 'depth'),
          'token': js_util.getProperty(rawState, 'token'),
          'serialCount': js_util.hasProperty(rawState, 'serialCount') 
              ? js_util.getProperty(rawState, 'serialCount') 
              : null,
        };
      }
    }
  } catch (e) {
    debugPrint('[WebJs] Error leyendo history.state: $e');
  }
  return null;
}

Stream<Map<String, Object?>?> webPopStateStream() {
  if (!kIsWeb) return const Stream.empty();
  return html.window.onPopState.map(
    (event) => readWebHistoryState(event.state),
  );
}

void goBackInBrowserHistory() {
  if (!kIsWeb) return;
  html.window.history.back();
}
