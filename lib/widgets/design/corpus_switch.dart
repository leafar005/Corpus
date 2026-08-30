import 'package:flutter/material.dart';

import '../../theme/corpus_typography.dart';
import '../../theme/corpus_theme_extension.dart';

/// Themed switch with optional label and subtitle.
class CorpusSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;

  const CorpusSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: cs.onPrimary,
      activeTrackColor: cs.primary,
    );

    if (label == null) return switchWidget;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label!,
                style: CorpusTypography.display(
                  context,
                  ext,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        switchWidget,
      ],
    );
  }
}
