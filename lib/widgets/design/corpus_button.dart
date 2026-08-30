import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import '../p5r_dynamic_frame.dart';

/// Visual variants for [CorpusButton].
enum CorpusButtonVariant { primary, secondary, outline, ghost, accent }

/// Size presets for [CorpusButton].
enum CorpusButtonSize { small, medium, large }

/// Design-system button that respects the active [StylePack].
///
/// Uses theme tokens ([ColorScheme], [CorpusThemeExtension]) instead of
/// hardcoded colours. When `useDynamicFrames` is enabled (e.g. Persona 5
/// Royal), the button adopts the animated P5R jagged frame.
class CorpusButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final CorpusButtonVariant variant;
  final CorpusButtonSize size;
  final bool expand;
  final bool iconTrailing;

  const CorpusButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = CorpusButtonVariant.primary,
    this.size = CorpusButtonSize.medium,
    this.expand = false,
    this.iconTrailing = false,
  });

  @override
  State<CorpusButton> createState() => _CorpusButtonState();
}

class _CorpusButtonState extends State<CorpusButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final metrics = _metricsFor(widget.size);
    final colors = _colorsFor(widget.variant, cs, _enabled);
    final borderRadius = ext.useDynamicFrames
        ? ext.radiusSmall
        : BorderRadius.circular(999);

    final content = _buildContent(context, ext, colors, metrics);
    final padding = metrics.padding;

    Widget button = _buildInteractiveShell(
      borderRadius: borderRadius,
      backgroundColor: colors.background,
      borderColor: colors.border,
      foregroundColor: colors.foreground,
      padding: padding,
      useDynamicFrames: ext.useDynamicFrames,
      child: content,
    );

    if (widget.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildInteractiveShell({
    required BorderRadius borderRadius,
    required Color backgroundColor,
    required Color? borderColor,
    required Color foregroundColor,
    required EdgeInsets padding,
    required bool useDynamicFrames,
    required Widget child,
  }) {
    final scale = !_enabled
        ? 1.0
        : _pressed
        ? 0.96
        : _hovered
        ? 1.03
        : 1.0;

    final hoverLift = _hovered && !_pressed && _enabled;
    final pressedDepth = _pressed && _enabled;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: _enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: _enabled && (hoverLift || pressedDepth)
                  ? [
                      BoxShadow(
                        color: foregroundColor.withValues(alpha: 0.18),
                        blurRadius: hoverLift ? 14 : 6,
                        offset: Offset(0, hoverLift ? 6 : 2),
                      ),
                    ]
                  : null,
            ),
            child: useDynamicFrames
                ? P5rDynamicFrame(
                    backgroundColor: backgroundColor,
                    padding: padding,
                    borderColor: borderColor ?? Colors.black,
                    borderWidth: borderColor != null ? 2 : 0,
                    child: child,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: borderRadius,
                      border: borderColor != null
                          ? Border.all(color: borderColor, width: 1.5)
                          : null,
                    ),
                    child: Padding(padding: padding, child: child),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CorpusThemeExtension ext,
    _ButtonColors colors,
    _ButtonMetrics metrics,
  ) {
    final label = Text(
      widget.label,
      style: _labelStyle(context, ext, colors.foreground, metrics.fontSize),
    );

    final children = <Widget>[];
    if (widget.icon != null && !widget.iconTrailing) {
      children
        ..add(
          Icon(widget.icon, size: metrics.iconSize, color: colors.foreground),
        )
        ..add(SizedBox(width: metrics.iconGap));
    }
    children.add(widget.expand ? Expanded(child: Center(child: label)) : label);
    if (widget.icon != null && widget.iconTrailing) {
      children
        ..add(SizedBox(width: metrics.iconGap))
        ..add(
          Icon(widget.icon, size: metrics.iconSize, color: colors.foreground),
        );
    }

    return Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: widget.expand
          ? MainAxisAlignment.center
          : MainAxisAlignment.center,
      children: children,
    );
  }

  static TextStyle _labelStyle(
    BuildContext context,
    CorpusThemeExtension ext,
    Color color,
    double fontSize,
  ) {
    return CorpusTypography.display(
      context,
      ext,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.2,
    );
  }

  static _ButtonMetrics _metricsFor(CorpusButtonSize size) {
    return switch (size) {
      CorpusButtonSize.small => const _ButtonMetrics(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        fontSize: 13,
        iconSize: 16,
        iconGap: 6,
      ),
      CorpusButtonSize.medium => const _ButtonMetrics(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        fontSize: 15,
        iconSize: 20,
        iconGap: 8,
      ),
      CorpusButtonSize.large => const _ButtonMetrics(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        fontSize: 17,
        iconSize: 22,
        iconGap: 10,
      ),
    };
  }

  static _ButtonColors _colorsFor(
    CorpusButtonVariant variant,
    ColorScheme cs,
    bool enabled,
  ) {
    final opacity = enabled ? 1.0 : 0.45;

    Color withOpacity(Color color) => color.withValues(alpha: opacity);

    return switch (variant) {
      CorpusButtonVariant.primary => _ButtonColors(
        background: withOpacity(cs.primary),
        foreground: withOpacity(cs.onPrimary),
      ),
      CorpusButtonVariant.secondary => _ButtonColors(
        background: withOpacity(cs.surfaceContainerHighest),
        foreground: withOpacity(cs.onSurface),
        border: withOpacity(cs.outlineVariant),
      ),
      CorpusButtonVariant.outline => _ButtonColors(
        background: Colors.transparent,
        foreground: withOpacity(cs.primary),
        border: withOpacity(cs.primary),
      ),
      CorpusButtonVariant.ghost => _ButtonColors(
        background: Colors.transparent,
        foreground: withOpacity(cs.primary),
      ),
      CorpusButtonVariant.accent => _ButtonColors(
        background: withOpacity(cs.secondary),
        foreground: withOpacity(cs.onSecondary),
      ),
    };
  }
}

class _ButtonMetrics {
  final EdgeInsets padding;
  final double fontSize;
  final double iconSize;
  final double iconGap;

  const _ButtonMetrics({
    required this.padding,
    required this.fontSize,
    required this.iconSize,
    required this.iconGap,
  });
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color? border;

  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });
}
