import 'package:flutter/material.dart';

class MilestoneProgressBar extends StatelessWidget {
  final int current;
  final List<Map<String, dynamic>> milestones;
  final Color color;
  final Color backgroundColor;

  const MilestoneProgressBar({
    super.key,
    required this.current,
    required this.milestones,
    required this.color,
    required this.backgroundColor,
  });

  static Color getSegmentColor(
    int index,
    int totalMilestones,
    Color fallbackColor,
  ) {
    if (totalMilestones <= 1) return fallbackColor;

    int tier = index + 1; // 1=Bronce, 2=Plata, 3=Oro
    if (totalMilestones == 2 && tier == 2) {
      tier = 3;
    }

    switch (tier) {
      case 3:
        return const Color(0xFFFFD700); // Dorado
      case 2:
        return const Color(0xFFC0C0C0); // Plata
      case 1:
        return const Color(0xFFCD7F32); // Bronce
      default:
        return fallbackColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    List<Widget> textSegments = [];
    int prevTarget = 0;

    for (var i = 0; i < milestones.length; i++) {
      final m = milestones[i];
      final target = m['target'] as int;
      final xp = m['xp'] as int;
      final gap = target - prevTarget;

      final Color segmentColor = getSegmentColor(i, milestones.length, color);

      textSegments.add(
        Expanded(
          flex: gap,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$target 🎮 • $xp XP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: current >= target
                    ? segmentColor
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      );

      prevTarget = target;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: textSegments),
        const SizedBox(height: 6),
        SizedBox(
          height: 10, // Thicker bar
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              5,
            ), // Redondea solo los extremos de la barra entera
            child: CustomPaint(
              painter: _MilestoneBarPainter(
                current: current,
                milestones: milestones,
                color: color,
                backgroundColor: backgroundColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MilestoneBarPainter extends CustomPainter {
  final int current;
  final List<Map<String, dynamic>> milestones;
  final Color color;
  final Color backgroundColor;

  _MilestoneBarPainter({
    required this.current,
    required this.milestones,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (milestones.isEmpty) return;

    final maxTarget = milestones.last['target'] as int;
    if (maxTarget <= 0) return;

    final bgPaint = Paint()..color = backgroundColor;

    final double h = size.height;
    final double h2 = h / 2.0;
    const double g2 = 1.5; // Half of the gap width (3.0 total)

    int prevTarget = 0;
    for (int i = 0; i < milestones.length; i++) {
      final target = milestones[i]['target'] as int;
      final gap = target - prevTarget;

      final startX = (prevTarget / maxTarget) * size.width;
      final endX = (target / maxTarget) * size.width;

      final bool isFirst = i == 0;
      final bool isLast = i == milestones.length - 1;

      final Color segmentColor = MilestoneProgressBar.getSegmentColor(
        i,
        milestones.length,
        color,
      );
      final fillPaint = Paint()..color = segmentColor;

      // Calculate progress in this segment
      double segmentProgress = 0.0;
      if (current >= target) {
        segmentProgress = 1.0;
      } else if (current > prevTarget) {
        segmentProgress = (current - prevTarget) / gap;
      }

      // Build the background path for this segment
      Path bgPath = Path();

      // Top-left
      if (isFirst) {
        bgPath.moveTo(0, 0);
      } else {
        bgPath.moveTo(startX + g2 + h2, 0);
      }

      // Top-right
      if (isLast) {
        bgPath.lineTo(size.width, 0);
      } else {
        bgPath.lineTo(endX - g2 + h2, 0);
      }

      // Bottom-right
      if (isLast) {
        bgPath.lineTo(size.width, h);
      } else {
        bgPath.lineTo(endX - g2 - h2, h);
      }

      // Bottom-left
      if (isFirst) {
        bgPath.lineTo(0, h);
      } else {
        bgPath.lineTo(startX + g2 - h2, h);
      }

      bgPath.close();

      // Draw segment background
      canvas.drawPath(bgPath, bgPaint);

      // Draw segment foreground if there is progress
      if (segmentProgress > 0) {
        if (segmentProgress == 1.0) {
          canvas.drawPath(bgPath, fillPaint);
        } else {
          double currentX = startX + (endX - startX) * segmentProgress;

          Path fillPath = Path();

          // Top-left
          if (isFirst) {
            fillPath.moveTo(0, 0);
          } else {
            fillPath.moveTo(startX + g2 + h2, 0);
          }

          // Slanted right edge for the fill
          fillPath.lineTo(currentX + h2, 0);
          fillPath.lineTo(currentX - h2, h);

          // Bottom-left
          if (isFirst) {
            fillPath.lineTo(0, h);
          } else {
            fillPath.lineTo(startX + g2 - h2, h);
          }

          fillPath.close();

          canvas.save();
          canvas.clipPath(bgPath);
          canvas.drawPath(fillPath, fillPaint);
          canvas.restore();
        }
      }

      prevTarget = target;
    }
  }

  @override
  bool shouldRepaint(covariant _MilestoneBarPainter oldDelegate) {
    return oldDelegate.current != current ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
