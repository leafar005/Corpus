import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

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
  final List<CorpusIconKind>? icons;
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
    final ext = CorpusThemeExtension.of(context);
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor),
              right: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: Material(
            color: activeBg,
            child: Padding(
              padding: contentPadding,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(selectedIndex), child: child!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CorpusTabRow extends StatelessWidget {
  final List<String> labels;
  final List<CorpusIconKind>? icons;
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
  final CorpusIconKind? icon;
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
          CorpusTablerIcon(widget.icon!, size: 16, color: fg),
          const SizedBox(width: 6),
        ],
        DefaultTextStyle.merge(
          style: labelStyle,
          child: Text(widget.label, style: labelStyle),
        ),
      ],
    );

    final paddedContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: content,
    );

    final Widget tabBody = widget.selected
        ? CustomPaint(
            painter: _SelectedTabPainter(
              activeBg: widget.activeBg,
              borderColor: widget.borderColor,
              topCornerRadius: widget.topCornerRadius,
            ),
            child: paddedContent,
          )
        : Container(
            color: _hovered
                ? cs.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            child: paddedContent,
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

class _SelectedTabPainter extends CustomPainter {
  final Color activeBg;
  final Color borderColor;
  final double topCornerRadius;

  const _SelectedTabPainter({
    required this.activeBg,
    required this.borderColor,
    required this.topCornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final maxR = (size.width / 2) < size.height
        ? (size.width / 2)
        : size.height;
    final r = topCornerRadius.clamp(0.0, maxR).toDouble();

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(rrect, Paint()..color = activeBg);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()..moveTo(0.5, size.height);
    if (r > 0.5) {
      path
        ..lineTo(0.5, r)
        ..arcToPoint(
          Offset(r, 0.5),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..lineTo(size.width - r, 0.5)
        ..arcToPoint(
          Offset(size.width - 0.5, r),
          radius: Radius.circular(r),
          clockwise: true,
        )
        ..lineTo(size.width - 0.5, size.height);
    } else {
      path
        ..lineTo(0.5, 0.5)
        ..lineTo(size.width - 0.5, 0.5)
        ..lineTo(size.width - 0.5, size.height);
    }
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SelectedTabPainter oldDelegate) {
    return oldDelegate.activeBg != activeBg ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.topCornerRadius != topCornerRadius;
  }
}
