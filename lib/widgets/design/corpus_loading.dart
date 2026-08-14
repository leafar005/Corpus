import 'package:flutter/material.dart';

import '../../theme/corpus_typography.dart';
import '../../theme/corpus_theme_extension.dart';

/// Loading indicator — inline or centered full-area.
class CorpusLoadingIndicator extends StatelessWidget {
  final String? label;
  final bool expand;
  final double strokeWidth;

  const CorpusLoadingIndicator({
    super.key,
    this.label,
    this.expand = false,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final spinner = SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: cs.primary,
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinner,
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: CorpusTypography.display(
              context,
              ext,
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (expand) {
      return Center(child: content);
    }
    return content;
  }
}
