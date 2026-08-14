import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import '../p5r_styled_panel.dart';

/// Surface container that adapts to the active style pack.
class CorpusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;

  const CorpusCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final edgePadding = padding ?? const EdgeInsets.all(16);
    final bg = color ?? cs.surface;

    Widget content;
    if (ext.useDynamicFrames) {
      content = P5rStyledPanel(
        backgroundColor: bg,
        padding: edgePadding,
        child: child,
      );
    } else {
      content = Material(
        color: bg,
        elevation: Theme.of(context).cardTheme.elevation ?? 2,
        shadowColor: Theme.of(context).cardTheme.shadowColor,
        borderRadius: ext.radiusMedium,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: edgePadding, child: child),
      );
    }

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    return content;
  }
}
