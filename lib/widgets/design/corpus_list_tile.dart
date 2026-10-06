import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import 'corpus_pointer.dart';

/// Settings-style list row with pack-aware typography.
class CorpusListTile extends StatelessWidget {
  final CorpusIconKind icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const CorpusListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final tile = ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
      leading: CorpusTablerIcon(icon, color: cs.primary),
      title: Text(
        title,
        style: CorpusTypography.display(
          context,
          ext,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            )
          : null,
      trailing:
          trailing ??
          (showChevron && onTap != null
              ? CorpusTablerIcon(CorpusIconKind.ChevronRight, color: cs.onSurfaceVariant)
              : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );

    if (onTap == null) return tile;

    return CorpusPointer(child: tile);
  }
}
