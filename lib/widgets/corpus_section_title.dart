import 'package:flutter/material.dart';

import '../theme/corpus_theme_extension.dart';
import 'p5r_ransom_title.dart';

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

  const CorpusHeroTitle({
    super.key,
    required this.prefix,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    final baseSize = isPortrait ? ext.heroFontSize * 0.85 : ext.heroFontSize;
    final primary = Theme.of(context).colorScheme.primary;

    if (ext.useDynamicFrames) {
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

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: ext.heroFontFamily,
          fontSize: baseSize,
          fontWeight: ext.heroFontWeight,
          height: 1.1,
          letterSpacing: -1,
        ),
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
