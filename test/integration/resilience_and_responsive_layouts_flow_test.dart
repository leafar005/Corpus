import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
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

  group('Resiliencia HTTP y Layouts Responsive', () {
    testWidgets(
      'Resiliencia ante errores HTTP 500, 401 y TimeoutException en carga inicial, reseña y acciones sociales',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true)
          ..seedFriendReview(
            userId: FakeSupabaseBackend.friendUserId,
            gameId: FakeSupabaseBackend.hollowKnightId,
            comment: 'Reseña para probar errores de red sociales.',
          );

        await harness.run(
          tester,
          (backend) async {
            // 1. Error HTTP 500 en carga inicial de Perfil y recuperación con Reintentar.
            backend.httpErrorOverride = (method, uri) {
              if (method == 'GET' && uri.path == '/rest/v1/users') return 500;
              return null;
            };

            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(
              tester,
              find.text('No se pudo cargar el perfil.'),
            );
            expect(find.text('Reintentar'), findsOneWidget);

            backend.httpErrorOverride = null;
            await harness.tapWhenReady(tester, find.text('Reintentar'));
            await harness.pumpUntilFound(
              tester,
              find.textContaining('playerone'),
            );
            expect(tester.takeException(), isNull);

            // 2. Fallos 500 y 401 al guardar una reseña sin corromper datos ni crashear, + éxito al reintentar.
            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.tapWhenReady(
              tester,
              find.text('Añadir a Biblioteca'),
            );
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(
              tester,
              find.text('Terminado'),
              useLast: true,
            );
            final reviewInput = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == '¿Qué te pareció el juego?',
            );
            await tester.enterText(
              reviewInput,
              'Reseña resiliente tras errores 500 y 401.',
            );
            await tester.pump();

            // Inyectar HTTP 500 al guardar reseña.
            backend.httpErrorOverride = (method, uri) {
              if (method == 'POST' && uri.path == '/rest/v1/reviews') {
                return 500;
              }
              return null;
            };
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.textContaining('Error al guardar'),
            );
            expect(find.text('Añadir Reseña'), findsOneWidget);
            expect(
              backend
                  .tableRows('reviews')
                  .where(
                    (r) =>
                        r['user_id'] == FakeSupabaseBackend.primaryUserId &&
                        r['game_id'] == FakeSupabaseBackend.eldenRingId,
                  ),
              isEmpty,
            );

            // Inyectar HTTP 401 al guardar reseña.
            backend.httpErrorOverride = (method, uri) {
              if (method == 'POST' && uri.path == '/rest/v1/reviews') {
                return 401;
              }
              return null;
            };
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.settleFrames(tester, count: 6);
            expect(find.text('Añadir Reseña'), findsOneWidget);
            expect(
              backend
                  .tableRows('reviews')
                  .where(
                    (r) =>
                        r['user_id'] == FakeSupabaseBackend.primaryUserId &&
                        r['game_id'] == FakeSupabaseBackend.eldenRingId,
                  ),
              isEmpty,
            );

            // Quitar bloqueo HTTP y guardar con éxito.
            backend.httpErrorOverride = null;
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 8);
            expect(
              backend
                  .tableRows('reviews')
                  .where(
                    (r) =>
                        r['user_id'] == FakeSupabaseBackend.primaryUserId &&
                        r['game_id'] == FakeSupabaseBackend.eldenRingId,
                  ),
              hasLength(1),
            );

            // Volver a MainScreen.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 8);

            // 3. Acciones sociales con TimeoutException y HTTP 500.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.text('Reseña para probar errores de red sociales.'),
            );

            backend.timeoutOverride = (method, uri) {
              return method == 'POST' && uri.path == '/rest/v1/review_likes';
            };
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUpAltOutlined),
            );
            await harness.settleFrames(tester, count: 6);
            expect(backend.tableRows('review_likes'), isEmpty);
            expect(tester.takeException(), isNull);
            backend.timeoutOverride = null;

            // Enviar solicitud de amistad con HTTP 500 en friendships.
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
            await harness.waitForPushDebounce(tester);
            final friendsBtn = find.byTooltip('Amigos');
            if (friendsBtn.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, friendsBtn);
            } else {
              await harness.tapWhenReady(tester, find.textContaining('amigo'));
            }
            await harness.pumpUntilFound(tester, find.byType(FriendsScreen));

            await harness.tapWhenReady(tester, find.text('Buscar'));
            final searchUserField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar por nombre de usuario…',
            );
            await harness.pumpUntilFound(tester, searchUserField);
            await tester.enterText(searchUserField, 'explorador');
            await tester.pump(const Duration(milliseconds: 650));
            await harness.pumpUntilFound(tester, find.text('Añadir'));

            backend.httpErrorOverride = (method, uri) {
              if (method == 'POST' && uri.path == '/rest/v1/friendships') {
                return 500;
              }
              return null;
            };
            await harness.tapWhenReady(tester, find.text('Añadir'));
            await harness.settleFrames(tester, count: 6);

            // No debe haberse persistido la amistad tras el 500 ni haber excepción sin capturar.
            expect(
              backend.tableRows('friendships').where(
                    (f) =>
                        f['addressee_id'] ==
                        FakeSupabaseBackend.searchableUserId,
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

    Future<void> runResponsiveSweep(
      WidgetTester tester, {
      required Size viewportSize,
      required bool floatingMobileNav,
    }) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      final seeded = FakeSupabaseBackend(seedSocialData: true)
        ..seedBeatenGame(
          gameId: FakeSupabaseBackend.eldenRingId,
          rating: 9.5,
          comment:
              'Reseña extensa para validar comportamiento responsive sin overflows.',
        )
        ..seedFriendReview(
          userId: FakeSupabaseBackend.friendUserId,
          gameId: FakeSupabaseBackend.hollowKnightId,
          comment:
              'Comentario de amigo largo para comprobar ReviewDetailsScreen en múltiples anchos.',
        );
      final friendReviewId =
          seeded.tableRows('reviews').last['id'] as String;
      final friendPostId =
          seeded.tableRows('feed_posts').last['id'] as String;
      seeded.seedReviewComment(
        userId: FakeSupabaseBackend.friendUserId,
        reviewId: friendReviewId,
        postId: friendPostId,
        content: 'Totalmente de acuerdo, el diseño es sobresaliente.',
      );

      try {
        await harness.run(
          tester,
          (backend) async {
            // 1. GameDetailsScreen y sus pestañas principales.
            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            for (final tab in const <String>[
              'Información',
              'Media',
              'Relacionado',
              'Links',
              'Comunidad',
            ]) {
              final tabFinder = find.text(tab);
              if (tabFinder.evaluate().isNotEmpty) {
                await harness.tapWhenReady(tester, tabFinder.first);
                await harness.settleFrames(tester, count: 4);
              }
            }
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 8);

            // 2. ReviewDetailsScreen desde Actividad.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.textContaining('Comentario de amigo largo'),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Totalmente de acuerdo, el diseño es sobresaliente.'),
            );
            await harness.settleFrames(tester, count: 6);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 8);

            // 3. FriendsScreen (Amigos, Solicitudes, Buscar).
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);

            await harness.waitForPushDebounce(tester);
            final friendsBtn = find.byTooltip('Amigos');
            if (friendsBtn.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, friendsBtn);
            } else {
              await harness.tapWhenReady(tester, find.textContaining('amigo'));
            }
            await harness.pumpUntilFound(tester, find.byType(FriendsScreen));
            await harness.tapWhenReady(tester, find.text('Solicitudes'));
            await harness.settleFrames(tester, count: 4);
            await harness.tapWhenReady(tester, find.text('Buscar'));
            await harness.settleFrames(tester, count: 4);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 8);

            // 4. SettingsScreen (con scroll completo).
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
            await tester.drag(find.byType(ListView).last, const Offset(0, -300));
            await harness.settleFrames(tester, count: 6);
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);

            expect(
              errors,
              isEmpty,
              reason: errors.map((e) => e.exceptionAsString()).join('\n'),
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          viewportSize: viewportSize,
          floatingMobileNav: floatingMobileNav,
          loggedIn: true,
        );
      } finally {
        FlutterError.onError = originalOnError;
      }
    }

    testWidgets(
      'Responsive 1280x800 (desktop/tablet) en GameDetailsScreen, ReviewDetailsScreen, FriendsScreen y SettingsScreen',
      (tester) async {
        await runResponsiveSweep(
          tester,
          viewportSize: const Size(1280, 800),
          floatingMobileNav: true,
        );
      },
    );

    testWidgets(
      'Responsive 360x640 (móvil compacto) en GameDetailsScreen, ReviewDetailsScreen, FriendsScreen y SettingsScreen',
      (tester) async {
        await runResponsiveSweep(
          tester,
          viewportSize: const Size(360, 640),
          floatingMobileNav: false,
        );
      },
    );

    testWidgets(
      'Debounce anti-doble-tap de 600 ms descarta un segundo push inmediato',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 8);

            // Reactivamos el debounce real de producción solo para esta aserción.
            kDisablePushDebounceForTests = false;
            resetPushDebounceForTesting();
            addTearDown(() {
              kDisablePushDebounceForTests = false;
              resetPushDebounceForTesting();
            });

            final settingsBtn = harness.findCorpusIcon(CorpusIconKind.Settings);
            expect(settingsBtn.hitTestable(), findsOneWidget);

            // Dos pulsaciones consecutivas en el mismo ciclo (<600 ms) -> solo debe abrir 1 pantalla.
            await tester.tap(settingsBtn.first);
            await tester.pump();
            if (settingsBtn.hitTestable().evaluate().isNotEmpty) {
              await tester.tap(settingsBtn.first);
            }
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
            await harness.settleFrames(tester, count: 6);

            expect(
              find.byType(SettingsScreen, skipOffstage: false),
              findsOneWidget,
            );

            // Un único pop vuelve directamente al perfil raíz (sin segunda copia apilada).
            Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(SettingsScreen));
            expect(
              find.byType(SettingsScreen, skipOffstage: false),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );
  });
}
