import 'package:flutter/material.dart';

/// Syncs web browser chrome (background and theme-color) to the active theme.
/// No-op on non-web platforms.
void syncWebThemeChrome(Color backgroundColor, Brightness brightness) {}

/// Reads CSS `env(safe-area-inset-*)` values from the web host page.
/// Returns [EdgeInsets.zero] on non-web platforms.
EdgeInsets getWebSafeAreaInsets() => EdgeInsets.zero;
