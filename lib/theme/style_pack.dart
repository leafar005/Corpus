import 'package:flutter/material.dart';

enum NavBarStyle { liquidGlass, solid, minimal, persona5Royal }

/// Describes a complete visual style for the app.
///
/// Each pack defines colours, typography, border radii and navigation-bar
/// appearance.  The built-in "default" pack reproduces the current Corpus look
/// so the migration is invisible to users.
@immutable
class StylePack {
  final String id;
  final String name;
  final String? description;

  // ── Colours ──────────────────────────────────────────────────────────────
  final Color seedColor;
  final Color? scaffoldLight;
  final Color? scaffoldDark;
  final Color? surfaceLight;
  final Color? surfaceDark;
  final Color accentColor;

  // ── Typography ───────────────────────────────────────────────────────────
  final String? fontFamily;
  final String? heroFontFamily;
  final double heroFontSize;
  final FontWeight heroFontWeight;

  // ── Shapes ───────────────────────────────────────────────────────────────
  final double borderRadiusSmall;
  final double borderRadiusMedium;
  final double borderRadiusLarge;

  // ── Navigation bar ───────────────────────────────────────────────────────
  final NavBarStyle navBarStyle;

  // ── P5R-style dynamic frames on buttons / nav ────────────────────────────
  final bool useDynamicFrames;

  /// Relative path inside an imported `.corpuspack` bundle (e.g. `music/theme.m4a`).
  final String? musicFile;

  const StylePack({
    required this.id,
    required this.name,
    this.description,
    required this.seedColor,
    this.scaffoldLight,
    this.scaffoldDark,
    this.surfaceLight,
    this.surfaceDark,
    required this.accentColor,
    this.fontFamily,
    this.heroFontFamily,
    this.heroFontSize = 48,
    this.heroFontWeight = FontWeight.w900,
    this.borderRadiusSmall = 8,
    this.borderRadiusMedium = 12,
    this.borderRadiusLarge = 16,
    this.navBarStyle = NavBarStyle.liquidGlass,
    this.useDynamicFrames = false,
    this.musicFile,
  });

  /// The pack that reproduces the current Corpus UI exactly.
  static StylePack defaultPack() => StylePack(
    id: 'default',
    name: 'Corpus Classic',
    seedColor: Colors.deepPurpleAccent,
    scaffoldLight: const Color(0xFFF5F5F5),
    scaffoldDark: Colors.black,
    surfaceLight: Colors.white,
    surfaceDark: Colors.grey.shade900,
    accentColor: Colors.amber,
    fontFamily: null,
    heroFontFamily: 'Helvetica',
    heroFontSize: 48,
    heroFontWeight: FontWeight.w900,
    borderRadiusSmall: 8,
    borderRadiusMedium: 12,
    borderRadiusLarge: 16,
    navBarStyle: NavBarStyle.liquidGlass,
  );

  // ── Serialisation ────────────────────────────────────────────────────────

  factory StylePack.fromJson(Map<String, dynamic> json) {
    return StylePack(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      seedColor: _colorFromHex(json['seedColor'] as String),
      scaffoldLight: json['scaffoldLight'] != null
          ? _colorFromHex(json['scaffoldLight'] as String)
          : null,
      scaffoldDark: json['scaffoldDark'] != null
          ? _colorFromHex(json['scaffoldDark'] as String)
          : null,
      surfaceLight: json['surfaceLight'] != null
          ? _colorFromHex(json['surfaceLight'] as String)
          : null,
      surfaceDark: json['surfaceDark'] != null
          ? _colorFromHex(json['surfaceDark'] as String)
          : null,
      accentColor: _colorFromHex(json['accentColor'] as String),
      fontFamily: json['fontFamily'] as String?,
      heroFontFamily: json['heroFontFamily'] as String?,
      heroFontSize: (json['heroFontSize'] as num?)?.toDouble() ?? 48,
      heroFontWeight: _fontWeightFromInt(json['heroFontWeight'] as int? ?? 900),
      borderRadiusSmall:
          (json['borderRadiusSmall'] as num?)?.toDouble() ?? 8,
      borderRadiusMedium:
          (json['borderRadiusMedium'] as num?)?.toDouble() ?? 12,
      borderRadiusLarge:
          (json['borderRadiusLarge'] as num?)?.toDouble() ?? 16,
      navBarStyle: _navBarStyleFromString(json['navBarStyle'] as String?),
      useDynamicFrames: json['useDynamicFrames'] as bool? ?? false,
      musicFile: json['musicFile'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'seedColor': _colorToHex(seedColor),
    if (scaffoldLight != null) 'scaffoldLight': _colorToHex(scaffoldLight!),
    if (scaffoldDark != null) 'scaffoldDark': _colorToHex(scaffoldDark!),
    if (surfaceLight != null) 'surfaceLight': _colorToHex(surfaceLight!),
    if (surfaceDark != null) 'surfaceDark': _colorToHex(surfaceDark!),
    'accentColor': _colorToHex(accentColor),
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (heroFontFamily != null) 'heroFontFamily': heroFontFamily,
    'heroFontSize': heroFontSize,
    'heroFontWeight': heroFontWeight.index * 100,
    'borderRadiusSmall': borderRadiusSmall,
    'borderRadiusMedium': borderRadiusMedium,
    'borderRadiusLarge': borderRadiusLarge,
    'navBarStyle': navBarStyle.name,
    'useDynamicFrames': useDynamicFrames,
    if (musicFile != null) 'musicFile': musicFile,
  };

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) buffer.write('FF');
    buffer.write(hex.toUpperCase());
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static FontWeight _fontWeightFromInt(int value) {
    const weights = {
      100: FontWeight.w100,
      200: FontWeight.w200,
      300: FontWeight.w300,
      400: FontWeight.w400,
      500: FontWeight.w500,
      600: FontWeight.w600,
      700: FontWeight.w700,
      800: FontWeight.w800,
      900: FontWeight.w900,
    };
    return weights[value] ?? FontWeight.w900;
  }

  static NavBarStyle _navBarStyleFromString(String? value) {
    if (value == null) return NavBarStyle.liquidGlass;
    return NavBarStyle.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NavBarStyle.liquidGlass,
    );
  }
}
