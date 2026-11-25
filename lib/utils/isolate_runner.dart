import 'dart:async';
import 'dart:isolate';

import 'package:corpus/globals.dart';
import 'package:flutter/foundation.dart';

/// Ejecuta [computation] en un Isolate secundario en plataformas nativas.
///
/// En Web (`kIsWeb`) o cuando [kDisableIsolatesForTests] está activo
/// (ej. entorno `FakeAsync` de `testWidgets` en tests E2E), cede un microtúrn
/// y ejecuta de forma síncrona para evitar bloqueos de puertos nativos.
Future<R> runInBackgroundIsolate<R>(R Function() computation) async {
  if (kIsWeb || kDisableIsolatesForTests) {
    await Future<void>.delayed(Duration.zero);
    return computation();
  }
  return Isolate.run(computation);
}
