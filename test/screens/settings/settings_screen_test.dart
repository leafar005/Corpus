import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/screens/profile/edit_profile_screen.dart';
import 'package:corpus/screens/settings/integrations_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      publishableKey: 'mock-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [CorpusThemeExtension()]),
      home: child,
    );
  }

  group('SettingsScreen (UI2-04)', () {
    testWidgets(
      'caches SharedPreferences future across rebuilds and persists toggles',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const SettingsScreen(
              userProfile: {'username': 'tester'},
              hallOfFame: [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Traducir enlaces de tiendas'), findsOneWidget);
        expect(find.text('DuracionDe (experimental)'), findsOneWidget);

        // Toggle localize_links off
        await tester.tap(find.text('Traducir enlaces de tiendas'));
        await tester.pump();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('localize_links'), isFalse);

        // Rebuild parent widget; should NOT flash back to loading indicator
        await tester.pumpWidget(
          wrap(
            const SettingsScreen(
              userProfile: {'username': 'tester2'},
              hallOfFame: [],
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Cargando preferencias...'), findsNothing);
        expect(find.text('Traducir enlaces de tiendas'), findsOneWidget);
      },
    );

    testWidgets(
      'Vaciar cuenta validates userId == null before opening loading dialog',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const SettingsScreen(
              userProfile: {'username': 'tester'},
              hallOfFame: [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final clearAccountFinder = find.text('DEBUG: Vaciar cuenta');
        await tester.scrollUntilVisible(clearAccountFinder, 200);
        await tester.ensureVisible(clearAccountFinder);
        await tester.pumpAndSettle();
        await tester.tap(clearAccountFinder);
        await tester.pumpAndSettle();

        expect(find.text('¿Vaciar cuenta por completo?'), findsOneWidget);
        await tester.tap(find.text('VACIAR CUENTA'));
        await tester.pumpAndSettle();

        // Loading dialog must NOT remain stuck open, and snackbar is shown.
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('No hay sesión activa.'), findsOneWidget);
      },
    );
  });

  group('IntegrationsScreen (UI2-03)', () {
    testWidgets('disposes cleanly without controller leak errors', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const IntegrationsScreen()));
      await tester.pump();

      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('EditProfileScreen platform drag detection (UI2-02)', () {
    test('uses delayed drag on iPhone/Android Web and immediate drag on desktop', () {
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: true,
          platform: TargetPlatform.iOS,
          screenWidth: 390,
        ),
        isFalse,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: true,
          platform: TargetPlatform.iOS,
          screenWidth: 844,
        ),
        isFalse,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: true,
          platform: TargetPlatform.android,
          screenWidth: 412,
        ),
        isFalse,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: true,
          platform: TargetPlatform.windows,
          screenWidth: 600,
        ),
        isFalse,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: true,
          platform: TargetPlatform.windows,
          screenWidth: 1200,
        ),
        isTrue,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: false,
          platform: TargetPlatform.macOS,
          screenWidth: 500,
        ),
        isTrue,
      );
      expect(
        EditProfileScreen.isDesktopDragEnvironment(
          isWeb: false,
          platform: TargetPlatform.iOS,
          screenWidth: 390,
        ),
        isFalse,
      );
    });

    testWidgets(
      'renders ReorderableDelayedDragStartListener on mobile viewport',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            wrap(
              const EditProfileScreen(
                userProfile: {
                  'username': 'player1',
                  'display_name': 'Player One',
                  'bio': '',
                  'platforms': ['pc'],
                },
                hallOfFame: [null, null, null, null, null],
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byType(ReorderableDelayedDragStartListener),
            findsAtLeastNWidgets(1),
          );
          expect(find.byType(ReorderableDragStartListener), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
