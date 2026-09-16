import 'dart:async';
import 'dart:ui';

/// A reusable debouncer that replaces the duplicated `Timer? _debounce`
/// pattern found across 5+ widgets.
///
/// Usage:
/// ```dart
/// final _debouncer = Debouncer();
///
/// void _onSearchChanged(String query) {
///   _debouncer.run(() => _performSearch(query));
/// }
///
/// @override
/// void dispose() {
///   _debouncer.dispose();
///   super.dispose();
/// }
/// ```
///
/// See: audit hallazgo I-02.
class Debouncer {
  /// Creates a debouncer with the given [duration] (default 500ms).
  Debouncer({this.duration = const Duration(milliseconds: 500)});

  /// The debounce delay.
  final Duration duration;

  Timer? _timer;

  /// Schedules [action] to run after [duration]. Cancels any pending action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancels any pending action without disposing the debouncer.
  void cancel() => _timer?.cancel();

  /// Cancels any pending action. Safe to call multiple times.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
