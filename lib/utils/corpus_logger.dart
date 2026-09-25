import 'package:flutter/foundation.dart';

/// Logger centralizado de Corpus.
///
/// Proporciona logging estructurado con tags de módulo y niveles de severidad.
/// Internamente usa [debugPrint] (que se elimina en release automáticamente
/// si se usa con Flutter), pero está diseñado para migrar fácilmente a
/// `package:logging` en el futuro sin cambiar los call sites.
///
/// Uso:
/// ```dart
/// // 1. Crear un logger por clase/módulo
/// static final _log = CorpusLogger('ActivityController');
///
/// // 2. Usar los niveles
/// _log.info('Feed loaded with 42 items');
/// _log.warning('Retry attempt 3/5');
/// _log.error('toggleLike failed', error: e, stackTrace: s);
/// ```
///
/// Creado en la auditoría técnica — Fase 3 para reemplazar debugPrint sueltos.
class CorpusLogger {
  CorpusLogger(this.module);

  /// Nombre del módulo (ej. 'ActivityController', 'BundleService').
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
    if (kDebugMode) {
      _print('DEBUG', message);
    }
  }

  void _print(String level, String message) {
    debugPrint('[$module] $level: $message');
  }
}
