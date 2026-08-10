import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Texto con efecto de máquina de escribir con timing irregular, para que
/// se sienta humano en vez de un tecleo robótico uniforme.
class TypewriterText extends StatefulWidget {
  final List<TextSpan> spans;
  final TextStyle? style;
  final Duration baseCharDuration;
  final bool showCursor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  /// Si es true, muestra el texto completo de golpe, sin animar.
  /// Útil para reutilizar el mismo widget en un sitio donde el texto ya
  /// se escribió una vez y no queremos que retipee.
  final bool instant;

  /// Se llama una vez cuando termina de escribirse todo el texto
  /// (o inmediatamente, tras el primer frame, si [instant] es true).
  final VoidCallback? onComplete;

  /// Renderizado personalizado del texto visible. Si se define, sustituye al
  /// [RichText] por defecto — útil para estilos por letra (p. ej. P5R).
  final Widget Function(BuildContext context, String visibleText, bool finished)?
      customBuilder;

  const TypewriterText({
    super.key,
    required this.spans,
    this.style,
    this.baseCharDuration = const Duration(milliseconds: 38),
    this.showCursor = true,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.instant = false,
    this.onComplete,
    this.customBuilder,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  Timer? _timer;
  int _visibleChars = 0;
  int _totalChars = 0;
  bool _finished = false;

  List<TextSpan> _currentSpans = [];

  late final AnimationController _cursorController;

  String get _plainText => widget.spans.map((s) => s.text ?? '').join();
  String get _currentPlainText => _currentSpans.map((s) => s.text ?? '').join();

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _currentSpans = widget.spans;
    _totalChars = _currentPlainText.length;

    if (widget.instant) {
      _visibleChars = _totalChars;
      _finished = true;
      _cursorController.stop();
      // Deferimos el callback para no llamar setState en el ancestro
      // mientras este widget todavía se está construyendo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete?.call();
      });
    } else {
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (!mounted) return;
    if (_visibleChars >= _totalChars) {
      if (!_finished) {
        _finished = true;
        _cursorController.stop();
        widget.onComplete?.call();
      }
      return;
    }

    final baseMs = widget.baseCharDuration.inMilliseconds;
    double factor = 0.4 + _random.nextDouble() * 1.2; // 40%–160% de la base

    final nextChar = _currentPlainText[_visibleChars];

    // Pequeña pausa extra tras un espacio o salto de línea.
    if (_visibleChars > 0 &&
        (_currentPlainText[_visibleChars - 1] == ' ' ||
            _currentPlainText[_visibleChars - 1] == '\n')) {
      factor += _random.nextDouble() * 1.5;
    }

    // Duda ocasional antes de cualquier carácter.
    if (_random.nextDouble() < 0.05) {
      factor += 2 + _random.nextDouble() * 3;
    }

    // Puntuación un poco más lenta.
    if ('.,!?'.contains(nextChar)) {
      factor += 0.8;
    }

    final delayMs = (baseMs * factor).clamp(8, baseMs * 8).round();

    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _visibleChars++);
      _scheduleNext();
    });
  }

  void _scheduleDelete([int targetChars = 0]) {
    if (!mounted) return;
    if (_visibleChars <= targetChars) {
      _currentSpans = widget.spans;
      _totalChars = _plainText.length;
      _finished = false;
      if (!widget.instant) {
        _scheduleNext();
      } else {
        setState(() {
          _visibleChars = _totalChars;
          _finished = true;
        });
        widget.onComplete?.call();
      }
      return;
    }

    // El borrado es más rápido y constante que el tipeo
    final delayMs = (widget.baseCharDuration.inMilliseconds * 0.4)
        .clamp(5, 20)
        .round();

    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _visibleChars--);
      _scheduleDelete(targetChars);
    });
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldText = oldWidget.spans.map((s) => s.text ?? '').join();
    if (oldText != _plainText) {
      _timer?.cancel();
      if (!widget.instant && _visibleChars > 0) {
        // Buscar prefijo común para no borrar lo que es igual
        int commonPrefixLen = 0;
        final minLen = min(_currentPlainText.length, _plainText.length);
        while (commonPrefixLen < minLen &&
            _currentPlainText[commonPrefixLen] == _plainText[commonPrefixLen]) {
          commonPrefixLen++;
        }

        if (_visibleChars <= commonPrefixLen) {
          // No hace falta borrar, el texto visible coincide con el nuevo
          _currentSpans = widget.spans;
          _totalChars = _plainText.length;
          _finished = false;
          _scheduleNext();
        } else {
          // En lugar de resetear a 0 de golpe, borramos hacia atrás hasta el prefijo común
          _finished = false;
          _cursorController.repeat(reverse: true);
          _scheduleDelete(commonPrefixLen);
        }
      } else {
        // Cambio instantáneo o estaba en 0
        _currentSpans = widget.spans;
        _totalChars = _plainText.length;
        if (widget.instant) {
          _visibleChars = _totalChars;
          _finished = true;
          _cursorController.stop();
        } else {
          _visibleChars = 0;
          _finished = false;
          _scheduleNext();
        }
      }
    } else if (widget.instant && _visibleChars != _totalChars) {
      _visibleChars = _totalChars;
      _finished = true;
      _cursorController.stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  List<InlineSpan> _visibleSpans() {
    final result = <InlineSpan>[];
    int remaining = _visibleChars;
    for (final span in _currentSpans) {
      final text = span.text ?? '';
      if (remaining <= 0) break;
      if (remaining >= text.length) {
        result.add(TextSpan(text: text, style: span.style));
        remaining -= text.length;
      } else {
        result.add(
          TextSpan(text: text.substring(0, remaining), style: span.style),
        );
        remaining = 0;
      }
    }

    if (widget.showCursor && _visibleChars < _totalChars) {
      result.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: FadeTransition(
            opacity: _cursorController,
            child: Container(
              width: 3,
              height: (widget.style?.fontSize ?? 24) * 0.85,
              margin: const EdgeInsets.only(left: 2),
              color: widget.style?.color ?? Colors.white,
            ),
          ),
        ),
      );
    }

    return result;
  }

  String get _visiblePlainText {
    final end = _visibleChars.clamp(0, _currentPlainText.length);
    return _currentPlainText.substring(0, end);
  }

  Widget _buildCursor() {
    return FadeTransition(
      opacity: _cursorController,
      child: Container(
        width: 3,
        height: (widget.style?.fontSize ?? 24) * 0.85,
        margin: const EdgeInsets.only(left: 2, top: 4),
        color: widget.style?.color ?? Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customBuilder != null) {
      final content = widget.customBuilder!(
        context,
        _visiblePlainText,
        _finished,
      );
      if (!widget.showCursor || _finished) return content;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          _buildCursor(),
        ],
      );
    }

    return RichText(
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      text: TextSpan(style: widget.style, children: _visibleSpans()),
    );
  }
}
