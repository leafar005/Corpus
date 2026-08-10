import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:corpus/theme/app_theme.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/theme/style_pack.dart';
import 'package:corpus/theme/style_pack_registry.dart';

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
  musicFile: 'music/persona5royal.m4a',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Persona 5 Royal pack JSON round-trips with musicFile', () {
    final pack = persona5RoyalPack();
    final restored = StylePack.fromJson(pack.toJson());

    expect(restored.id, 'persona_5_royal');
    expect(restored.musicFile, 'music/persona5royal.m4a');
    expect(restored.navBarStyle, NavBarStyle.persona5Royal);
    expect(restored.useDynamicFrames, isTrue);
  });

  test('imported Persona 5 Royal pack appears in registry', () async {
    SharedPreferences.setMockInitialValues({});
    await StylePackRegistry.importFromJson(persona5RoyalPack().toJson());

    final packs = StylePackRegistry.all;
    expect(
      packs.any((p) => p.id == 'persona_5_royal'),
      isTrue,
      reason: 'Imported pack should appear via StylePackRegistry.all',
    );

    final pack = StylePackRegistry.getById('persona_5_royal');
    expect(pack.name, 'Persona 5 Royal');
    expect(pack.seedColor, const Color(0xFFD3112D));
    expect(pack.musicFile, 'music/persona5royal.m4a');
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
