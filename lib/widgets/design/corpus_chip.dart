import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import '../p5r_dynamic_frame.dart';
import 'corpus_pointer.dart';

enum CorpusChipVariant { choice, filter, action }

/// Pack-aware chip for filters, status tags and quick actions.
class CorpusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final CorpusChipVariant variant;
  final IconData? icon;
  final bool showCheckmark;

  const CorpusChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.variant = CorpusChipVariant.choice,
    this.icon,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    final bg = switch (variant) {
      CorpusChipVariant.action => cs.surfaceContainerHighest,
      CorpusChipVariant.filter => selected ? cs.primary : cs.surface,
      CorpusChipVariant.choice => selected ? cs.primary : cs.surfaceContainerHighest,
    };

    final fg = switch (variant) {
      CorpusChipVariant.action => cs.onSurface,
      CorpusChipVariant.filter => selected ? cs.onPrimary : cs.onSurface,
      CorpusChipVariant.choice => selected ? cs.onPrimary : cs.onSurface,
    };

    final border = selected && variant != CorpusChipVariant.action
        ? cs.primary
        : cs.outlineVariant.withValues(alpha: 0.5);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        if (selected && showCheckmark && variant == CorpusChipVariant.filter) ...[
          Icon(Icons.check, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: CorpusTypography.display(
            context,
            ext,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: fg,
          ),
        ),
      ],
    );

    final padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final borderRadius = ext.useDynamicFrames
        ? ext.radiusSmall
        : BorderRadius.circular(999);

    Widget chip;
    if (ext.useDynamicFrames) {
      chip = P5rDynamicFrame(
        backgroundColor: bg,
        padding: padding,
        borderColor: border,
        borderWidth: 1.5,
        child: content,
      );
    } else {
      chip = DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: borderRadius,
          border: Border.all(color: border, width: 1),
        ),
        child: Padding(padding: padding, child: content),
      );
    }

    return CorpusPointer(
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );
  }
}
