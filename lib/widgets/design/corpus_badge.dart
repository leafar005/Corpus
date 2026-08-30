import 'package:flutter/material.dart';

import '../../theme/corpus_typography.dart';
import '../../theme/corpus_theme_extension.dart';

/// Small label badge for scores, counts and status tags.
class CorpusBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double fontSize;

  const CorpusBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize = 12,
  });

  /// Metacritic-style colour coding.
  factory CorpusBadge.metacritic(int score) {
    Color bg;
    if (score >= 75) {
      bg = const Color(0xFF6C9B3C);
    } else if (score >= 50) {
      bg = const Color(0xFFD4AC0D);
    } else {
      bg = const Color(0xFFB03A2E);
    }
    return CorpusBadge(
      label: '$score',
      backgroundColor: bg,
      foregroundColor: Colors.white,
      fontSize: 11,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final bg = backgroundColor ?? cs.primaryContainer;
    final fg = foregroundColor ?? cs.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: ext.radiusSmall),
      child: Text(
        label,
        style: CorpusTypography.display(
          context,
          ext,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
