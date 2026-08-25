import 'package:flutter/material.dart';

import '../../theme/corpus_typography.dart';
import '../../theme/corpus_theme_extension.dart';

/// Standard block for the design system page and documentation layouts.
class CorpusSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const CorpusSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: CorpusTypography.display(
            context,
            ext,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
