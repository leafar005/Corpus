import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/theme/app_theme.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/theme/style_pack.dart';
import 'package:corpus/theme/style_pack_registry.dart';

/// Mirrors the built-in registration in lib/main.dart.
StylePack persona5RoyalPack() => const StylePack(
  id: 'persona_5_royal',
  name: 'Persona 5 Royal',
  description:
      'Estilo inspirado en la identidad visual de Persona 5 Royal: rojo intenso, negro profundo, tipografía agresiva y formas angulares.',
  seedColor: Color(0xFFD3112D),
  scaffoldLight: Color(0xFFFFFFFF),
  scaffoldDark: Color(0xFF000000),
  surfaceLight: Color(0xFFFFFFFF),
  surfaceDark: Color(0xFF121212),
  accentColor: Color(0xFFFFD400),
  fontFamily: 'Archivo Black',
  heroFontFamily: 'Archivo Black',
  heroFontSize: 52,
  heroFontWeight: FontWeight.w900,
  borderRadiusSmall: 0,
  borderRadiusMedium: 2,
  borderRadiusLarge: 4,
  navBarStyle: NavBarStyle.persona5Royal,
  useDynamicFrames: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Persona 5 Royal pack registers and exposes expected tokens', () {
    StylePackRegistry.registerBuiltIn(persona5RoyalPack());

    final packs = StylePackRegistry.all;
    expect(
      packs.any((p) => p.id == 'persona_5_royal'),
      isTrue,
      reason: 'Pack should appear in Appearance grid via StylePackRegistry.all',
    );

    final pack = StylePackRegistry.getById('persona_5_royal');
    expect(pack.name, 'Persona 5 Royal');
    expect(pack.seedColor, const Color(0xFFD3112D));
    expect(pack.scaffoldDark, const Color(0xFF000000));
    expect(pack.surfaceDark, const Color(0xFF121212));
    expect(pack.accentColor, const Color(0xFFFFD400));
    expect(pack.fontFamily, 'Archivo Black');
    expect(pack.heroFontFamily, 'Archivo Black');
    expect(pack.heroFontSize, 52);
    expect(pack.borderRadiusSmall, 0);
    expect(pack.borderRadiusMedium, 2);
    expect(pack.borderRadiusLarge, 4);
    expect(pack.navBarStyle, NavBarStyle.persona5Royal);
    expect(pack.useDynamicFrames, isTrue);
  });

  test('AppTheme builds light/dark themes for Persona 5 Royal pack', () {
    final pack = persona5RoyalPack();
    final light = AppTheme.getLightTheme(pack.seedColor, pack);
    final dark = AppTheme.getDarkTheme(pack.seedColor, pack);

    expect(light.scaffoldBackgroundColor, pack.scaffoldLight);
    expect(dark.scaffoldBackgroundColor, pack.scaffoldDark);
    expect(light.colorScheme.primary, pack.seedColor);
    expect(dark.colorScheme.secondary, pack.accentColor);

    final ext = dark.extension<CorpusThemeExtension>()!;
    expect(ext.heroFontFamily, 'Archivo Black');
    expect(ext.heroFontSize, 52);
    expect(ext.borderRadiusMedium, 2);
    expect(ext.navBarStyle, NavBarStyle.persona5Royal);
    expect(ext.useDynamicFrames, isTrue);
  });
}
