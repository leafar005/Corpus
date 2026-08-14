import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import 'corpus_pointer.dart';

/// Classic connected tab bar — inactive tabs on a muted strip, active tab
/// merges into the content panel below (see reference wireframe).
///
/// Pass [child] to render the panel under the selected tab. Without [child],
/// only the tab headers are shown (useful in scrollable page layouts).
class CorpusTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<IconData>? icons;
  final Widget? child;
  final EdgeInsetsGeometry contentPadding;
  final bool isScrollable;

  const CorpusTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    this.child,
    this.contentPadding = const EdgeInsets.all(20),
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final borderColor = cs.outlineVariant;
    final inactiveBg = cs.surfaceContainerHighest;
    final activeBg = cs.surface;

    final tabRow = _CorpusTabRow(
      labels: labels,
      icons: icons,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      isScrollable: isScrollable,
      borderColor: borderColor,
      inactiveBg: inactiveBg,
      activeBg: activeBg,
      primaryColor: cs.primary,
      useDynamicFrames: ext.useDynamicFrames,
    );

    if (child == null) return tabRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabRow,
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          decoration: BoxDecoration(
            color: activeBg,
            border: Border(
              left: BorderSide(color: borderColor),
              right: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          padding: contentPadding,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(selectedIndex),
              child: child!,
            ),
          ),
        ),
      ],
    );
  }
}

class _CorpusTabRow extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isScrollable;
  final Color borderColor;
  final Color inactiveBg;
  final Color activeBg;
  final Color primaryColor;
  final bool useDynamicFrames;

  const _CorpusTabRow({
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onChanged,
    required this.isScrollable,
    required this.borderColor,
    required this.inactiveBg,
    required this.activeBg,
    required this.primaryColor,
    required this.useDynamicFrames,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) {
        final prevSelected = i - 1 == selectedIndex;
        final nextSelected = i == selectedIndex;
        if (!prevSelected && !nextSelected) {
          tabs.add(
            Container(width: 1, color: borderColor.withValues(alpha: 0.8)),
          );
        }
      }

      tabs.add(
        _CorpusTabHeader(
          label: labels[i],
          icon: icons != null && i < icons!.length ? icons![i] : null,
          selected: i == selectedIndex,
          onTap: () => onChanged(i),
          borderColor: borderColor,
          inactiveBg: inactiveBg,
          activeBg: activeBg,
          primaryColor: primaryColor,
          useDynamicFrames: useDynamicFrames,
          isFirst: i == 0,
          isLast: i == labels.length - 1,
        ),
      );
    }

    Widget row;
    if (isScrollable) {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: tabs,
          ),
        ),
      );
    } else {
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _CorpusTabHeader(
                label: labels[i],
                icon: icons != null && i < icons!.length ? icons![i] : null,
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
                borderColor: borderColor,
                inactiveBg: inactiveBg,
                activeBg: activeBg,
                primaryColor: primaryColor,
                useDynamicFrames: useDynamicFrames,
                isFirst: i == 0,
                isLast: i == labels.length - 1,
              ),
            ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: inactiveBg,
        border: Border(
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
      ),
      child: row,
    );
  }
}

class _CorpusTabHeader extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color borderColor;
  final Color inactiveBg;
  final Color activeBg;
  final Color primaryColor;
  final bool useDynamicFrames;
  final bool isFirst;
  final bool isLast;

  const _CorpusTabHeader({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    required this.borderColor,
    required this.inactiveBg,
    required this.activeBg,
    required this.primaryColor,
    required this.useDynamicFrames,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_CorpusTabHeader> createState() => _CorpusTabHeaderState();
}

class _CorpusTabHeaderState extends State<_CorpusTabHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final fg = widget.selected
        ? cs.onSurface
        : (_hovered ? cs.onSurface : cs.onSurfaceVariant);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          widget.label,
          style: CorpusTypography.display(
            context,
            ext,
            fontSize: 14,
            fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            color: fg,
          ),
        ),
      ],
    );

    return CorpusPointer(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.only(bottom: widget.selected ? -1 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? widget.activeBg
                  : (_hovered
                        ? widget.inactiveBg.withValues(alpha: 0.85)
                        : widget.inactiveBg),
              border: Border(
                top: BorderSide(
                  color: widget.selected ? widget.primaryColor : widget.borderColor,
                  width: widget.selected ? (widget.useDynamicFrames ? 4 : 3) : 1,
                ),
                left: widget.isFirst || widget.selected
                    ? BorderSide(color: widget.borderColor)
                    : BorderSide.none,
                right: widget.isLast || widget.selected
                    ? BorderSide(color: widget.borderColor)
                    : BorderSide.none,
                bottom: widget.selected
                    ? BorderSide(color: widget.activeBg, width: 1)
                    : BorderSide(color: widget.borderColor),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
