import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'style_pack.dart';

/// Semantic design tokens that extend [ThemeData] with values not covered
/// by Material's built-in component themes.
///
/// Access from any widget:
/// ```dart
/// final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
/// ```
@immutable
class CorpusThemeExtension extends ThemeExtension<CorpusThemeExtension> {
  final String? heroFontFamily;
  final double heroFontSize;
  final FontWeight heroFontWeight;
  final double borderRadiusSmall;
  final double borderRadiusMedium;
  final double borderRadiusLarge;
  final NavBarStyle navBarStyle;
  final bool useDynamicFrames;

  const CorpusThemeExtension({
    this.heroFontFamily,
    this.heroFontSize = 48,
    this.heroFontWeight = FontWeight.w900,
    this.borderRadiusSmall = 8,
    this.borderRadiusMedium = 12,
    this.borderRadiusLarge = 16,
    this.navBarStyle = NavBarStyle.solid,
    this.useDynamicFrames = false,
  });

  /// Build from a [StylePack].
  factory CorpusThemeExtension.fromPack(StylePack pack) {
    return CorpusThemeExtension(
      heroFontFamily: pack.heroFontFamily,
      heroFontSize: pack.heroFontSize,
      heroFontWeight: pack.heroFontWeight,
      borderRadiusSmall: pack.borderRadiusSmall,
      borderRadiusMedium: pack.borderRadiusMedium,
      borderRadiusLarge: pack.borderRadiusLarge,
      navBarStyle: pack.navBarStyle,
      useDynamicFrames: pack.useDynamicFrames,
    );
  }

  // ── Convenience getters ──────────────────────────────────────────────────

  BorderRadius get radiusSmall => BorderRadius.circular(borderRadiusSmall);
  BorderRadius get radiusMedium => BorderRadius.circular(borderRadiusMedium);
  BorderRadius get radiusLarge => BorderRadius.circular(borderRadiusLarge);

  // ── ThemeExtension contract ──────────────────────────────────────────────

  @override
  CorpusThemeExtension copyWith({
    String? heroFontFamily,
    double? heroFontSize,
    FontWeight? heroFontWeight,
    double? borderRadiusSmall,
    double? borderRadiusMedium,
    double? borderRadiusLarge,
    NavBarStyle? navBarStyle,
    bool? useDynamicFrames,
  }) {
    return CorpusThemeExtension(
      heroFontFamily: heroFontFamily ?? this.heroFontFamily,
      heroFontSize: heroFontSize ?? this.heroFontSize,
      heroFontWeight: heroFontWeight ?? this.heroFontWeight,
      borderRadiusSmall: borderRadiusSmall ?? this.borderRadiusSmall,
      borderRadiusMedium: borderRadiusMedium ?? this.borderRadiusMedium,
      borderRadiusLarge: borderRadiusLarge ?? this.borderRadiusLarge,
      navBarStyle: navBarStyle ?? this.navBarStyle,
      useDynamicFrames: useDynamicFrames ?? this.useDynamicFrames,
    );
  }

  @override
  CorpusThemeExtension lerp(covariant CorpusThemeExtension? other, double t) {
    if (other == null) return this;
    return CorpusThemeExtension(
      heroFontFamily: t < 0.5 ? heroFontFamily : other.heroFontFamily,
      heroFontSize: lerpDouble(heroFontSize, other.heroFontSize, t)!,
      heroFontWeight: t < 0.5 ? heroFontWeight : other.heroFontWeight,
      borderRadiusSmall: lerpDouble(
        borderRadiusSmall,
        other.borderRadiusSmall,
        t,
      )!,
      borderRadiusMedium: lerpDouble(
        borderRadiusMedium,
        other.borderRadiusMedium,
        t,
      )!,
      borderRadiusLarge: lerpDouble(
        borderRadiusLarge,
        other.borderRadiusLarge,
        t,
      )!,
      navBarStyle: t < 0.5 ? navBarStyle : other.navBarStyle,
      useDynamicFrames: t < 0.5 ? useDynamicFrames : other.useDynamicFrames,
    );
  }
}
