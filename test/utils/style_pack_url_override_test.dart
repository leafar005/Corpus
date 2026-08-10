import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/theme/style_pack.dart';
import 'package:corpus/theme/style_pack_registry.dart';
import 'package:corpus/utils/style_pack_url_override.dart';

void main() {
  setUp(() {
    StylePackRegistry.registerBuiltIn(const StylePack(
      id: 'persona_5_royal',
      name: 'Persona 5 Royal',
      seedColor: Color(0xFFD3112D),
      accentColor: Color(0xFFFFD400),
    ));
  });

  test('?style=persona5 resolves to persona_5_royal', () {
    final uri = Uri.parse('http://localhost:8080/?style=persona5');
    expect(StylePackUrlOverride.packIdFromUri(uri), 'persona_5_royal');
  });

  test('?style=corpus resolves to default', () {
    final uri = Uri.parse('http://localhost:8080/?style=corpus');
    expect(StylePackUrlOverride.packIdFromUri(uri), 'default');
  });

  test('/style/persona5 path resolves to persona_5_royal', () {
    final uri = Uri.parse('http://localhost:8080/style/persona5');
    expect(StylePackUrlOverride.packIdFromUri(uri), 'persona_5_royal');
  });

  test('?=persona5 empty query key resolves to persona_5_royal', () {
    final uri = Uri.parse('http://localhost:8080/style?=persona5');
    expect(StylePackUrlOverride.packIdFromUri(uri), 'persona_5_royal');
  });

  test('unknown style returns null', () {
    final uri = Uri.parse('http://localhost:8080/?style=unknown_pack');
    expect(StylePackUrlOverride.packIdFromUri(uri), isNull);
  });

  test('no style param returns null', () {
    final uri = Uri.parse('http://localhost:8080/');
    expect(StylePackUrlOverride.packIdFromUri(uri), isNull);
  });
}
