import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import 'corpus_pointer.dart';

/// Themed icon button with desktop pointer cursor and pack-aware shape.
class CorpusIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CorpusIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<CorpusIconButton> createState() => _CorpusIconButtonState();
}

class _CorpusIconButtonState extends State<CorpusIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;

    final bg = widget.backgroundColor ??
        (enabled && _hovered
            ? cs.primary.withValues(alpha: 0.12)
            : Colors.transparent);
    final fg = widget.foregroundColor ?? cs.onSurface;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ext.radiusMedium,
      ),
      child: Icon(
        widget.icon,
        size: widget.size * 0.5,
        color: enabled ? fg : fg.withValues(alpha: 0.4),
      ),
    );

    button = CorpusPointer(
      enabled: enabled,
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: button,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
