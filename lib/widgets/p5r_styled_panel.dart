import 'package:flutter/material.dart';

import '../theme/corpus_theme_extension.dart';
import 'p5r_dynamic_frame.dart';

/// Collage-style panel: offset shadow layers + animated jagged fill, static content.
class P5rStyledPanel extends StatelessWidget {
  static const Color defaultBackground = Color(0xFF141414);

  final Widget child;
  final Color backgroundColor;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double tilt;

  const P5rStyledPanel({
    super.key,
    required this.child,
    this.backgroundColor = defaultBackground,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.tilt = -0.028,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(6, 5),
                child: const P5rStaticBackground(
                  backgroundColor: Colors.black,
                  frame: 4,
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(-3, -2),
                child: P5rStaticBackground(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  frame: 2,
                ),
              ),
            ),
            P5rDynamicFrame(
              backgroundColor: backgroundColor,
              borderColor: Colors.black,
              borderWidth: 2,
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small jagged label chip (black cut-out behind text).
class P5rTextBadge extends StatelessWidget {
  static const Color defaultTextColor = Color(0xFFFFD400);

  final String text;
  final Color textColor;
  final Color backgroundColor;

  const P5rTextBadge({
    super.key,
    required this.text,
    this.textColor = defaultTextColor,
    this.backgroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return P5rDynamicFrame(
      backgroundColor: backgroundColor,
      borderColor: Colors.white,
      borderWidth: 1,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Card/panel that switches between Material surface and P5R styled panel.
class CorpusStyledPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const CorpusStyledPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    if (ext.useDynamicFrames) {
      return P5rStyledPanel(
        margin: margin is EdgeInsets ? margin as EdgeInsets : EdgeInsets.zero,
        padding: padding is EdgeInsets
            ? padding as EdgeInsets
            : const EdgeInsets.all(16),
        backgroundColor: backgroundColor ?? P5rStyledPanel.defaultBackground,
        child: child,
      );
    }

    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: ext.radiusLarge,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: ext.radiusLarge,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}
