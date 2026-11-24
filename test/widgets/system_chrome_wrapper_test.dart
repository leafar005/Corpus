import 'package:corpus/globals.dart';
import 'package:corpus/theme/app_theme.dart';
import 'package:corpus/widgets/system_chrome_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyWebSafeAreaInsets', () {
    test('returns original MediaQueryData when webInsets is zero', () {
      const base = MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(top: 10),
        viewPadding: EdgeInsets.only(top: 10),
      );
      final result = applyWebSafeAreaInsets(base, EdgeInsets.zero);
      expect(result, equals(base));
    });

    test('applies CSS safe-area insets when viewPadding is zero', () {
      const base = MediaQueryData(size: Size(393, 852));
      const webInsets = EdgeInsets.fromLTRB(4, 59, 6, 34);
      final result = applyWebSafeAreaInsets(base, webInsets);

      expect(result.viewPadding, const EdgeInsets.fromLTRB(4, 59, 6, 34));
      expect(result.padding, const EdgeInsets.fromLTRB(4, 59, 6, 34));
    });

    test('uses max per side to avoid double padding', () {
      const base = MediaQueryData(
        size: Size(393, 852),
        viewPadding: EdgeInsets.fromLTRB(10, 44, 2, 20),
        padding: EdgeInsets.fromLTRB(10, 44, 2, 20),
      );
      const webInsets = EdgeInsets.fromLTRB(4, 59, 8, 34);
      final result = applyWebSafeAreaInsets(base, webInsets);

      expect(result.viewPadding, const EdgeInsets.fromLTRB(10, 59, 8, 34));
      expect(result.padding, const EdgeInsets.fromLTRB(10, 59, 8, 34));
    });

    test(
      'subtracts viewInsets from padding and clamps at 0 while keeping viewPadding',
      () {
        const base = MediaQueryData(
          size: Size(393, 852),
          viewInsets: EdgeInsets.only(bottom: 300),
        );
        const webInsets = EdgeInsets.fromLTRB(0, 59, 0, 34);
        final result = applyWebSafeAreaInsets(base, webInsets);

        expect(result.viewPadding, const EdgeInsets.fromLTRB(0, 59, 0, 34));
        expect(result.padding, const EdgeInsets.fromLTRB(0, 59, 0, 0));
      },
    );
  });

  group('corpusSystemUiOverlayStyle', () {
    test('light brightness produces transparent bars and dark icons', () {
      final style = corpusSystemUiOverlayStyle(Brightness.light);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('dark brightness produces transparent bars and light icons', () {
      final style = corpusSystemUiOverlayStyle(Brightness.dark);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });
  });

  group('AppTheme systemOverlayStyle', () {
    test('light theme sets light overlay style on AppBarTheme', () {
      final theme = AppTheme.getLightTheme(Colors.deepPurpleAccent);
      expect(
        theme.appBarTheme.systemOverlayStyle,
        equals(corpusSystemUiOverlayStyle(Brightness.light)),
      );
    });

    test('dark theme sets dark overlay style on AppBarTheme', () {
      final theme = AppTheme.getDarkTheme(Colors.deepPurpleAccent);
      expect(
        theme.appBarTheme.systemOverlayStyle,
        equals(corpusSystemUiOverlayStyle(Brightness.dark)),
      );
    });
  });

  group('getBottomSpacer', () {
    testWidgets('returns 32.0 on desktop width', (tester) async {
      late double spacer;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1024, 768),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              spacer = getBottomSpacer(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(spacer, 32.0);
    });

    testWidgets('includes bottom safe-area padding on mobile', (tester) async {
      late double spacer;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              spacer = getBottomSpacer(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(spacer, 138.0);
    });
  });

  group('SystemChromeWrapper widget', () {
    testWidgets('renders AnnotatedRegion matching light and dark themes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getLightTheme(Colors.deepPurpleAccent),
          builder: (context, child) =>
              SystemChromeWrapper(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('Light')),
        ),
      );

      final lightRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(
        lightRegion.value,
        equals(corpusSystemUiOverlayStyle(Brightness.light)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getDarkTheme(Colors.deepPurpleAccent),
          builder: (context, child) =>
              SystemChromeWrapper(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('Dark')),
        ),
      );
      await tester.pumpAndSettle();

      final darkRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(
        darkRegion.value,
        equals(corpusSystemUiOverlayStyle(Brightness.dark)),
      );
    });
  });
}
