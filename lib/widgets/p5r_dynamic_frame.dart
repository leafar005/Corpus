import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Default cadence for P5R jagged-frame swaps (slower = less visual noise).
const Duration kP5rFrameInterval = Duration(milliseconds: 1800);

/// Animated P5R jagged shape — background only (no child transform).
class P5rDynamicBackground extends StatefulWidget {
  final Color backgroundColor;
  final Duration interval;
  final Color? borderColor;
  final double borderWidth;

  const P5rDynamicBackground({
    super.key,
    required this.backgroundColor,
    this.interval = kP5rFrameInterval,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  State<P5rDynamicBackground> createState() => _P5rDynamicBackgroundState();
}

class _P5rDynamicBackgroundState extends State<P5rDynamicBackground> {
  static const int _frameCount = 6;

  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) {
        setState(() => _frame = (_frame + 1) % _frameCount);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = _rotationForFrame(_frame);
    final skew = _skewForFrame(_frame);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(angle)
        ..setEntry(0, 1, skew),
      child: ClipPath(
        clipper: _P5rShapeClipper(_frame),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: widget.borderWidth > 0 && widget.borderColor != null
                ? Border.all(
                    color: widget.borderColor!,
                    width: widget.borderWidth,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  static double _rotationForFrame(int frame) {
    const angles = [0.0, 0.035, -0.03, 0.05, -0.045, 0.02];
    return angles[frame % angles.length];
  }

  static double _skewForFrame(int frame) {
    const skews = [0.0, 0.04, -0.035, 0.05, -0.04, 0.025];
    return skews[frame % skews.length];
  }
}

/// P5R-style container: animated background, static legible content on top.
class P5rDynamicFrame extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Duration interval;
  final Color? borderColor;
  final double borderWidth;

  const P5rDynamicFrame({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.interval = kP5rFrameInterval,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: P5rDynamicBackground(
            backgroundColor: backgroundColor,
            interval: interval,
            borderColor: borderColor,
            borderWidth: borderWidth,
          ),
        ),
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

class _P5rShapeClipper extends CustomClipper<Path> {
  final int frame;

  _P5rShapeClipper(this.frame);

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final cut = math.min(10.0, math.min(w, h) * 0.12);

    switch (frame % 6) {
      case 0:
        return Path()..addRect(Rect.fromLTWH(0, 0, w, h));
      case 1:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w - cut, 0)
          ..lineTo(w, cut)
          ..lineTo(w, h)
          ..lineTo(cut, h)
          ..lineTo(0, h - cut)
          ..close();
      case 2:
        return Path()
          ..moveTo(cut, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h - cut)
          ..lineTo(w - cut, h)
          ..lineTo(0, h)
          ..lineTo(0, cut)
          ..close();
      case 3:
        return Path()
          ..moveTo(0, cut)
          ..lineTo(cut, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
      case 4:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h - cut)
          ..lineTo(w - cut * 1.5, h)
          ..lineTo(0, h)
          ..close();
      case 5:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(w - cut * 1.2, 0)
          ..lineTo(w, cut * 0.8)
          ..lineTo(w, h)
          ..lineTo(cut, h)
          ..lineTo(0, h - cut * 0.8)
          ..close();
      default:
        return Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    }
  }

  @override
  bool shouldReclip(covariant _P5rShapeClipper oldClipper) =>
      oldClipper.frame != frame;
}

/// Fixed jagged shape (no animation timer) for shadow layers.
class P5rStaticBackground extends StatelessWidget {
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final int frame;

  const P5rStaticBackground({
    super.key,
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.frame = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _P5rShapeClipper(frame),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderWidth > 0 && borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
        ),
      ),
    );
  }
}
