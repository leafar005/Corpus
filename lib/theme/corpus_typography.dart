import 'package:flutter/material.dart';

import 'corpus_theme_extension.dart';

/// Central typography helpers for Corpus style packs.
class CorpusTypography {
  CorpusTypography._();

  static List<String> _fallbackFor(String? fontFamily) {
    return switch (fontFamily) {
      'Archivo Black' => const ['Impact', 'Arial Black', 'Syne', 'sans-serif'],
      _ => const ['Syne', 'sans-serif'],
    };
  }

  static TextTheme? textThemeFor(String? fontFamily, Brightness brightness) {
    if (fontFamily == null) return null;
    final base = ThemeData(brightness: brightness).textTheme;
    final theme = base.apply(fontFamily: fontFamily);
    return _applyFeatures(
      theme,
      fallback: _fallbackFor(fontFamily),
    );
  }

  static TextTheme _applyFeatures(
    TextTheme theme, {
    List<String>? fallback,
  }) {
    const features = [
      FontFeature.liningFigures(),
      FontFeature.tabularFigures(),
    ];
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      displaySmall: theme.displaySmall?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      bodyMedium: theme.bodyMedium?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      bodySmall: theme.bodySmall?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontFeatures: features,
        fontFamilyFallback: fallback,
      ),
    );
  }

  static TextStyle style({
    required String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: _fallbackFor(fontFamily),
      fontSize: fontSize,
      fontWeight: fontFamily == 'Archivo Black'
          ? (fontWeight ?? FontWeight.w400)
          : fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: const [
        FontFeature.liningFigures(),
        FontFeature.tabularFigures(),
      ],
    );
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
    final resolvedBase =
        base ?? theme.textTheme.bodyMedium ?? const TextStyle();

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

  static Future<void> preloadFonts(Iterable<String?> families) async {}
}
