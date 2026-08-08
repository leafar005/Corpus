import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/corpus_theme_extension.dart';
import 'p5r_dynamic_frame.dart';

/// Primary action button that adapts to the active style pack.
class CorpusPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final EdgeInsets? padding;

  const CorpusPrimaryButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    if (ext.useDynamicFrames) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: P5rDynamicFrame(
            backgroundColor: cs.primary,
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            borderColor: Colors.black,
            borderWidth: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _labelStyle(context, ext, Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: ext.radiusMedium,
        ),
      ),
    );
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
