// lib/widgets/genre_radar_chart.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/genre_time_stat.dart';
import '../utils/igdb_constants.dart';

/// Dibuja un gráfico de araña/radar a partir de estadísticas ya agregadas.
/// [stats] debe tener entre 3 y 6 elementos (lo garantiza GenreRadarCalculator).
class GenreRadarChart extends StatelessWidget {
  final List<GenreTimeStat> stats;
  final ValueChanged<GenreTimeStat>? onGenreTapped;

  const GenreRadarChart({
    super.key,
    required this.stats,
    this.onGenreTapped,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapUp: (details) {
        if (onGenreTapped == null) return;
        final RenderBox box = context.findRenderObject() as RenderBox;
        final center = Offset(box.size.width / 2, box.size.height / 2);
        final radius = math.min(box.size.width, box.size.height) / 2 * _RadarPainter._radiusFraction;
        final n = stats.length;
        for (int i = 0; i < n; i++) {
          final a = -math.pi / 2 + i * (2 * math.pi / n);
          final labelRadius = radius + 22;
          final anchor = Offset(
            center.dx + labelRadius * math.cos(a),
            center.dy + labelRadius * math.sin(a),
          );
          // If tap is near the label anchor point (within ~40 pixels)
          if ((details.localPosition - anchor).distance < 45) {
            onGenreTapped!(stats[i]);
            break;
          }
        }
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadarPainter(
          stats: stats,
          fillColor: scheme.primary.withValues(alpha: 0.28),
          strokeColor: scheme.primary,
          gridColor: scheme.onSurface.withValues(alpha: 0.15),
          labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface, fontSize: 12) ?? TextStyle(color: scheme.onSurface, fontSize: 12),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<GenreTimeStat> stats;
  final Color fillColor;
  final Color strokeColor;
  final Color gridColor;
  final TextStyle labelStyle;

  static const int _ringCount = 4;
  static const double _radiusFraction = 0.55; // equilibrado para aspectRatio 1.35

  _RadarPainter({
    required this.stats,
    required this.fillColor,
    required this.strokeColor,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 * _radiusFraction;
    final n = stats.length;
    if (n == 0) return;

    final maxValue = stats
        .map((s) => s.gameCount.toDouble())
        .fold<double>(0, (a, b) => math.max(a, b));
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    // Ángulo de cada eje: empieza arriba (-90°) y avanza en sentido horario.
    double angleFor(int i) => -math.pi / 2 + i * (2 * math.pi / n);

    // 1. Anillos de fondo (grid concéntrico).
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int ring = 1; ring <= _ringCount; ring++) {
      final r = radius * ring / _ringCount;
      final path = Path();
      for (int i = 0; i <= n; i++) {
        final a = angleFor(i % n);
        final p = Offset(
          center.dx + r * math.cos(a),
          center.dy + r * math.sin(a),
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, gridPaint);
    }

    // 2. Ejes (líneas del centro a cada vértice exterior).
    for (int i = 0; i < n; i++) {
      final a = angleFor(i);
      final end = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawLine(center, end, gridPaint);
    }

    // 3. Polígono de datos (relleno + contorno).
    final dataPath = Path();
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final a = angleFor(i);
      final normalized = (stats[i].gameCount.toDouble() / safeMax).clamp(0.0, 1.0);
      final r = radius * normalized;
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      points.add(p);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = fillColor);
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = strokeColor);
    }

    // 4. Etiquetas de cada eje (nombre del género en español + horas).
    for (int i = 0; i < n; i++) {
      final a = angleFor(i);
      final labelRadius = radius + 22;
      final anchor = Offset(
        center.dx + labelRadius * math.cos(a),
        center.dy + labelRadius * math.sin(a),
      );

      final text = '${IgdbConstants.formatGenreWithEmoji(stats[i].genre)}\n(${stats[i].gameCount} juegos)';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);

      // Centrar horizontalmente salvo en los extremos izquierdo/derecho,
      // donde se ancla al borde correspondiente para no salirse del lienzo.
      final dx = math.cos(a);
      final Offset origin;
      if (dx > 0.3) {
        origin = Offset(anchor.dx, anchor.dy - tp.height / 2);
      } else if (dx < -0.3) {
        origin = Offset(anchor.dx - tp.width, anchor.dy - tp.height / 2);
      } else {
        origin = Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height / 2);
      }
      tp.paint(canvas, origin);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.stats != stats;
}
