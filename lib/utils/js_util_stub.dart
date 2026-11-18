// lib/utils/js_util_stub.dart
// Stub para 'dart:js_util' en plataformas no web.

dynamic jsify(Object? object) => object;
Object? dartify(Object? object) => object;
bool hasProperty(Object o, Object name) => false;
dynamic getProperty(Object o, Object name) => null;
T callMethod<T>(Object o, Object method, List<Object?> args) =>
    throw UnsupportedError('callMethod not supported on this platform');
Future<T> promiseToFuture<T>(Object jsPromise) =>
    Future<T>.error(UnsupportedError('promiseToFuture not supported'));
