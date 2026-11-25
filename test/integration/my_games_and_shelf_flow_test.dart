import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/my_games/group_detail_screen.dart';
import 'package:corpus/screens/profile/collection_shelf_screen.dart';
import 'package:corpus/services/deep_link_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Mis Juegos, Colecciones y Estantería física', () {
    testWidgets(
      'GamesTab — secciones Jugando/Por jugar, filtro rápido (>4 juegos) y apertura de ficha',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedUserGame(
            gameId: FakeSupabaseBackend.eldenRingId,
            status: 'playing',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.hollowKnightId,
            status: 'playing',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.witcher3Id,
            status: 'playing',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.baldursGate3Id,
            status: 'to_play',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.eldenRingDlcId,
            status: 'to_play',
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Mis juegos');
            await harness.pumpUntilFound(tester, find.text('Jugando'));
            await harness.pumpUntilFound(tester, find.text('Por jugar'));

            expect(
              harness.findGameCardByTitle('Hollow Knight'),
              findsOneWidget,
            );
            expect(
              harness.findGameCardByTitle("Baldur's Gate 3"),
              findsOneWidget,
            );

            // Al haber > 4 juegos, se muestra el buscador rápido.
            final quickFilter = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText ==
                      'Filtrar juegos en curso o por jugar…',
            );
            await harness.pumpUntilFound(tester, quickFilter);
            await tester.enterText(quickFilter, 'Baldur');
            await harness.settleFrames(tester, count: 6);

            expect(
              harness.findGameCardByTitle("Baldur's Gate 3"),
              findsOneWidget,
            );
            expect(harness.findGameCardByTitle('Hollow Knight'), findsNothing);

            // Limpiar búsqueda y verificar recuperación completa.
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );

            // Abrir ficha desde GamesTab.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Hollow Knight'), findsWidgets);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'GroupsTab y GroupDetailScreen — editar colección, rankeada, quitar juego y eliminar colección',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedBeatenGame(gameId: FakeSupabaseBackend.eldenRingId)
          ..seedBeatenGame(gameId: FakeSupabaseBackend.hollowKnightId)
          ..seedCollection(
            userId: FakeSupabaseBackend.primaryUserId,
            name: 'Backlog RPG',
            description: 'Pendientes',
            gameIds: <int>[
              FakeSupabaseBackend.eldenRingId,
              FakeSupabaseBackend.hollowKnightId,
            ],
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Mis juegos');
            await harness.tapWhenReady(tester, find.text('Colecciones'));
            await harness.pumpUntilFound(tester, find.text('Backlog RPG'));

            // Abrir detalle de la colección.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Backlog RPG'));
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupDetailScreen),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );

            // Buscador interno de la colección.
            final groupSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juego en la colección…',
            );
            await tester.enterText(groupSearch, 'Hollow');
            await harness.settleFrames(tester, count: 6);
            expect(
              harness.findGameCardByTitle('Hollow Knight'),
              findsOneWidget,
            );
            expect(harness.findGameCardByTitle('Elden Ring'), findsNothing);

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );

            // Editar nombre, descripción y activar ranking.
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Editar colección'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Editar colección'),
            );

            final dialogFields = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            );
            await tester.enterText(dialogFields.at(0), 'Top Souls & Indies');
            await tester.enterText(dialogFields.at(1), 'Favoritos ordenados');
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Colección rankeada'),
              ),
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Guardar'),
            );

            await harness.pumpUntilFound(
              tester,
              find.text('Top Souls & Indies'),
            );
            expect(find.text('Favoritos ordenados'), findsOneWidget);
            expect(find.text('Colección rankeada'), findsWidgets);
            expect(find.text('#1'), findsOneWidget);
            expect(find.text('#2'), findsOneWidget);

            // Abrir hoja de reordenación.
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Reordenar juegos'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Reordenar juegos'),
            );
            final closeReorder = find.byWidgetPredicate(
              (w) =>
                  w is IconButton &&
                  w.icon is CorpusTablerIcon &&
                  (w.icon as CorpusTablerIcon).kind == CorpusIconKind.Close,
            );
            await harness.tapWhenReady(tester, closeReorder, useLast: true);
            await harness.settleFrames(tester, count: 6);

            // Quitar uno de los juegos de la colección.
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Close).first,
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Quitar de la colección'),
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Quitar'),
            );
            await harness.pumpUntilFound(tester, find.text('1 juego'));
            expect(backend.tableRows('game_group_items'), hasLength(1));

            // Volver atrás a GroupsTab y verificar la tarjeta actualizada.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(GroupDetailScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Top Souls & Indies'),
            );
            expect(find.text('Rankeada'), findsOneWidget);

            // Eliminar la colección completa desde el menú de tarjeta.
            await harness.tapWhenReady(tester, find.byTooltip('Opciones'));
            await harness.pumpUntilFound(tester, find.text('Eliminar'));
            await harness.tapWhenReady(tester, find.text('Eliminar'));
            await harness.pumpUntilFound(
              tester,
              find.text('Eliminar colección'),
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Eliminar'),
            );

            await harness.pumpUntilFound(
              tester,
              find.text('Sin colecciones todavía'),
            );
            expect(backend.tableRows('game_groups'), isEmpty);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'CollectionTab y CollectionShelfScreen — añadir juego, selección masiva, filtros, vista y eliminar ítem',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.eldenRingId,
            platform: null,
          )
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.hollowKnightId,
            platform: null,
          )
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.witcher3Id,
            platform: 'PC',
            steamOwned: true,
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Mis juegos');
            await harness.tapWhenReady(tester, find.text('Estantería'));
            await harness.pumpUntilFound(
              tester,
              find.text('Tu estantería está vacía'),
            );

            // 1. Añadir primer juego con PlatformPickerSheet (PlayStation 5).
            await harness.tapWhenReady(
              tester,
              find.text('Añadir primer juego'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Añadir a la estantería'),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Elden Ring'),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¿En qué plataforma lo tienes?'),
            );

            await harness.tapWhenReady(
              tester,
              find.text('PlayStation 5'),
              useLast: true,
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Guardar'),
            );
            await harness.pumpUntilGone(
              tester,
              find.text('Añadir a la estantería'),
            );

            expect(backend.tableRows('user_game_platforms'), hasLength(1));
            await harness.pumpUntilFound(tester, find.text('Todas (1)'));
            expect(find.text('PS5 (1)'), findsOneWidget);

            // 2. Selección masiva en lote (Steam).
            await harness.tapWhenReady(
              tester,
              find.text('Selección masiva'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Elige una plataforma y marca los juegos de tu biblioteca.'),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Elegir plataforma'),
            );
            await harness.pumpUntilFound(tester, find.text('Plataforma'));

            final steamTile = find.widgetWithText(ListTile, 'Steam');
            await tester.scrollUntilVisible(
              steamTile,
              300,
              scrollable: find.byType(Scrollable).last,
            );
            await harness.tapWhenReady(tester, steamTile);

            // Witcher 3 queda autoseleccionado por steamOwned; marcamos también Hollow Knight.
            await harness.pumpUntilFound(
              tester,
              find.text('The Witcher 3: Wild Hunt'),
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(CheckboxListTile, 'Hollow Knight'),
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Añadir 2 juegos'),
            );
            await harness.pumpUntilGone(
              tester,
              find.text('Elige una plataforma y marca los juegos de tu biblioteca.'),
            );

            expect(backend.tableRows('user_game_platforms'), hasLength(3));
            await harness.pumpUntilFound(tester, find.text('Todas (3)'));
            expect(find.text('PS5 (1)'), findsOneWidget);
            expect(find.text('Steam (2)'), findsOneWidget);

            // 3. Buscar y filtrar por chip + alternar vista de lomo a portadas.
            final shelfSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar en estantería…',
            );
            await tester.enterText(shelfSearch, 'Witcher');
            await harness.settleFrames(tester, count: 6);
            expect(
              find.byTooltip('The Witcher 3: Wild Hunt'),
              findsOneWidget,
            );
            expect(find.byTooltip('Elden Ring'), findsNothing);

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await harness.pumpUntilFound(
              tester,
              find.byTooltip('Elden Ring'),
            );

            // Cambiar a vista portadas y filtrar por PS5 para editar/eliminar el ítem de Elden Ring.
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Estilo portadas (GameCards)'),
            );
            await harness.tapWhenReady(tester, find.text('PS5 (1)'));
            await harness.settleFrames(tester, count: 6);
            expect(harness.findGameCardByTitle('Elden Ring'), findsOneWidget);
            expect(
              harness.findGameCardByTitle('The Witcher 3: Wild Hunt'),
              findsNothing,
            );

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.EditOutlined),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¿En qué plataforma lo tienes?'),
            );
            // Desmarcar PlayStation 5 y guardar -> elimina Elden Ring de user_game_platforms.
            await harness.tapWhenReady(
              tester,
              find.text('PlayStation 5'),
              useLast: true,
            );
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(FilledButton, 'Guardar'),
            );
            await harness.pumpUntilGone(
              tester,
              find.text('¿En qué plataforma lo tienes?'),
            );

            expect(backend.tableRows('user_game_platforms'), hasLength(2));
            await harness.pumpUntilFound(tester, find.text('Todas (2)'));

            // 4. Abrir CollectionShelfScreen autenticado y verificar sincronización.
            DeepLinkService.navigatorKey.currentState!.push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.privateCollection),
                builder: (_) => const CollectionShelfScreen(),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(CollectionShelfScreen),
            );
            expect(find.text('Mi Estantería'), findsOneWidget);
            await harness.pumpUntilFound(
              tester,
              find.descendant(
                of: find.byType(CollectionShelfScreen),
                matching: find.text('Todas (2)'),
              ),
            );
            expect(
              find.descendant(
                of: find.byType(CollectionShelfScreen),
                matching: find.text('Selección masiva'),
              ),
              findsOneWidget,
            );
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );
  });
}
