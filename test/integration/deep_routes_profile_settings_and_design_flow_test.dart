import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/deep_route_resolver.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/screens/activity/grouped_post_details_screen.dart';
import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/bundles/bundle_details_screen.dart';
import 'package:corpus/screens/design/design_screen.dart';
import 'package:corpus/screens/home/home_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';
import 'package:corpus/screens/profile/achievements_screen.dart';
import 'package:corpus/screens/profile/edit_profile_screen.dart';
import 'package:corpus/screens/profile/profile_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/screens/social/notifications_feed_screen.dart';
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

  group('Deep Routes, Scroll-to-Top, EditProfile, Settings Debug y DesignScreen', () {
    testWidgets(
      'DeepRouteResolver construye las 9 TabDeepRoute, devuelve null en inexistentes y re-tap en pestaña vuelve arriba',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true)
          ..seedAchievementsCatalog()
          ..seedBeatenGame(gameId: FakeSupabaseBackend.eldenRingId);
        final reviewId = seeded.tableRows('reviews').last['id'] as String;
        final bundleId = seeded.seedActiveBundle();
        final groupedPostId = seeded.seedGroupedFriendActivity(
          userId: FakeSupabaseBackend.friendUserId,
          gameIds: const <int>[
            FakeSupabaseBackend.eldenRingId,
            FakeSupabaseBackend.hollowKnightId,
          ],
        );

        await harness.run(
          tester,
          (backend) async {
            final navContext = tester.element(find.byType(HomeScreen));
            final navigator = Navigator.of(navContext);

            Future<void> pushAndVerifyDeepRoute(
              TabDeepRoute deepRoute,
              Type expectedScreenType,
            ) async {
              final route = await tester.runAsync(
                () => DeepRouteResolver.buildRoute(deepRoute),
              );
              expect(
                route,
                isNotNull,
                reason: 'Se esperaba Route válida para $deepRoute',
              );
              // ignore: unawaited_futures
              navigator.push(route!);
              await harness.pumpUntilFound(
                tester,
                find.byType(expectedScreenType),
              );
              await harness.settleFrames(tester, count: 4);
              navigator.pop();
              await harness.pumpUntilGone(
                tester,
                find.byType(expectedScreenType),
              );
            }

            await pushAndVerifyDeepRoute(
              const GameDeepRoute(FakeSupabaseBackend.eldenRingId),
              GameDetailsScreen,
            );
            await pushAndVerifyDeepRoute(
              BundleDeepRoute(bundleId),
              BundleDetailsScreen,
            );
            await pushAndVerifyDeepRoute(
              const ProfileDeepRoute(FakeSupabaseBackend.friendUserId),
              ProfileScreen,
            );
            await pushAndVerifyDeepRoute(
              const FriendsDeepRoute(),
              FriendsScreen,
            );
            await pushAndVerifyDeepRoute(
              const NotificationsFeedDeepRoute(),
              NotificationsFeedScreen,
            );
            await pushAndVerifyDeepRoute(
              ReviewDeepRoute(reviewId),
              ReviewDetailsScreen,
            );
            await pushAndVerifyDeepRoute(
              GroupedPostDeepRoute(groupedPostId),
              GroupedPostDetailsScreen,
            );
            await pushAndVerifyDeepRoute(
              const AchievementsDeepRoute(
                userId: FakeSupabaseBackend.primaryUserId,
              ),
              AchievementsScreen,
            );
            await pushAndVerifyDeepRoute(
              const AchievementGamesDeepRoute(
                userId: FakeSupabaseBackend.primaryUserId,
                achievementId: 'fromsoftware_1',
              ),
              AchievementGamesScreen,
            );

            // IDs inexistentes -> devuelve null de forma limpia.
            final missingGame = await tester.runAsync(
              () => DeepRouteResolver.buildRoute(const GameDeepRoute(99999999)),
            );
            final missingBundle = await tester.runAsync(
              () => DeepRouteResolver.buildRoute(
                const BundleDeepRoute('00000000-0000-4000-8000-000000000999'),
              ),
            );
            final missingReview = await tester.runAsync(
              () => DeepRouteResolver.buildRoute(
                const ReviewDeepRoute('00000000-0000-4000-8000-000000000999'),
              ),
            );
            expect(missingGame, isNull);
            expect(missingBundle, isNull);
            expect(missingReview, isNull);

            // Hacer scroll en HomeScreen y re-pulsar la pestaña activa "Inicio" -> vuelve arriba (0.0).
            final homeScrollView = find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(CustomScrollView),
            );
            await tester.drag(homeScrollView.first, const Offset(0, -600));
            await harness.settleFrames(tester, count: 4);
            final scrollable = tester.state<ScrollableState>(
              find.descendant(
                of: homeScrollView.first,
                matching: find.byType(Scrollable),
              ).first,
            );
            expect(scrollable.position.pixels, greaterThan(100));

            await harness.tapTab(tester, 'Inicio');
            await tester.pump(const Duration(milliseconds: 450));
            await harness.settleFrames(tester, count: 4);
            expect(scrollable.position.pixels, lessThan(20));

            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'EditProfileScreen detecta username duplicado y guarda plataformas seleccionadas',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
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
            await harness.settleFrames(tester, count: 6);

            // 1. Colisión de nombre de usuario existente ('amigogamer').
            final usernameField = find.widgetWithText(
              TextField,
              FakeSupabaseBackend.primaryUsername,
            );
            await tester.enterText(usernameField, 'amigogamer');
            await tester.pump();
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Cambios'),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Ese nombre de usuario ya está en uso.'),
            );
            await tester.pump(const Duration(seconds: 4));

            // 2. Cambiar username válido y activar plataformas 'xbox' y 'switch'.
            await tester.enterText(
              find.widgetWithText(TextField, 'amigogamer'),
              'tester_pro',
            );
            await tester.pump();

            final xboxBadge = find.byKey(const ValueKey('xbox'));
            final switchBadge = find.byKey(const ValueKey('switch'));
            await tester.ensureVisible(xboxBadge);
            await harness.tapWhenReady(tester, xboxBadge);
            await tester.ensureVisible(switchBadge);
            await harness.tapWhenReady(tester, switchBadge);

            await harness.tapWhenReady(
              tester,
              find.text('Guardar Cambios'),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Perfil guardado correctamente'),
            );

            final updatedUser = backend
                .tableRows('users')
                .firstWhere((u) => u['id'] == FakeSupabaseBackend.primaryUserId);
            expect(updatedUser['username'], 'tester_pro');
            expect(
              updatedUser['platforms'],
              containsAll(<String>['xbox', 'switch']),
            );
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'SettingsScreen activa DuracionDe (fetch-duracionde-time) y DEBUG: Vaciar cuenta elimina juegos y reseñas',
      (tester) async {
        final seeded = FakeSupabaseBackend()
          ..seedBeatenGame(gameId: FakeSupabaseBackend.eldenRingId)
          ..seedBeatenGame(gameId: FakeSupabaseBackend.hollowKnightId);

        await harness.run(
          tester,
          (backend) async {
            // 1. Activar DuracionDe (experimental) en Ajustes.
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
            await harness.pumpUntilFound(
              tester,
              find.text('DuracionDe (experimental)'),
            );
            await harness.tapWhenReady(
              tester,
              find.text('DuracionDe (experimental)'),
            );
            await harness.settleFrames(tester, count: 4);

            // Volver atrás y comprobar DuracionDe en GameInfoTab de Elden Ring.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);
            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            await harness.tapWhenReady(tester, find.text('Información'));
            await harness.pumpUntilFound(
              tester,
              find.text('Tiempo estimado (duracionde.com)'),
            );
            expect(find.text('58 h'), findsOneWidget);
            expect(find.text('100 h'), findsOneWidget);
            expect(find.text('134 h'), findsOneWidget);
            expect(
              backend.requestedPaths
                  .contains('POST /functions/v1/fetch-duracionde-time'),
              isTrue,
            );

            // Volver y abrir Ajustes -> DEBUG: Vaciar cuenta.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));

            await tester.dragUntilVisible(
              find.text('DEBUG: Vaciar cuenta'),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            await harness.tapWhenReady(
              tester,
              find.text('DEBUG: Vaciar cuenta'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¿Vaciar cuenta por completo?'),
            );
            await harness.tapWhenReady(tester, find.text('VACIAR CUENTA'));
            await harness.pumpUntilFound(
              tester,
              find.text('Cuenta vaciada limpiamente.'),
            );

            expect(
              backend
                  .tableRows('reviews')
                  .where((r) => r['user_id'] == FakeSupabaseBackend.primaryUserId),
              isEmpty,
            );
            expect(
              backend
                  .tableRows('user_games')
                  .where(
                    (ug) => ug['user_id'] == FakeSupabaseBackend.primaryUserId,
                  ),
              isEmpty,
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'DesignScreen (/design) recorre las 8 categorías del sistema de diseño sin errores ni overflows',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
        };

        try {
          await harness.run(
            tester,
            (backend) async {
              final navContext = tester.element(find.byType(HomeScreen));
              // ignore: unawaited_futures
              navContext.pushRoute<void>(AppRoutes.design);
              await harness.pumpUntilFound(tester, find.byType(DesignScreen));
              await harness.settleFrames(tester, count: 6);

              for (final category in const <String>[
                'Fundamentos',
                'Botones',
                'Inputs',
                'Selección',
                'Navegación',
                'Feedback',
                'Superficies',
                'Style packs',
              ]) {
                await harness.tapWhenReady(tester, find.text(category));
                await harness.settleFrames(tester, count: 4);
              }

              expect(
                errors
                    .map((e) => '${e.context}: ${e.exception}')
                    .toList(),
                isEmpty,
              );
              expect(tester.takeException(), isNull);
            },
            loggedIn: true,
          );
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });
}
