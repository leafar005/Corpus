import 'package:corpus/screens/library/game_details/game_details_controller.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Ficha de Juego y Reseñas', () {
    testWidgets(
      'Ficha de juego muestra pestañas Información, Comunidad, Media, Relacionado y Links con localización',
      (tester) async {
        final seededBackend = FakeSupabaseBackend()
          ..seedStashData(gameId: FakeSupabaseBackend.eldenRingId);

        await harness.run(
          tester,
          (backend) async {
            await harness.searchAndOpenGame(tester, 'Elden Ring');

            // 1. Pestaña Información: sinopsis, Metacritic, Stash Stats y tiempos.
            await harness.pumpUntilFound(
              tester,
              find.textContaining('Sinluz'),
            );
            await harness.pumpUntilFound(tester, find.text('Metacritic'));
            expect(find.text('94'), findsOneWidget);
            expect(find.text('Metascore'), findsOneWidget);
            expect(find.text('85 críticas'), findsOneWidget);
            expect(find.text('8.9'), findsOneWidget);
            expect(find.text('User Score'), findsOneWidget);

            await harness.pumpUntilFound(
              tester,
              find.text('Estadísticas de la Comunidad (Stash)'),
            );
            expect(find.text('50 h'), findsOneWidget);
            expect(find.text('80 h'), findsOneWidget);
            expect(find.text('130 h'), findsOneWidget);

            // 2. Pestaña Comunidad: reseñas de Stash.
            await harness.tapWhenReady(tester, find.text('Comunidad'));
            await harness.pumpUntilFound(tester, find.text('SoulsVeteran'));
            expect(find.text('Diseño de mundo insuperable.'), findsOneWidget);

            // 3. Pestaña Media: Capturas, Tráilers y Artworks.
            await harness.tapWhenReady(tester, find.text('Media'));
            await harness.pumpUntilFound(tester, find.text('Capturas'));
            expect(find.text('Tráilers'), findsOneWidget);
            expect(find.text('Artworks'), findsOneWidget);
            await harness.tapWhenReady(tester, find.text('Tráilers'));
            await harness.tapWhenReady(tester, find.text('Artworks'));
            expect(tester.takeException(), isNull);

            // 4. Pestaña Relacionado: expansiones y navegación a ficha relacionada.
            await harness.tapWhenReady(tester, find.text('Relacionado'));
            await harness.pumpUntilFound(tester, find.text('Expansiones (1)'));
            final dlcCard = find.textContaining('Shadow of the Erdtree');
            await harness.pumpUntilFound(tester, dlcCard);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, dlcCard);
            await harness.pumpUntilFound(
              tester,
              find.text('Elden Ring: Shadow of the Erdtree'),
            );

            Navigator.of(tester.element(find.byType(GameDetailsScreen).last)).pop();
            await harness.settleFrames(tester, count: 6);

            // 5. Pestaña Links: enlaces localizados a España por defecto.
            await harness.tapWhenReady(tester, find.text('Links'));
            await harness.pumpUntilFound(tester, find.text('Tiendas'));
            expect(find.text('Steam'), findsOneWidget);
            expect(find.text('PlayStation Store'), findsOneWidget);
            expect(find.text('Información Oficial'), findsOneWidget);
            expect(find.textContaining('l=spanish&cc=es'), findsOneWidget);
            expect(find.textContaining('/es-es/'), findsOneWidget);

            // Desactivar traducción de enlaces desde Perfil -> Ajustes y comprobar efecto.
            Navigator.of(tester.element(find.byType(GameDetailsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            await harness.settleFrames(tester, count: 6);

            await harness.tapTab(tester, 'Perfil');
            final settingsBtn = harness.findCorpusIcon(CorpusIconKind.Settings);
            await harness.pumpUntilFound(tester, settingsBtn);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, settingsBtn);

            await harness.pumpUntilFound(
              tester,
              find.text('Traducir enlaces de tiendas'),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Traducir enlaces de tiendas'),
            );
            await harness.settleFrames(tester, count: 6);

            // Volver atrás a Explorar -> abrir Elden Ring -> pestaña Links sin localizar.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);

            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.tapWhenReady(tester, find.text('Links'));
            await harness.pumpUntilFound(tester, find.text('Tiendas'));
            expect(find.textContaining('l=spanish&cc=es'), findsNothing);
            expect(find.textContaining('/en-us/'), findsOneWidget);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'ReviewModal cubre estados Por jugar, En Pausa, Abandonado, rejugada y desglose de nota',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await harness.searchAndOpenGame(tester, 'Hollow Knight');

            // 1. Guardar como Por jugar.
            await harness.tapWhenReady(
              tester,
              find.text('Añadir a Biblioteca'),
            );
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
            await harness.tapWhenReady(
              tester,
              find.text('Por jugar'),
              useLast: true,
            );
            await harness.tapWhenReady(
              tester,
              find.text('Guardar'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 6);
            expect(backend.tableRows('user_games').first['status'], 'to_play');

            // 2. Cambiar a Jugando + modo En Pausa + Rejugada activada.
            await harness.tapWhenReady(tester, find.text('Por jugar'));
            await harness.pumpUntilFound(tester, find.byTooltip('Cambiar estado'));
            await harness.tapWhenReady(tester, find.byTooltip('Cambiar estado'));

            await harness.tapWhenReady(
              tester,
              find.text('Jugando'),
              useLast: true,
            );
            await harness.tapWhenReady(
              tester,
              find.text('En Pausa'),
              useLast: true,
            );
            await harness.tapWhenReady(tester, find.byType(Switch).first);

            await harness.tapWhenReady(
              tester,
              find.text('Guardar'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Guardar'));
            await harness.settleFrames(tester, count: 6);
            expect(find.text('En Pausa'), findsWidgets);

            final playingReview = backend.tableRows('reviews').first;
            expect(playingReview['status'], 'playing');
            expect(playingReview['completion_type'], 'on_hold');
            expect(playingReview['is_replay'], isTrue);

            // 3. Cambiar a Abandonado con Slider, Desglosar nota y texto de reseña.
            await harness.tapWhenReady(tester, find.text('Jugando'));
            await harness.pumpUntilFound(tester, find.byTooltip('Cambiar estado'));
            await harness.tapWhenReady(tester, find.byTooltip('Cambiar estado'));

            await harness.tapWhenReady(
              tester,
              find.text('Abandonado'),
              useLast: true,
            );

            await harness.dragSliderIfPresent(tester);
            await harness.tapWhenReady(tester, find.text('Desglosar nota'));
            await harness.pumpUntilFound(tester, find.text('Gameplay'));
            expect(find.text('Narrativa'), findsOneWidget);
            expect(find.text('Banda Sonora'), findsOneWidget);
            expect(find.text('Gráficos'), findsOneWidget);

            const abandonedNote = 'Abandonado temporalmente por dificultad.';
            final commentInput = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == '¿Qué te pareció el juego?',
            );
            await tester.enterText(commentInput, abandonedNote);
            await tester.pump();

            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Guardar Reseña'));
            await harness.settleFrames(tester, count: 6);

            final abandonedReview = backend.tableRows('reviews').first;
            expect(abandonedReview['status'], 'abandoned');
            expect(abandonedReview['comment'], abandonedNote);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Reabrir GameDetailsScreen tras recarga completa refleja estado y reseña persistidos',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await harness.searchAndOpenGame(tester, 'Elden Ring');

            await harness.tapWhenReady(
              tester,
              find.text('Añadir a Biblioteca'),
            );
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
            await harness.tapWhenReady(
              tester,
              find.text('Terminado'),
              useLast: true,
            );

            const savedText = 'Persistencia verificada tras recarga';
            final commentInput = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == '¿Qué te pareció el juego?',
            );
            await tester.enterText(commentInput, savedText);
            await tester.pump();

            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 8);

            // Cerrar ficha y limpiar caches en memoria para forzar recarga limpia desde BD/proxy.
            Navigator.of(tester.element(find.byType(GameDetailsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            GameDetailsController.clearSessionCacheForTesting();
            IGDBService.clearCache();

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            await harness.pumpUntilFound(
              tester,
              find.textContaining(savedText),
            );
            expect(find.text('Añadir a Biblioteca'), findsNothing);
            expect(find.text('Terminado'), findsWidgets);
          },
          loggedIn: true,
        );
      },
    );
  });
}

extension on CorpusTestHarness {
  Future<void> dragSliderIfPresent(WidgetTester tester) async {
    final slider = find.byType(Slider);
    if (slider.evaluate().isNotEmpty) {
      await tester.drag(slider.first, const Offset(100, 0));
      await settleFrames(tester, count: 3);
    }
  }
}
