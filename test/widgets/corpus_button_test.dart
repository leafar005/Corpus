import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/theme/style_pack.dart';
import 'package:corpus/widgets/design/corpus_button.dart';

void main() {
  Widget wrap(Widget child, {StylePack? pack}) {
    final p = pack ?? StylePack.defaultPack();
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: p.seedColor),
        extensions: [CorpusThemeExtension.fromPack(p)],
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('CorpusButton renders label and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(CorpusButton(label: 'Probar', onPressed: () => tapped = true)),
    );

    expect(find.text('Probar'), findsOneWidget);
    await tester.tap(find.text('Probar'));
    expect(tapped, isTrue);
  });

  testWidgets('CorpusButton uses P5R frame when pack enables dynamic frames', (
    tester,
  ) async {
    const p5r = StylePack(
      id: 'persona_5_royal',
      name: 'P5R',
      seedColor: Color(0xFFD3112D),
      accentColor: Color(0xFFFFD400),
      useDynamicFrames: true,
      borderRadiusSmall: 0,
      borderRadiusMedium: 2,
      borderRadiusLarge: 4,
    );

    await tester.pumpWidget(
      wrap(
        CorpusButton(label: 'Take Heart', onPressed: () {}),
        pack: p5r,
      ),
    );

    expect(find.byType(CorpusButton), findsOneWidget);
    expect(find.text('Take Heart'), findsOneWidget);
  });
}
