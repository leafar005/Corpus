import 'package:corpus/screens/bundles/bundle_details_screen.dart';
import 'package:corpus/screens/home/hero_showcase.dart';
import 'package:corpus/screens/home/home_screen.dart';
import 'package:corpus/screens/library/filter_option_screen.dart';
import 'package:corpus/screens/library/filter_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/typewriter_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Inicio, Explorar, Filtros y Resiliencia IGDB', () {
    testWidgets(
      'Inicio muestra HeroShowcase, Oportunidades Finales y Próximos lanzamientos con navegación',
      (tester) async {
        final seededBackend = FakeSupabaseBackend()
          ..seedPlayingGame(gameId: FakeSupabaseBackend.eldenRingId)
          ..seedActiveBundle(
            title: 'Humble RPG Classics Bundle',
            storeName: 'Humble Bundle',
            endsInDays: 2,
            gameIds: const <int>[
              FakeSupabaseBackend.eldenRingId,
              FakeSupabaseBackend.witcher3Id,
            ],
          );

        await harness.run(
          tester,
          (backend) async {
            // 1. HeroShowcase carga juego Jugando y abre su ficha al tocar el título.
            await harness.pumpUntilFound(tester, find.byType(HeroShowcase));
            await harness.pumpUntilFound(tester, find.text('Editar reseña'));
            await tester.pump(const Duration(seconds: 2));
            expect(
              find.textContaining('Player One', findRichText: true),
              findsWidgets,
            );

            await harness.pumpUntilFound(
              tester,
              find.descendant(
                of: find.byType(HeroShowcase),
                matching: find.textContaining('Elden Ring', findRichText: true),
              ),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(HeroShowcase),
                matching: find.byType(TypewriterText),
              ),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Elden Ring'), findsWidgets);

            Navigator.of(tester.element(find.byType(GameDetailsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            await harness.settleFrames(tester, count: 6);

            // 2. Desplazamiento hacia Oportunidades Finales y apertura de BundleDetailsScreen.
            final homeScrollable = find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            );
            await tester.dragUntilVisible(
              find.text('Humble RPG Classics Bundle'),
              homeScrollable.first,
              const Offset(0, -300),
            );
            await harness.settleFrames(tester, count: 6);
            expect(find.text('Oportunidades Finales'), findsOneWidget);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Humble RPG Classics Bundle'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(BundleDetailsScreen),
            );
            expect(find.text('Humble RPG Classics Bundle'), findsWidgets);
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );

            Navigator.of(
              tester.element(find.byType(BundleDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(BundleDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 3. Próximos lanzamientos (Juegos más anticipados) y apertura de ficha.
            await tester.dragUntilVisible(
              find.text('Hollow Knight: Silksong'),
              homeScrollable.first,
              const Offset(0, -300),
            );
            await harness.settleFrames(tester, count: 6);
            expect(find.text('Juegos más anticipados'), findsOneWidget);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Hollow Knight: Silksong'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Hollow Knight: Silksong'), findsWidgets);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Explorar muestra Tendencias y Bundles, abre BundleDetails, maneja estado vacío y limpia búsqueda',
      (tester) async {
        final seededBackend = FakeSupabaseBackend()
          ..seedActiveBundle(
            title: 'Fanatical Indie Gems',
            storeName: 'Fanatical',
            endsInDays: 5,
            gameIds: const <int>[FakeSupabaseBackend.hollowKnightId],
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Explorar');

            await harness.pumpUntilFound(tester, find.text('Tendencias'));
            await harness.pumpUntilFound(tester, find.text('Bundles'));
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Fanatical Indie Gems'),
            );

            // 1. Abrir BundleDetailsScreen desde Explorar.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Fanatical Indie Gems'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(BundleDetailsScreen),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );

            Navigator.of(
              tester.element(find.byType(BundleDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(BundleDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 2. Búsqueda sin resultados muestra mensaje de estado vacío.
            final searchField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juegos...',
            );
            await harness.pumpUntilFound(tester, searchField);
            await tester.enterText(searchField, 'JuegoInexistenteXYZ');
            await tester.pump(const Duration(milliseconds: 550));
            await harness.settleFrames(tester, count: 6);

            await harness.pumpUntilFound(
              tester,
              find.text('No se encontraron resultados...'),
            );

            // 3. Limpiar búsqueda vuelve a mostrar Tendencias y Bundles.
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await tester.pump(const Duration(milliseconds: 550));
            await harness.settleFrames(tester, count: 6);

            await harness.pumpUntilFound(tester, find.text('Tendencias'));
            expect(find.text('Bundles'), findsOneWidget);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Filtros avanzados filtran por plataforma y género, ordenan y permiten limpiar',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Explorar');
            await harness.pumpUntilFound(tester, find.text('Filtros'));

            // 1. Filtrar por plataforma Nintendo Switch.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Filtros'));
            await harness.pumpUntilFound(tester, find.byType(FilterScreen));

            await harness.tapWhenReady(tester, find.text('Plataformas'));
            await harness.pumpUntilFound(
              tester,
              find.byType(FilterOptionScreen),
            );
            await harness.tapWhenReady(tester, find.text('Nintendo Switch'));
            await harness.pumpUntilFound(tester, find.text('Aplicar (1)'));
            await harness.tapWhenReady(tester, find.text('Aplicar (1)'));
            await harness.pumpUntilGone(
              tester,
              find.byType(FilterOptionScreen),
            );

            await harness.pumpUntilFound(tester, find.byType(FilterScreen));
            expect(
              find.descendant(
                of: find.byType(FilterScreen),
                matching: find.text('Nintendo Switch'),
              ),
              findsOneWidget,
            );
            await harness.tapWhenReady(tester, find.text('Aplicar'));

            await harness.pumpUntilFound(tester, find.text('Filtros (1)'));
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );
            expect(
              harness.findGameCardByTitle('Elden Ring'),
              findsNothing,
            );

            // 2. Limpiar filtros, elegir género Rol (RPG) y ordenar alfabético ascendente.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Filtros (1)'));
            await harness.pumpUntilFound(tester, find.byType(FilterScreen));

            await harness.tapWhenReady(tester, find.text('Borrar'));
            await harness.tapWhenReady(tester, find.text('Géneros'));
            await harness.pumpUntilFound(
              tester,
              find.byType(FilterOptionScreen),
            );
            await harness.tapWhenReady(tester, find.text('🛡️ Rol (RPG)'));
            await harness.tapWhenReady(tester, find.text('Aplicar (1)'));
            await harness.pumpUntilGone(
              tester,
              find.byType(FilterOptionScreen),
            );

            await harness.pumpUntilFound(tester, find.byType(FilterScreen));
            await harness.tapWhenReady(tester, find.text('Alfabético'));
            await harness.tapWhenReady(tester, find.text('Ascendente'));
            await harness.tapWhenReady(tester, find.text('Aplicar'));

            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            expect(
              harness.findGameCardByTitle("Baldur's Gate 3"),
              findsOneWidget,
            );
            expect(
              harness.findGameCardByTitle('Hollow Knight'),
              findsNothing,
            );

            // 3. Limpiar todos los filtros y aplicar vuelve a Explorar (Tendencias).
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Filtros (1)'));
            await harness.pumpUntilFound(tester, find.byType(FilterScreen));
            await harness.tapWhenReady(tester, find.text('Borrar'));
            await harness.tapWhenReady(tester, find.text('Aplicar'));

            await harness.pumpUntilFound(tester, find.text('Tendencias'));
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Resiliencia ante error de red en igdb-proxy y recuperación en búsqueda',
      (tester) async {
        final failingBackend = FakeSupabaseBackend()..failIgdbProxy = true;

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Explorar');

            await harness.pumpUntilFound(
              tester,
              find.textContaining('Error cargando tendencias:'),
            );
            expect(tester.takeException(), isNull);

            // Restaura conectividad del proxy y limpia caché para recuperar la búsqueda.
            backend.failIgdbProxy = false;
            IGDBService.clearCache();

            final searchField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juegos...',
            );
            await harness.pumpUntilFound(tester, searchField);
            await tester.enterText(searchField, 'Elden Ring');
            await tester.pump(const Duration(milliseconds: 550));
            await harness.settleFrames(tester, count: 6);

            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: failingBackend,
          loggedIn: true,
        );
      },
    );
  });
}
