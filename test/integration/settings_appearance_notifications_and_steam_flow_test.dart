import 'dart:convert';
import 'dart:typed_data';

import 'package:corpus/globals.dart';
import 'package:corpus/screens/appearance_screen.dart';
import 'package:corpus/screens/info_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/settings/home_appearance_screen.dart';
import 'package:corpus/screens/settings/info_tab_appearance_screen.dart';
import 'package:corpus/screens/settings/integrations_screen.dart';
import 'package:corpus/screens/settings/notifications_screen.dart';
import 'package:corpus/screens/settings/steam_import_progress_screen.dart';
import 'package:corpus/screens/settings/steam_import_setup_screen.dart';
import 'package:corpus/screens/settings/import_preview_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/services/style_pack_music_service.dart';
import 'package:corpus/theme/style_pack_registry.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  Future<void> openSettingsFromProfile(WidgetTester tester) async {
    await harness.tapTab(tester, 'Perfil');
    await harness.settleFrames(tester, count: 8);
    final settingsBtn = harness.findCorpusIcon(CorpusIconKind.Settings);
    await harness.waitForPushDebounce(tester);
    await harness.tapWhenReady(tester, settingsBtn);
    await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
    await harness.settleFrames(tester, count: 6);
  }

  group('Ajustes, Apariencia, Notificaciones, Info e Importación Steam', () {
    testWidgets(
      'AppearanceScreen cambia tema, color principal, style pack, música y opciones móviles',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openSettingsFromProfile(tester);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Apariencia'));
            await harness.pumpUntilFound(tester, find.byType(AppearanceScreen));
            await harness.settleFrames(tester, count: 6);

            // 1. Validar StylePackRegistry + selección de debug pack y retorno a Corpus Classic.
            expect(find.text('Corpus Classic'), findsOneWidget);
            if (StylePackRegistry.debugBuiltIn.isNotEmpty) {
              final debugPack = StylePackRegistry.debugBuiltIn.first;
              expect(find.text(debugPack.name), findsOneWidget);
              await harness.tapWhenReady(tester, find.text(debugPack.name));
              await harness.settleFrames(tester, count: 6);
              expect(themeNotifier.stylePackId, debugPack.id);
              await tester.runAsync(
                () => StylePackMusicService.instance.syncWithCurrentPack(
                  force: true,
                ),
              );

              await harness.tapWhenReady(tester, find.text('Corpus Classic'));
              await harness.settleFrames(tester, count: 6);
              expect(themeNotifier.stylePackId, 'default');
            }

            // Importar un style pack .json desde UI real con FilePicker y eliminarlo después.
            expect(floatingMobileNavNotifier.value, isFalse);
            harness.enqueuePickedFile(
              name: 'cyber_neon.json',
              bytes: Uint8List.fromList(
                utf8.encode(
                  jsonEncode(<String, dynamic>{
                    'id': 'cyber_neon',
                    'name': 'Cyber Neon',
                    'seedColor': '#00E5FF',
                    'accentColor': '#FF4081',
                    'fontFamily': 'Syne',
                  }),
                ),
              ),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Importar addon (.corpuspack)'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Pack "Cyber Neon" importado'),
            );
            expect(harness.filePickerCallCount, 1);
            expect(themeNotifier.stylePackId, 'cyber_neon');
            expect(find.text('Cyber Neon'), findsOneWidget);

            await harness.tapWhenReady(
              tester,
              find.byTooltip('Eliminar addon'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Eliminar "Cyber Neon"?'),
            );
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Eliminar'),
              ),
            );
            await harness.pumpUntilGone(tester, find.byType(AlertDialog));
            await harness.settleFrames(tester, count: 4);
            expect(themeNotifier.stylePackId, 'default');
            expect(find.text('Cyber Neon'), findsNothing);

            // 2. Cambiar ThemeMode (Claro -> Oscuro -> Sistema).
            await tester.dragUntilVisible(
              find.text('Oscuro'),
              find.byType(ListView).last,
              const Offset(0, -250),
            );
            await harness.tapWhenReady(tester, find.text('Claro'));
            await harness.settleFrames(tester, count: 4);
            expect(themeNotifier.currentMode, ThemeMode.light);

            await harness.tapWhenReady(tester, find.text('Oscuro'));
            await harness.settleFrames(tester, count: 4);
            expect(themeNotifier.currentMode, ThemeMode.dark);

            await harness.tapWhenReady(tester, find.text('Sistema'));
            await harness.settleFrames(tester, count: 4);
            expect(themeNotifier.currentMode, ThemeMode.system);

            // 3. Seleccionar otro color principal (Teal).
            await tester.dragUntilVisible(
              find.text('Color principal'),
              find.byType(ListView).last,
              const Offset(0, -250),
            );
            final tealSwatch = find.byWidgetPredicate((w) {
              if (w is AnimatedContainer && w.decoration is BoxDecoration) {
                final dec = w.decoration! as BoxDecoration;
                return dec.color == Colors.teal;
              }
              return false;
            });
            expect(tealSwatch, findsOneWidget);
            await harness.tapWhenReady(tester, tealSwatch);
            await harness.settleFrames(tester, count: 4);
            expect(themeNotifier.seedColor, Colors.teal);

            // 4. Opciones exclusivas móviles: columnas de cuadrícula y nav flotante.
            await tester.dragUntilVisible(
              find.byType(SwitchListTile),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            final targetCols = mobileGridColumnsNotifier.value == 2 ? 4 : 2;
            await tester.ensureVisible(find.text('$targetCols'));
            await harness.tapWhenReady(tester, find.text('$targetCols'));
            await harness.settleFrames(tester, count: 4);
            expect(mobileGridColumnsNotifier.value, targetCols);

            final beforeFloating = floatingMobileNavNotifier.value;
            await tester.ensureVisible(find.byType(SwitchListTile));
            await harness.settleFrames(tester, count: 4);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(SwitchListTile),
                matching: find.byType(Switch),
              ),
            );
            await harness.settleFrames(tester, count: 4);
            expect(floatingMobileNavNotifier.value, !beforeFloating);

            expect(tester.takeException(), isNull);
          },
          viewportSize: CorpusTestHarness.mobileSize,
          floatingMobileNav: false,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Personalizar Inicio (HomeAppearanceScreen) y pestaña Información (InfoTabAppearanceScreen)',
      (tester) async {
        final seeded = FakeSupabaseBackend()..seedActiveBundle();
        await harness.run(
          tester,
          (backend) async {
            await openSettingsFromProfile(tester);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Apariencia'));
            await harness.pumpUntilFound(tester, find.byType(AppearanceScreen));
            await harness.settleFrames(tester, count: 6);

            // 1. Personalizar Inicio.
            await tester.dragUntilVisible(
              find.text('Personalizar Inicio'),
              find.byType(ListView).last,
              const Offset(0, -250),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Personalizar Inicio'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(HomeAppearanceScreen),
            );
            await harness.settleFrames(tester, count: 6);

            expect(
              find.text('Destacados / Jugando Actualmente'),
              findsOneWidget,
            );
            expect(
              find.text('Oportunidades Finales (Bundles)'),
              findsOneWidget,
            );
            expect(find.text('Actividad global de Stash'), findsOneWidget);
            expect(find.text('Más Anticipados'), findsOneWidget);

            // Ocultar Oportunidades Finales (1) y Actividad global de Stash (2).
            final switches = find.descendant(
              of: find.byType(HomeAppearanceScreen),
              matching: find.byType(Switch),
            );
            await harness.tapWhenReady(tester, switches.at(1));
            await harness.tapWhenReady(tester, switches.at(2));
            await harness.settleFrames(tester, count: 6);

            final prefs = await SharedPreferences.getInstance();
            final hidden = prefs.getStringList('home_sections_hidden') ?? [];
            expect(hidden, contains('bundles_ending_soon'));
            expect(hidden, contains('stash_activity'));

            // Abrir diálogo de Oportunidades Finales (días).
            final bundlesSettingsTooltip = find.byTooltip(
              'Configurar días de antelación',
            );
            if (bundlesSettingsTooltip.evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, bundlesSettingsTooltip);
            } else {
              final settingsIcons = find.descendant(
                of: find.byType(HomeAppearanceScreen),
                matching: harness.findCorpusIcon(
                  CorpusIconKind.SettingsOutlined,
                ),
              );
              await harness.tapWhenReady(tester, settingsIcons.first);
            }
            await harness.pumpUntilFound(tester, find.byType(AlertDialog));
            await tester.drag(find.byType(Slider).last, const Offset(80, 0));
            await harness.tapWhenReady(tester, find.text('Guardar'));
            await harness.pumpUntilGone(tester, find.byType(AlertDialog));

            // Abrir diálogo de formato de cuenta atrás en Más Anticipados.
            final settingsIcons = find.descendant(
              of: find.byType(HomeAppearanceScreen),
              matching: harness.findCorpusIcon(CorpusIconKind.SettingsOutlined),
            );
            if (settingsIcons.evaluate().length >= 2) {
              await harness.tapWhenReady(tester, settingsIcons.last);
              await harness.pumpUntilFound(tester, find.byType(AlertDialog));
              await harness.tapWhenReady(
                tester,
                find.text('Completa (Días, Horas, Minutos)'),
              );
              await harness.pumpUntilGone(tester, find.byType(AlertDialog));
            }

            // Volver a AppearanceScreen.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);

            // 2. Personalizar pestaña Información.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Personalizar pestaña Información'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(InfoTabAppearanceScreen),
            );
            await harness.settleFrames(tester, count: 6);

            expect(find.text('Franquicia / Colección'), findsOneWidget);
            expect(find.text('Tiempo estimado (HLTB)'), findsOneWidget);

            final infoSwitches = find.descendant(
              of: find.byType(InfoTabAppearanceScreen),
              matching: find.byType(Switch),
            );
            await harness.tapWhenReady(tester, infoSwitches.first);
            await harness.settleFrames(tester, count: 6);
            expect(
              prefs.getStringList('info_tab_hidden') ?? [],
              contains('franchise'),
            );

            // Restablecer por defecto, luego volver a ocultar 'franchise' para verificar el efecto vivo.
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Restablecer por defecto'),
            );
            await harness.settleFrames(tester, count: 6);
            expect(prefs.getStringList('info_tab_hidden') ?? [], isEmpty);

            await harness.tapWhenReady(tester, infoSwitches.first);
            await harness.settleFrames(tester, count: 6);
            expect(
              prefs.getStringList('info_tab_hidden') ?? [],
              contains('franchise'),
            );

            // Volver hasta Profile y comprobar en vivo en Inicio y en GameInfoTab.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 4);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 4);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);

            await harness.tapTab(tester, 'Inicio');
            await harness.settleFrames(tester, count: 10);
            expect(find.text('Oportunidades Finales'), findsNothing);

            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            await harness.tapWhenReady(tester, find.text('Información'));
            await harness.pumpUntilFound(tester, find.text('Sinopsis'));
            expect(find.text('Franquicia / Colección'), findsNothing);

            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'NotificationsScreen guarda preferencias + send-test-notification e InfoScreen muestra créditos y enlaces',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openSettingsFromProfile(tester);

            // 1. Notificaciones.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Notificaciones'));
            await harness.pumpUntilFound(
              tester,
              find.byType(NotificationsScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Amigo empieza a jugar'),
            );

            expect(find.text('Amigo termina un juego'), findsOneWidget);
            expect(find.text('Bundle nuevo disponible'), findsOneWidget);
            expect(find.text('Comentario en tu reseña'), findsOneWidget);

            await harness.tapWhenReady(
              tester,
              find.text('Amigo empieza a jugar'),
            );
            await harness.settleFrames(tester, count: 6);

            await tester.dragUntilVisible(
              find.text('Enviar notificación de prueba'),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Comentario en tu reseña'),
            );
            await harness.settleFrames(tester, count: 6);

            final notifRows = backend.tableRows('notification_preferences');
            expect(notifRows, hasLength(1));
            expect(notifRows.first['friend_started_playing'], isFalse);
            expect(notifRows.first['comment_on_review'], isFalse);

            await harness.tapWhenReady(
              tester,
              find.text('Enviar notificación de prueba'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Notificación de prueba enviada.'),
            );

            // Comprobar también el endpoint Edge Function send-test-notification.
            await tester.runAsync(
              () => Supabase.instance.client.functions.invoke(
                'send-test-notification',
                body: <String, dynamic>{'token': 'mock-fcm-token'},
              ),
            );
            expect(backend.testNotificationsSent, 1);

            // Volver a Ajustes.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);

            // 2. Información (InfoScreen).
            await tester.dragUntilVisible(
              find.text('Información'),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Información'));
            await harness.pumpUntilFound(tester, find.byType(InfoScreen));
            await harness.settleFrames(tester, count: 6);

            expect(find.text('Corpus'), findsOneWidget);
            expect(find.textContaining('Versión'), findsOneWidget);
            expect(find.text('leafar005'), findsOneWidget);
            expect(find.text('coldrzz'), findsOneWidget);

            await tester.dragUntilVisible(
              find.text('IGDB API'),
              find.byType(SingleChildScrollView).last,
              const Offset(0, -300),
            );
            expect(find.text('Flutter'), findsOneWidget);
            expect(find.text('Supabase'), findsOneWidget);
            expect(find.text('IGDB API'), findsOneWidget);

            await harness.tapWhenReady(tester, find.text('Flutter'));
            await harness.settleFrames(tester, count: 4);
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Importación Steam E2E: vincular cuenta -> setup -> progreso -> preview -> guardar en biblioteca y desvincular',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openSettingsFromProfile(tester);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Integraciones'));
            await harness.pumpUntilFound(
              tester,
              find.byType(IntegrationsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 1. Vincular perfil Steam.
            final steamField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Steam Profile URL o ID',
            );
            await harness.pumpUntilFound(tester, steamField);
            await tester.enterText(
              steamField,
              'https://steamcommunity.com/id/steamplayer',
            );
            await tester.pump();

            await harness.tapWhenReady(tester, find.text('Vincular'));
            await harness.pumpUntilFound(
              tester,
              find.text('Cuenta vinculada: SteamPlayer'),
            );
            expect(backend.steamResolveCalls, 1);

            // 2. Abrir SteamImportSetupScreen y elegir mínimo de 1h (60 min).
            await harness.tapWhenReady(
              tester,
              find.text('Importar biblioteca de Steam'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(SteamImportSetupScreen),
            );
            await harness.tapWhenReady(tester, find.text('1h'));
            await harness.settleFrames(tester, count: 4);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Iniciar importación'),
            );

            // 3. SteamImportProgressScreen llama a steam-library-import y reemplaza con ImportPreviewScreen.
            await harness.pumpUntilFound(
              tester,
              find.byType(ImportPreviewScreen),
            );
            await harness.pumpUntilGone(
              tester,
              find.byType(SteamImportProgressScreen),
            );
            await harness.settleFrames(tester, count: 6);
            expect(find.byType(SteamImportProgressScreen), findsNothing);
            expect(backend.steamImportCalls, 1);
            expect(backend.lastSteamImportMinPlaytimeMinutes, 60);

            // Hollow Knight (45m) quedó filtrado; quedan Elden Ring (10h) y The Witcher 3 (3h).
            expect(find.text('Elden Ring'), findsOneWidget);
            expect(find.text('The Witcher 3: Wild Hunt'), findsOneWidget);
            expect(find.text('Hollow Knight'), findsNothing);

            // 4. Probar buscador en ImportPreviewScreen y luego restaurar.
            final previewSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juego...',
            );
            await tester.enterText(previewSearch, 'Elden');
            await harness.settleFrames(tester, count: 4);
            expect(find.text('Elden Ring'), findsOneWidget);
            expect(find.text('The Witcher 3: Wild Hunt'), findsNothing);

            await tester.enterText(previewSearch, '');
            await harness.settleFrames(tester, count: 4);

            // 5. Confirmar importación a Supabase.
            await harness.tapWhenReady(
              tester,
              find.text('Importar 2 juegos a mi biblioteca'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¡Importación completada con éxito! (2 juegos)'),
            );
            await harness.pumpUntilGone(
              tester,
              find.byType(ImportPreviewScreen),
            );

            expect(
              backend
                  .tableRows('user_games')
                  .where((ug) => ug['steam_owned'] == true),
              hasLength(2),
            );
            expect(backend.tableRows('reviews'), hasLength(2));
            // El activity_feed automático de importación se limpia (no aparece en activity_feed).
            expect(backend.tableRows('activity_feed'), isEmpty);

            // Verificación extra sobre el contrato JSON de SteamImportProgressScreen -> ImportPreviewScreen.
            final userAfterImport = backend
                .tableRows('users')
                .firstWhere((u) => u['id'] == FakeSupabaseBackend.primaryUserId);
            expect(userAfterImport['steam_id'], '76561198000000001');

            // 6. Desvincular Steam en IntegrationsScreen.
            await harness.tapWhenReady(tester, find.text('Desvincular'));
            await harness.pumpUntilFound(tester, find.text('Vincular'));
            final userAfterUnlink = backend
                .tableRows('users')
                .firstWhere((u) => u['id'] == FakeSupabaseBackend.primaryUserId);
            expect(userAfterUnlink['steam_id'], isNull);

            // Verificar que el payload real de steam-library-import es JSON válido.
            expect(jsonDecode(jsonEncode(userAfterUnlink)), isA<Map>());
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );
  });
}
