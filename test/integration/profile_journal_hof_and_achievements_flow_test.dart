import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';
import 'package:corpus/screens/profile/achievements_screen.dart';
import 'package:corpus/screens/profile/edit_profile_screen.dart';
import 'package:corpus/screens/profile/hall_of_fame_selector_screen.dart';
import 'package:corpus/screens/profile/profile_screen.dart';
import 'package:corpus/screens/profile/widgets/profile_giant_stats.dart';
import 'package:corpus/screens/profile/widgets/profile_hall_of_fame.dart';
import 'package:corpus/screens/profile/widgets/profile_ratings_histogram.dart';
import 'package:corpus/screens/profile/widgets/profile_sidebar_info.dart';
import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/level_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Perfil personal, Diario, Hall of Fame y Logros', () {
    testWidgets(
      'Perfil — estadísticas gigantes, histograma, sidebar, CurrentlyPlayingBadge, GamesGridTab y ReviewsTab',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.eldenRingId,
            rating: 10.0,
            completionType: '100_percent',
            comment: 'Obra maestra absoluta.',
            createdAt: '2026-05-15T12:00:00Z',
          )
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.hollowKnightId,
            rating: 9.0,
            completionType: 'story',
            comment: 'Metroidvania inolvidable.',
            createdAt: '2025-11-10T12:00:00Z',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.witcher3Id,
            status: 'playing',
          )
          ..seedUserGame(
            gameId: FakeSupabaseBackend.baldursGate3Id,
            status: 'wishlist',
          )
          ..seedCurrentlyPlaying(
            steamAppId: 1245620,
            gameName: 'Elden Ring',
          )
          ..seedUserPlatforms(
            platforms: <String>['pc', 'playstation'],
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(
              tester,
              find.byType(ProfileGiantStats),
            );
            await harness.settleFrames(tester, count: 8);

            // 1. Verificar cabecera, CurrentlyPlayingBadge, sidebar, histograma y stats.
            expect(find.text('Jugando: Elden Ring'), findsOneWidget);
            expect(find.byType(ProfileSidebarInfo), findsOneWidget);
            expect(find.text('Bio'), findsOneWidget);
            expect(find.text('Plataformas'), findsOneWidget);

            expect(find.byType(ProfileRatingsHistogram), findsOneWidget);
            expect(find.text('Calificaciones'), findsOneWidget);
            expect(find.text('1★'), findsOneWidget);
            expect(find.text('10★'), findsOneWidget);
            expect(find.textContaining('Media'), findsOneWidget);

            final giantStats = find.byType(ProfileGiantStats);
            expect(
              find.descendant(of: giantStats, matching: find.text('002')),
              findsOneWidget,
            );
            expect(
              find.descendant(of: giantStats, matching: find.text('001')),
              findsNWidgets(3),
            );
            expect(
              find.descendant(
                of: giantStats,
                matching: find.text('Completados'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: giantStats,
                matching: find.text('Platinos'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: giantStats,
                matching: find.text('En Wishlist'),
              ),
              findsOneWidget,
            );

            // Pulsar CurrentlyPlayingBadge desde la cabecera de Perfil -> abre ficha de juego.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Jugando: Elden Ring'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Elden Ring'), findsWidgets);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(GameDetailsScreen),
            );

            // 2. Pulsar 'Platinos' en ProfileGiantStats -> salta a pestaña Juegos filtrada.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: giantStats,
                matching: find.text('Platinos'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );
            expect(harness.findGameCardByTitle('Hollow Knight'), findsNothing);

            // Cambiar chip a 'Terminado' y probar buscador.
            await harness.tapWhenReady(
              tester,
              find.widgetWithText(ChoiceChip, 'Terminado'),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Hollow Knight'),
            );
            expect(harness.findGameCardByTitle('Elden Ring'), findsOneWidget);

            final profileGameSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juego...',
            );
            await tester.enterText(profileGameSearch, 'Hollow');
            await tester.pump(const Duration(milliseconds: 600));
            await harness.settleFrames(tester, count: 6);
            expect(harness.findGameCardByTitle('Hollow Knight'), findsOneWidget);
            expect(harness.findGameCardByTitle('Elden Ring'), findsNothing);

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle('Elden Ring'),
            );

            // 3. Pestaña Reseñas de Perfil + búsqueda + abrir detalle.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(ProfileScreen),
                matching: find.text('Reseñas'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Obra maestra absoluta.'),
            );
            expect(find.text('Metroidvania inolvidable.'), findsOneWidget);

            final reviewsSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar reseña por juego...',
            );
            await tester.enterText(reviewsSearch, 'Elden');
            await tester.pump(const Duration(milliseconds: 600));
            await harness.settleFrames(tester, count: 6);
            expect(find.text('Obra maestra absoluta.'), findsOneWidget);
            expect(find.text('Metroidvania inolvidable.'), findsNothing);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Obra maestra absoluta.'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'ProfileJournalTab (diario cronológico y filtro por año) + HallOfFameSelectorScreen y ProfileHallOfFame',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.eldenRingId,
            rating: 10.0,
            comment: 'Diario 2026',
            createdAt: '2026-05-15T12:00:00Z',
          )
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.hollowKnightId,
            rating: 9.0,
            comment: 'Diario 2025',
            createdAt: '2025-11-12T12:00:00Z',
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(
              tester,
              find.byType(ProfileHallOfFame),
            );

            // 1. Sub-pestaña Diario: agrupación por mes/año y filtro por año.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(ProfileScreen),
                matching: find.text('Diario'),
              ),
            );
            await harness.pumpUntilFound(tester, find.text('Mayo, 2026'));
            expect(find.text('Noviembre, 2025'), findsOneWidget);
            expect(find.text('15'), findsOneWidget);
            expect(find.text('12'), findsOneWidget);
            expect(find.text('Elden Ring'), findsOneWidget);
            expect(find.text('Hollow Knight'), findsOneWidget);

            // Filtrar por año 2025.
            await harness.tapWhenReady(
              tester,
              find.byType(DropdownButtonFormField<int?>),
            );
            await harness.tapWhenReady(tester, find.text('2025'), useLast: true);
            await harness.settleFrames(tester, count: 6);
            expect(find.text('Noviembre, 2025'), findsOneWidget);
            expect(find.text('Mayo, 2026'), findsNothing);

            // Volver a 'Todos' y abrir la entrada de Elden Ring.
            await harness.tapWhenReady(
              tester,
              find.byType(DropdownButtonFormField<int?>),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Todos'),
              useLast: true,
            );
            await harness.pumpUntilFound(tester, find.text('Mayo, 2026'));

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Elden Ring'));
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );

            // 2. Configurar Hall of Fame en EditProfileScreen -> HallOfFameSelectorScreen.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Cuenta'));
            await harness.pumpUntilFound(
              tester,
              find.byType(EditProfileScreen),
            );

            final hofTitle = find.text('Hall of Fame (Toca para editar)');
            await tester.scrollUntilVisible(
              hofTitle,
              250,
              scrollable: find.byType(Scrollable).last,
            );
            await harness.settleFrames(tester, count: 6);

            final hofRow = find.byWidgetPredicate(
              (w) =>
                  w is Row &&
                  w.mainAxisAlignment == MainAxisAlignment.spaceBetween &&
                  w.children.length == 5,
            );
            final hofSlots = find.descendant(
              of: hofRow,
              matching: find.byType(GestureDetector),
            );

            // Elegir hueco #1 -> buscar y fijar Elden Ring.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, hofSlots.at(0));
            await harness.pumpUntilFound(
              tester,
              find.byType(HallOfFameSelectorScreen),
            );
            expect(find.text('Pin #1'), findsOneWidget);

            final selectorSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar juego...',
            );
            await tester.enterText(selectorSearch, 'Elden');
            await harness.settleFrames(tester, count: 4);

            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(GridView),
                matching: find.byType(GestureDetector),
              ).first,
            );
            await harness.pumpUntilGone(
              tester,
              find.byType(HallOfFameSelectorScreen),
            );
            expect(
              backend.tableRows('hall_of_fame').where(
                    (r) =>
                        r['pin_order'] == 1 &&
                        r['game_id'] == FakeSupabaseBackend.eldenRingId,
                  ),
              hasLength(1),
            );

            // Reabrir Pin #1 y vaciar el hueco.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: hofRow,
                matching: find.byType(GestureDetector),
              ).first,
            );
            await harness.pumpUntilFound(tester, find.byTooltip('Vaciar hueco'));
            await harness.tapWhenReady(tester, find.byTooltip('Vaciar hueco'));
            await harness.pumpUntilGone(
              tester,
              find.byType(HallOfFameSelectorScreen),
            );
            expect(backend.tableRows('hall_of_fame'), isEmpty);

            // Fijar Elden Ring en el hueco central (#3 dorado).
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: hofRow,
                matching: find.byType(GestureDetector),
              ).at(2),
            );
            await harness.pumpUntilFound(tester, find.text('Pin #3'));
            await tester.enterText(
              find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.hintText == 'Buscar juego...',
              ),
              'Elden',
            );
            await harness.settleFrames(tester, count: 4);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(GridView),
                matching: find.byType(GestureDetector),
              ).first,
            );
            await harness.pumpUntilGone(
              tester,
              find.byType(HallOfFameSelectorScreen),
            );
            expect(
              backend.tableRows('hall_of_fame').where(
                    (r) =>
                        r['pin_order'] == 3 &&
                        r['game_id'] == FakeSupabaseBackend.eldenRingId,
                  ),
              hasLength(1),
            );

            // Volver a ProfileScreen y verificar ProfileHallOfFame + navegación al juego.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(EditProfileScreen),
            );
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(tester, find.byType(SettingsScreen));

            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(ProfileScreen),
                matching: find.text('Perfil'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ProfileHallOfFame),
            );

            // El slot #3 de ProfileHallOfFame debe abrir GameDetailsScreen al pulsarlo.
            final profileHofTap = find
                .descendant(
                  of: find.byType(ProfileHallOfFame),
                  matching: find.byType(GestureDetector),
                )
                .at(2);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, profileHofTap);
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            expect(find.text('Elden Ring'), findsWidgets);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Logros — ProfileAchievementsTab, AchievementsScreen y AchievementGamesScreen',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedAchievementsCatalog()
          ..seedBeatenGame(
            gameId: FakeSupabaseBackend.eldenRingId,
            rating: 10.0,
            comment: 'FromSoft!',
          )
          ..seedUserAchievement(achievementId: 'fromsoftware_1');

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(
              tester,
              find.byType(LevelProgressBar),
            );

            // 1. Sub-pestaña Logros dentro de ProfileScreen.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(ProfileScreen),
                matching: find.text('Logros'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Logros e Hitos Conseguidos (1)'),
            );
            expect(find.text('FromSoftware'), findsOneWidget);
            expect(find.text('Novato (Bronce)'), findsOneWidget);

            // Tocar el logro abre AchievementGamesScreen.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('FromSoftware'));
            await harness.pumpUntilFound(
              tester,
              find.byType(AchievementGamesScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Progreso de la Saga'),
            );
            expect(find.text('1 juegos completados'), findsOneWidget);
            expect(find.text('Siguiente hito: 3'), findsOneWidget);
            expect(harness.findGameCardByTitle('Elden Ring'), findsOneWidget);

            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(AchievementGamesScreen),
            );

            // 2. Pulsar barra de nivel -> AchievementsScreen completa.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.byType(LevelProgressBar),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(AchievementsScreen),
            );
            await harness.pumpUntilFound(tester, find.text('250 XP Total'));

            // Abrir diálogo de ayuda '¿Cómo ganar XP?'.
            await harness.tapWhenReady(
              tester,
              find.byTooltip('¿Cómo ganar XP?'),
            );
            await harness.pumpUntilFound(tester, find.text('¿Cómo ganar XP?'));
            await harness.tapWhenReady(tester, find.text('Entendido'));
            await harness.pumpUntilGone(tester, find.text('¿Cómo ganar XP?'));

            // Filtrar logros en el buscador.
            final achSearch = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar logros...',
            );
            await tester.enterText(achSearch, 'CD Projekt');
            await harness.settleFrames(tester, count: 4);
            expect(
              find.descendant(
                of: find.byType(Card),
                matching: find.text('CD Projekt'),
              ),
              findsOneWidget,
            );
            expect(find.text('Primera Reseña'), findsNothing);

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Clear),
            );
            await harness.pumpUntilFound(tester, find.text('FromSoftware'));

            // Abrir AchievementGamesScreen desde AchievementsScreen.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('FromSoftware'));
            await harness.pumpUntilFound(
              tester,
              find.byType(AchievementGamesScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Progreso de la Saga'),
            );
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );
  });
}
