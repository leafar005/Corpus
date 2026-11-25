import 'package:corpus/globals.dart';
import 'package:corpus/screens/home/anticipated_games_section.dart';
import 'package:corpus/screens/home/hero_showcase.dart';
import 'package:corpus/screens/home/home_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/library/group_games_screen.dart';
import 'package:corpus/screens/library/library_screen.dart';
import 'package:corpus/screens/library/search_screen.dart';
import 'package:corpus/services/igdb_service.dart';
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

  group('Inicio, Catálogo, Paginación y Grupos (Casos límite)', () {
    testWidgets(
      'HomeScreen maneja estado vacío, fallo IGDB 500, error Fase 1 y se recupera al recargar',
      (tester) async {
        // 1. Arrancar con error 500 en user_games para verificar estado de error en Fase 1.
        final backend = FakeSupabaseBackend()
          ..failIgdbProxy = true
          ..httpErrorOverride = (method, uri) {
            if (uri.path == '/rest/v1/user_games') {
              return 500;
            }
            return null;
          };

        await harness.run(
          tester,
          (activeBackend) async {
            await harness.pumpUntilFound(
              tester,
              find.textContaining('Error:'),
            );
            expect(tester.takeException(), isNull);

            // 2. Recuperar Fase 1 (sin juegos jugando aún) manteniendo failIgdbProxy = true
            //    para validar EmptyPlayingHero y resiliencia ante IGDB 500 en Fase 2.
            activeBackend.httpErrorOverride = null;
            libraryUpdateNotifier.value++;
            await harness.pumpUntilFound(
              tester,
              find.byType(EmptyPlayingHero),
            );
            await tester.pump(const Duration(seconds: 2));
            expect(find.byType(EmptyPlayingHero), findsOneWidget);
            expect(find.byType(AnticipatedGamesSection), findsNothing);
            expect(tester.takeException(), isNull);

            // 3. Quitar failIgdbProxy, sembrar juego en Jugando y hacer pull-to-refresh.
            activeBackend.failIgdbProxy = false;
            activeBackend.seedPlayingGame(
              gameId: FakeSupabaseBackend.eldenRingId,
            );
            IGDBService.clearCache();

            final homeScroll = find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(CustomScrollView),
            );
            await tester.drag(homeScroll.first, const Offset(0, 320));
            await harness.pumpUntilFound(tester, find.byType(HeroShowcase));
            await harness.pumpUntilFound(
              tester,
              find.descendant(
                of: find.byType(HeroShowcase),
                matching: find.byType(TypewriterText),
              ),
            );
            await tester.pump(const Duration(seconds: 2));

            expect(find.byType(HeroShowcase), findsOneWidget);
            expect(
              find.textContaining('Elden Ring', findRichText: true),
              findsWidgets,
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: backend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'LibraryScreen (vacío, error 500 y catálogo) y paginación por scroll en SearchScreen',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            Future<void> pushScreen(Widget screen) async {
              final navContext = tester.element(find.byType(HomeScreen));
              // ignore: unawaited_futures
              Navigator.of(navContext).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              );
              await harness.settleFrames(tester, count: 8);
            }

            Future<void> popTop() async {
              tester.state<NavigatorState>(find.byType(Navigator).last).pop();
              await harness.settleFrames(tester, count: 8);
            }

            // 1. LibraryScreen vacío.
            await pushScreen(const LibraryScreen());
            await harness.pumpUntilFound(
              tester,
              find.text('Tu biblioteca está vacía'),
            );
            expect(
              find.text('Pulsa el botón + para añadir\ntus primeros juegos.'),
              findsOneWidget,
            );
            await popTop();

            // 2. LibraryScreen con error HTTP 500 en user_games.
            backend.httpErrorOverride = (method, uri) {
              if (uri.path == '/rest/v1/user_games') return 500;
              return null;
            };
            await pushScreen(const LibraryScreen());
            await harness.pumpUntilFound(
              tester,
              find.textContaining('Oops, no hemos podido cargar tu biblioteca.'),
            );
            backend.httpErrorOverride = null;
            await popTop();

            // 3. LibraryScreen poblado con varios juegos + navegación con FAB +.
            backend.seedUserGame(
              gameId: FakeSupabaseBackend.eldenRingId,
              status: 'playing',
              rating: 9.5,
            );
            backend.seedUserGame(
              gameId: FakeSupabaseBackend.hollowKnightId,
              status: 'beaten',
              rating: 9.0,
            );
            backend.seedUserGame(
              gameId: FakeSupabaseBackend.witcher3Id,
              status: 'beaten',
              rating: 9.8,
            );

            await pushScreen(const LibraryScreen());
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            expect(
              harness.findGameCardByTitle('Hollow Knight'),
              findsOneWidget,
            );
            expect(
              harness.findGameCardByTitle('The Witcher 3: Wild Hunt'),
              findsOneWidget,
            );

            await harness.tapWhenReady(
              tester,
              find.byType(FloatingActionButton),
            );
            await harness.pumpUntilFound(tester, find.byType(SearchScreen));
            await popTop();
            await popTop();

            // 4. Paginación / scroll infinito en SearchScreen (>35 resultados).
            backend.seedExtraIgdbGames(40);
            IGDBService.clearCache();

            await harness.tapTab(tester, 'Explorar');
            final searchField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juegos...',
            );
            await harness.pumpUntilFound(tester, searchField);
            await tester.enterText(searchField, 'Chronicle');
            await tester.pump(const Duration(milliseconds: 550));
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Chronicle Quest 01'),
            );

            final callsAfterPage1 = backend.igdbProxyCalls;
            final gridScroll = find.descendant(
              of: find.byType(SearchScreen),
              matching: find.byType(CustomScrollView),
            );

            // Desplazar hasta el final para disparar PaginatedScrollMixin.loadMore (offset=35).
            for (var i = 0; i < 6; i++) {
              await tester.drag(gridScroll.first, const Offset(0, -1400));
              await harness.settleFrames(tester, count: 6);
              if (backend.igdbProxyCalls > callsAfterPage1 &&
                  harness
                      .findGameCardByTitle('Chronicle Quest 40')
                      .evaluate()
                      .isNotEmpty) {
                break;
              }
            }

            expect(backend.igdbProxyCalls, greaterThan(callsAfterPage1));
            expect(
              harness.findGameCardByTitle('Chronicle Quest 40'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'GroupGamesScreen navega desde GameDetailsScreen por compañía, colección, franquicia y muestra estado vacío',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            Future<void> openGroup(Widget screen) async {
              final navContext = tester.element(find.byType(Navigator).last);
              // ignore: unawaited_futures
              Navigator.of(navContext).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              );
              await harness.settleFrames(tester, count: 8);
            }

            Future<void> popTop() async {
              tester.state<NavigatorState>(find.byType(Navigator).last).pop();
              await harness.settleFrames(tester, count: 8);
            }

            // 1. Navegación real desde GameDetailsScreen de Elden Ring -> desarrollador FromSoftware.
            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            await harness.pumpUntilFound(tester, find.text('FromSoftware'));
            await harness.settleFrames(tester, count: 6);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('FromSoftware'));
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupGamesScreen),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            await popTop();

            // 2. Navegación real desde GameInfoTab -> colección (Soulsborne = 543) y franquicia (Elden Ring = 1124).
            await harness.tapWhenReady(tester, find.text('Información'));
            await harness.pumpUntilFound(
              tester,
              find.text('Franquicia / Colección'),
            );
            await tester.ensureVisible(
              find.widgetWithText(ActionChip, 'Soulsborne'),
            );
            await harness.settleFrames(tester, count: 4);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(ActionChip, 'Soulsborne'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupGamesScreen),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            await popTop();

            final franchiseChip = find.widgetWithText(ActionChip, 'Elden Ring');
            await tester.ensureVisible(franchiseChip);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, franchiseChip);
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupGamesScreen),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            await popTop();

            // 3. Saga inexistente -> estado vacío.
            await openGroup(
              const GroupGamesScreen(
                title: 'Saga Inexistente',
                collectionId: 999999,
                isFranchise: false,
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('No se encontraron juegos para esta saga/franquicia.'),
            );
            await popTop();
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );
  });
}
