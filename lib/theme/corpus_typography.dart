import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'corpus_theme_extension.dart';

/// Central typography helpers for Corpus style packs.
class CorpusTypography {
  CorpusTypography._();

  static TextTheme? textThemeFor(String? fontFamily, Brightness brightness) {
    if (fontFamily == null) return null;
    final base = ThemeData(brightness: brightness).textTheme;

    final theme = switch (fontFamily) {
      'Syne' => GoogleFonts.syneTextTheme(base),
      'Archivo Black' => GoogleFonts.archivoBlackTextTheme(base),
      _ => _googleOrBundled(fontFamily, base),
    };

    return _applyFeatures(theme);
  }

  static TextTheme _applyFeatures(TextTheme theme) {
    const features = [FontFeature.liningFigures(), FontFeature.tabularFigures()];
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(fontFeatures: features),
      displayMedium: theme.displayMedium?.copyWith(fontFeatures: features),
      displaySmall: theme.displaySmall?.copyWith(fontFeatures: features),
      headlineLarge: theme.headlineLarge?.copyWith(fontFeatures: features),
      headlineMedium: theme.headlineMedium?.copyWith(fontFeatures: features),
      headlineSmall: theme.headlineSmall?.copyWith(fontFeatures: features),
      titleLarge: theme.titleLarge?.copyWith(fontFeatures: features),
      titleMedium: theme.titleMedium?.copyWith(fontFeatures: features),
      titleSmall: theme.titleSmall?.copyWith(fontFeatures: features),
      bodyLarge: theme.bodyLarge?.copyWith(fontFeatures: features),
      bodyMedium: theme.bodyMedium?.copyWith(fontFeatures: features),
      bodySmall: theme.bodySmall?.copyWith(fontFeatures: features),
      labelLarge: theme.labelLarge?.copyWith(fontFeatures: features),
      labelMedium: theme.labelMedium?.copyWith(fontFeatures: features),
      labelSmall: theme.labelSmall?.copyWith(fontFeatures: features),
    );
  }

  static TextTheme _googleOrBundled(String fontFamily, TextTheme base) {
    try {
      return GoogleFonts.getTextTheme(fontFamily, base);
    } catch (_) {
      return base.apply(fontFamily: fontFamily);
    }
  }

  static TextStyle style({
    required String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: const [
        FontFeature.liningFigures(),
        FontFeature.tabularFigures(),
      ],
    );

    return switch (fontFamily) {
      'Syne' => GoogleFonts.syne(textStyle: textStyle).copyWith(color: color),
      'Archivo Black' => GoogleFonts.archivoBlack(
        textStyle: textStyle.copyWith(fontWeight: FontWeight.w400),
      ).copyWith(color: color),
      _ => textStyle,
    };
  }

  static TextStyle fromTheme(
    BuildContext context, {
    TextStyle? base,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final theme = Theme.of(context);
    final family =
        theme.textTheme.bodyMedium?.fontFamily ??
        theme.textTheme.labelLarge?.fontFamily;
    final resolvedBase = base ?? theme.textTheme.bodyMedium ?? const TextStyle();

    return style(
      fontFamily: family,
      fontSize: fontSize ?? resolvedBase.fontSize,
      fontWeight: fontWeight ?? resolvedBase.fontWeight,
      color: color ?? resolvedBase.color,
      height: height ?? resolvedBase.height,
      letterSpacing: letterSpacing ?? resolvedBase.letterSpacing,
    );
  }

  /// Pack-aware UI text. Corpus Classic uses the same body font as subtitles;
  /// display packs (e.g. P5R) keep their own hero/display family.
  static TextStyle display(
    BuildContext context,
    CorpusThemeExtension ext, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (ext.useDynamicFrames) {
      return style(
        fontFamily: ext.heroFontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight ?? ext.heroFontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return fromTheme(
      context,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static Future<void> preloadFonts(Iterable<String?> families) async {
    final pending = <Future<void>>[];
    for (final family in families) {
      switch (family) {
        case 'Syne':
          pending.add(GoogleFonts.pendingFonts([GoogleFonts.syne()]));
        case 'Archivo Black':
          pending.add(
            GoogleFonts.pendingFonts([GoogleFonts.archivoBlack()]),
          );
        default:
          break;
      }
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }
}
