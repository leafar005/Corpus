import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void dispatchCorpusReadyImpl() {
  try {
    web.window.dispatchEvent(web.Event('corpus-ready'));
  } catch (e) {
    debugPrint('[WebJs] Error disparando corpus-ready: $e');
  }
}

bool _hasCropperGlobal(JSObject windowObj) {
  final cropper = windowObj.getProperty('Cropper'.toJS);
  return cropper != null && !cropper.isUndefinedOrNull;
}

Future<bool> ensureCropperJsLoadedImpl() async {
  try {
    final win = web.window as JSObject;
    if (_hasCropperGlobal(win)) return true;

    final loader = win.getProperty('__loadCropperJs'.toJS);
    if (loader == null || loader.isUndefinedOrNull) {
      return _hasCropperGlobal(win);
    }

    final promiseOrValue = win.callMethodVarArgs('__loadCropperJs'.toJS);
    Object? resolvedValue;
    if (promiseOrValue != null && !promiseOrValue.isUndefinedOrNull) {
      try {
        final future = (promiseOrValue as JSPromise<JSAny?>).toDart;
        final jsResolved = await future.timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
        resolvedValue = jsResolved?.dartify();
      } catch (e) {
        debugPrint('[WebJs] Promise de __loadCropperJs falló: $e');
        return false;
      }
    }

    if (resolvedValue == false) {
      return false;
    }
    return _hasCropperGlobal(win);
  } catch (e) {
    debugPrint('[WebJs] Error cargando CropperJS bajo demanda: $e');
    return false;
  }
}

String? getWebPathnameImpl() {
  try {
    return web.window.location.pathname;
  } catch (e) {
    debugPrint('[WebJs] Error leyendo pathname: $e');
    return null;
  }
}

String? getWebSearchImpl() {
  try {
    return web.window.location.search;
  } catch (e) {
    debugPrint('[WebJs] Error leyendo search: $e');
    return null;
  }
}

String? getWebHashImpl() {
  try {
    return web.window.location.hash;
  } catch (e) {
    debugPrint('[WebJs] Error leyendo hash: $e');
    return null;
  }
}

void setWebHistoryStateImpl(
  String url, {
  required bool replace,
  String? jsonState,
}) {
  try {
    // Mantiene history.state como JSON String plano por compatibilidad con
    // el router interno de Flutter Web.
    final JSAny? jsState = jsonState?.toJS;
    if (replace) {
      web.window.history.replaceState(jsState, '', url);
    } else {
      web.window.history.pushState(jsState, '', url);
    }
  } catch (e) {
    debugPrint('[WebJs] Error actualizando path: $e');
  }
}

Object? _unwrapJsState(JSAny? rawState) {
  if (rawState == null || rawState.isUndefinedOrNull) return null;
  if (rawState.typeofEquals('string')) {
    return (rawState as JSString).toDart;
  }
  return rawState.dartify();
}

Stream<Object?> webPopStateRawStreamImpl() {
  return web.EventStreamProviders.popStateEvent
      .forTarget(web.window)
      .map((event) => _unwrapJsState(event.state));
}

void goBackInBrowserHistoryImpl() {
  web.window.history.back();
}

bool clickExternalAnchorImpl(String safeUrl) {
  final body = web.document.body;
  if (body == null) return false;
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = safeUrl
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  body.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

Stream<Map<String, dynamic>> webNotificationClickStreamImpl() {
  try {
    final navObj = web.window.navigator as JSObject;
    final swAny = navObj.getProperty('serviceWorker'.toJS);
    if (swAny == null || swAny.isUndefinedOrNull) {
      return const Stream.empty();
    }
    final sw = swAny as web.ServiceWorkerContainer;
    return web.EventStreamProviders.messageEvent
        .forTarget(sw)
        .transform(
          StreamTransformer<web.MessageEvent, Map<String, dynamic>>.fromHandlers(
            handleData: (event, sink) {
              try {
                final payload = event.data.dartify();
                if (payload is Map &&
                    payload['type'] == 'CORPUS_NOTIFICATION_CLICK' &&
                    payload['data'] is Map) {
                  sink.add(
                    Map<String, dynamic>.from(payload['data'] as Map),
                  );
                }
              } catch (e) {
                debugPrint('[WebJs] Error leyendo mensaje SW: $e');
              }
            },
          ),
        );
  } catch (e) {
    debugPrint('[WebJs] serviceWorker message stream no disponible: $e');
    return const Stream.empty();
  }
}
