import 'dart:js_interop';
import 'package:flutter/material.dart';

@JS('__corpusSyncTheme')
external JSFunction? get _corpusSyncThemeFn;

@JS('__corpusSyncTheme')
external void _corpusSyncTheme(JSString bgHex, JSBoolean isDark);

@JS('__corpusGetSafeAreaInsets')
external JSFunction? get _corpusGetSafeAreaInsetsFn;

@JS('__corpusGetSafeAreaInsets')
external JSArray<JSNumber>? _corpusGetSafeAreaInsets();

/// Syncs the web page `html`/`body` background color, `color-scheme`, and
/// `<meta name="theme-color">` with the active Flutter [ThemeData].
void syncWebThemeChrome(Color backgroundColor, Brightness brightness) {
  try {
    if (_corpusSyncThemeFn == null) return;
    final hex = backgroundColor
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    _corpusSyncTheme('#$hex'.toJS, (brightness == Brightness.dark).toJS);
  } catch (e) {
    debugPrint('[WebViewportSync] Error syncing theme chrome: $e');
  }
}

/// Reads CSS `env(safe-area-inset-*)` values from the host `#corpus-safe-area-probe`
/// element and maps `[top, right, bottom, left]` to Flutter [EdgeInsets].
EdgeInsets getWebSafeAreaInsets() {
  try {
    if (_corpusGetSafeAreaInsetsFn == null) return EdgeInsets.zero;
    final raw = _corpusGetSafeAreaInsets();
    if (raw == null) return EdgeInsets.zero;
    final list = raw.toDart;
    if (list.length < 4) return EdgeInsets.zero;
    final top = list[0].toDartDouble.clamp(0.0, double.infinity);
    final right = list[1].toDartDouble.clamp(0.0, double.infinity);
    final bottom = list[2].toDartDouble.clamp(0.0, double.infinity);
    final left = list[3].toDartDouble.clamp(0.0, double.infinity);
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  } catch (e) {
    debugPrint('[WebViewportSync] Error reading safe-area insets: $e');
    return EdgeInsets.zero;
  }
}
