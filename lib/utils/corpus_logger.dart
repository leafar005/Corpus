import 'package:flutter/foundation.dart';

/// Logger centralizado de Corpus.
///
/// Proporciona logging estructurado con tags de módulo y niveles de severidad.
/// Silencia automáticamente todos los niveles cuando [kReleaseMode] es `true`,
/// y restringe [debug] exclusivamente a [kDebugMode].
class CorpusLogger {
  CorpusLogger(this.module);

  /// Nombre del módulo (ej. 'ActivityController', 'CorpusRouter').
  final String module;

  /// Mensaje informativo — flujo normal.
  void info(String message) {
    _print('INFO', message);
  }

  /// Advertencia — situación inusual pero recuperable.
  void warning(String message) {
    _print('WARN', message);
  }

  /// Error — algo falló.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) return;
    _print('ERROR', message);
    if (error != null) {
      debugPrint('  ↳ $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('  ↳ $stackTrace');
    }
  }

  /// Debug — solo en modo desarrollo, para tracing detallado.
  void debug(String message) {
    if (!kDebugMode) return;
    _print('DEBUG', message);
  }

  void _print(String level, String message) {
    if (kReleaseMode) return;
    debugPrint('[$module] $level: $message');
  }
}
