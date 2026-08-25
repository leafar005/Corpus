import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import 'corpus_pointer.dart';

/// Connected tab bar — selected tab with rounded top corners merges into the
/// content panel below. Inactive tabs stay transparent.
///
/// Pass [child] to render the panel under the selected tab.
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
    final activeBg = cs.surface;
    final topRadius = ext.borderRadiusLarge > 0 ? ext.borderRadiusLarge : 12.0;

    final tabRow = _CorpusTabRow(
      labels: labels,
      icons: icons,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      isScrollable: isScrollable,
      borderColor: borderColor,
      activeBg: activeBg,
      topCornerRadius: topRadius,
      connectToContent: child != null,
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
  final Color activeBg;
  final double topCornerRadius;
  final bool connectToContent;

  const _CorpusTabRow({
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onChanged,
    required this.isScrollable,
    required this.borderColor,
    required this.activeBg,
    required this.topCornerRadius,
    this.connectToContent = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget row;
    if (isScrollable) {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                _CorpusTabHeader(
                  label: labels[i],
                  icon: icons != null && i < icons!.length ? icons![i] : null,
                  selected: i == selectedIndex,
                  onTap: () => onChanged(i),
                  borderColor: borderColor,
                  activeBg: activeBg,
                  topCornerRadius: topCornerRadius,
                  connectToContent: connectToContent,
                ),
            ],
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
                activeBg: activeBg,
                topCornerRadius: topCornerRadius,
                connectToContent: connectToContent,
              ),
            ),
        ],
      );
    }

    return row;
  }
}

class _CorpusTabHeader extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color borderColor;
  final Color activeBg;
  final double topCornerRadius;
  final bool connectToContent;

  const _CorpusTabHeader({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    required this.borderColor,
    required this.activeBg,
    required this.topCornerRadius,
    this.connectToContent = false,
  });

  @override
  State<_CorpusTabHeader> createState() => _CorpusTabHeaderState();
}

class _CorpusTabHeaderState extends State<_CorpusTabHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Mismo color en todos los estados — solo cambia el peso al seleccionar.
    final fg = cs.onSurface;

    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
      color: fg,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        DefaultTextStyle.merge(
          style: labelStyle,
          child: Text(widget.label, style: labelStyle),
        ),
      ],
    );

    final topRadius = BorderRadius.only(
      topLeft: Radius.circular(widget.topCornerRadius),
      topRight: Radius.circular(widget.topCornerRadius),
    );

    final tabBody = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.selected
            ? widget.activeBg
            : (_hovered
                  ? cs.onSurface.withValues(alpha: 0.06)
                  : Colors.transparent),
        borderRadius: widget.selected ? topRadius : null,
        border: widget.selected
            ? Border(
                left: BorderSide(color: widget.borderColor),
                right: BorderSide(color: widget.borderColor),
                bottom: BorderSide(color: widget.activeBg, width: 1),
              )
            : null,
      ),
      child: content,
    );

    final tabShell = widget.selected && widget.connectToContent
        ? Transform.translate(offset: const Offset(0, 1), child: tabBody)
        : tabBody;

    return CorpusPointer(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: tabShell,
        ),
      ),
    );
  }
}
