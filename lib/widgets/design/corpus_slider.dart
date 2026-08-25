import 'package:flutter/material.dart';

import '../../theme/corpus_typography.dart';
import '../../theme/corpus_theme_extension.dart';

/// Themed slider — used for ratings and numeric inputs.
class CorpusSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String Function(double)? labelBuilder;
  final ValueChanged<double>? onChanged;

  const CorpusSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 10,
    this.divisions,
    this.label,
    this.labelBuilder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final displayLabel = labelBuilder?.call(value) ?? label ?? value.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || labelBuilder != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              displayLabel,
              style: CorpusTypography.display(
                context,
                ext,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.surfaceContainerHighest,
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
