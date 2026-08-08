import 'package:flutter/material.dart';

import '../theme/corpus_theme_extension.dart';
import 'p5r_ransom_title.dart';
import 'typewriter_text.dart';

/// Standard section heading — picks pack-specific title treatment automatically.
///
/// Use this for section headers across the app so new style packs can swap
/// title rendering without touching every screen.
class CorpusSectionTitle extends StatelessWidget {
  final String text;
  final double? fontSize;

  const CorpusSectionTitle(
    this.text, {
    super.key,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    if (ext.useDynamicFrames) {
      return P5rRansomTitle(
        text: text,
        baseFontSize: fontSize ?? 24,
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize ?? 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Hero greeting title (e.g. "Bienvenido," + username) — pack-aware typography.
class CorpusHeroTitle extends StatelessWidget {
  final String prefix;
  final String highlight;
  final bool animated;
  final bool instant;
  final VoidCallback? onAnimationComplete;

  const CorpusHeroTitle({
    super.key,
    required this.prefix,
    required this.highlight,
    this.animated = false,
    this.instant = false,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    final baseSize = isPortrait ? ext.heroFontSize * 0.85 : ext.heroFontSize;
    final primary = Theme.of(context).colorScheme.primary;

    if (ext.useDynamicFrames) {
      if (animated) {
        const separator = '\n';
        return TypewriterText(
          instant: instant,
          onComplete: onAnimationComplete,
          spans: [TextSpan(text: '$prefix$separator$highlight')],
          customBuilder: (context, visible, finished) {
            final parts = _splitHeroVisible(prefix, highlight, visible);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parts.$1.isNotEmpty)
                  P5rRansomTitle(
                    text: parts.$1,
                    baseFontSize: baseSize * 0.82,
                  ),
                if (parts.$2.isNotEmpty)
                  P5rRansomTitle(
                    text: parts.$2,
                    baseFontSize: baseSize,
                    color: primary,
                  ),
              ],
            );
          },
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          P5rRansomTitle(
            text: prefix,
            baseFontSize: baseSize * 0.82,
          ),
          P5rRansomTitle(
            text: highlight,
            baseFontSize: baseSize,
            color: primary,
          ),
        ],
      );
    }

    final baseStyle = TextStyle(
      fontFamily: ext.heroFontFamily,
      fontSize: baseSize,
      fontWeight: ext.heroFontWeight,
      height: 1.1,
      letterSpacing: -1,
    );

    if (animated) {
      return TypewriterText(
        instant: instant,
        onComplete: onAnimationComplete,
        style: baseStyle,
        spans: [
          TextSpan(
            text: '$prefix\n',
            style: const TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: highlight,
            style: TextStyle(color: primary),
          ),
        ],
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: '$prefix\n',
            style: const TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: highlight,
            style: TextStyle(color: primary),
          ),
        ],
      ),
    );
  }
}

/// Divide el texto visible del typewriter en prefijo y nombre destacado.
(String, String) _splitHeroVisible(
  String prefix,
  String highlight,
  String visible,
) {
  if (visible.length <= prefix.length) {
    return (visible, '');
  }
  if (visible.length <= prefix.length + 1) {
    return (prefix, '');
  }
  return (prefix, visible.substring(prefix.length + 1));
}
