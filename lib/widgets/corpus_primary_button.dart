import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/corpus_theme_extension.dart';
import 'p5r_dynamic_frame.dart';

/// Primary action button that adapts to the active style pack.
///
/// Use this for hero CTAs ("Editar reseña", "Añadir a Biblioteca", etc.) so
/// they always share the same look within each style pack.
class CorpusPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool expand;
  final double? height;
  final double elevation;

  const CorpusPrimaryButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.expand = false,
    this.height,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primary;
    final fg = foregroundColor ?? cs.onPrimary;
    final contentPadding = padding ??
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    Widget button;
    if (ext.useDynamicFrames) {
      button = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: P5rDynamicFrame(
            backgroundColor: bg,
            padding: contentPadding,
            borderColor: Colors.black,
            borderWidth: 2,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment:
                  expand ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _labelStyle(context, ext, fg),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      button = ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: fg),
        label: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          padding: contentPadding,
          minimumSize: expand
              ? Size(double.infinity, height ?? 50)
              : height != null
                  ? Size(0, height!)
                  : null,
          shape: RoundedRectangleBorder(
            borderRadius: ext.radiusMedium,
          ),
        ),
      );
    }

    if (expand || height != null) {
      button = SizedBox(
        width: expand ? double.infinity : null,
        height: height,
        child: button,
      );
    }

    return button;
  }

  static TextStyle _labelStyle(
    BuildContext context,
    CorpusThemeExtension ext,
    Color color,
  ) {
    if (ext.heroFontFamily == 'Archivo Black') {
      return GoogleFonts.archivoBlack(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );
    }
    return TextStyle(
      color: color,
      fontWeight: FontWeight.bold,
      fontFamily: ext.heroFontFamily,
    );
  }
}
