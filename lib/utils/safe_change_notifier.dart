import 'package:flutter/foundation.dart';

/// Base class for controllers that need a safe [notifyListeners] guard.
///
/// Replaces the repetitive `bool _disposed = false` + `void _notify() { ... }`
/// boilerplate in every controller. Subclasses call [notify] instead of
/// [notifyListeners] and override [dispose] with `super.dispose()` at the end.
///
/// See: audit hallazgo M-02.
abstract class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  /// Whether this notifier has been disposed.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safe wrapper around [notifyListeners] that silently no-ops after dispose.
  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }
}
