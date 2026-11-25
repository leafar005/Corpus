import 'package:corpus/globals.dart';
import 'package:corpus/screens/activity/grouped_post_details_screen.dart';
import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/library/search_screen.dart';
import 'package:corpus/screens/profile/profile_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/screens/social/notifications_feed_screen.dart';
import 'package:corpus/widgets/coop_badge.dart';
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

  group('Cooperativo, Citas en Comentarios, Aislamiento de Hilos y Triggers', () {
    testWidgets(
      'ReviewModal guarda compañero cooperativo (partner_ids) y Actividad/ReviewDetailsScreen muestran CoopBadge',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true);

        await harness.run(
          tester,
          (backend) async {
            await harness.searchAndOpenGame(tester, 'Elden Ring');
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // Abrir ReviewModal.
            await harness.tapWhenReady(
              tester,
              find.text('Añadir a Biblioteca'),
            );
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));

            await harness.tapWhenReady(tester, find.text('Terminado'));

            // Expandir Información Extra y seleccionar a @amigogamer como compañero.
            final extraTile = find.text('Información Extra');
            await tester.ensureVisible(extraTile);
            await harness.tapWhenReady(tester, extraTile);
            await harness.pumpUntilFound(
              tester,
              find.text('Compañero (Cooperativo)'),
            );
            await harness.settleFrames(tester, count: 8);

            final partnerDropdown = find.byType(DropdownMenu<String>);
            await tester.ensureVisible(partnerDropdown);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: partnerDropdown,
                matching: find.byType(IconButton),
              ),
            );
            await harness.settleFrames(tester, count: 6);
            await harness.tapWhenReady(
              tester,
              find.text('Amigo Gamer'),
              useLast: true,
            );
            await harness.pumpUntilFound(tester, find.byType(ListTile));
            await harness.settleFrames(tester, count: 4);

            // Guardar reseña.
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 6);

            final savedReview = backend.tableRows('reviews').lastWhere(
                  (r) =>
                      r['user_id'] == FakeSupabaseBackend.primaryUserId &&
                      r['game_id'] == FakeSupabaseBackend.eldenRingId,
                );
            expect(
              savedReview['partner_ids'],
              contains(FakeSupabaseBackend.friendUserId),
            );
            final savedUg = backend.tableRows('user_games').firstWhere(
                  (ug) =>
                      ug['user_id'] == FakeSupabaseBackend.primaryUserId &&
                      ug['game_id'] == FakeSupabaseBackend.eldenRingId,
                );
            expect(
              savedUg['partner_ids'],
              contains(FakeSupabaseBackend.friendUserId),
            );

            // Volver al shell e ir a Actividad para comprobar CoopBadge.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 6);
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(tester, find.byType(CoopBadge));
            expect(find.text('Jugado con @amigogamer'), findsOneWidget);

            // Pulsar el CoopBadge navega al perfil de @amigogamer.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.byType(CoopBadge).first);
            await harness.pumpUntilFound(tester, find.byType(ProfileScreen));
            expect(find.text('@amigogamer'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'CommentComposer cita un juego en ReviewDetailsScreen (búsqueda) y en GroupedPostDetailsScreen (sugeridos)',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true)
          ..seedRecentFriendActivity(
            userId: FakeSupabaseBackend.friendUserId,
            gameId: FakeSupabaseBackend.eldenRingId,
            comment: 'Reseña para citar juego.',
            age: const Duration(minutes: 10),
          );
        seeded.seedGroupedFriendActivity(
          userId: FakeSupabaseBackend.friendUserId,
          gameIds: const <int>[
            FakeSupabaseBackend.hollowKnightId,
            FakeSupabaseBackend.witcher3Id,
          ],
          status: 'wishlist',
          age: const Duration(minutes: 5),
        );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.text('Reseña para citar juego.'),
            );
            await harness.settleFrames(tester, count: 6);

            // 1. Abrir la reseña individual (segundo card, tras el post agrupado más reciente).
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline).at(1),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // Pulsar "Citar juego" -> SearchScreen(isSelectionMode: true) -> elegir Baldur's Gate 3.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.byTooltip('Citar juego'));
            await harness.pumpUntilFound(tester, find.byType(SearchScreen));

            final searchField = find.descendant(
              of: find.byType(SearchScreen),
              matching: find.byType(TextField),
            );
            await tester.enterText(searchField.first, 'Baldur');
            await tester.pump(const Duration(milliseconds: 550));
            await harness.pumpUntilFound(
              tester,
              harness.findGameCardByTitle("Baldur's Gate 3"),
            );
            await harness.tapWhenReady(
              tester,
              harness.findGameCardByTitle("Baldur's Gate 3"),
            );
            await harness.pumpUntilGone(tester, find.byType(SearchScreen));
            await harness.settleFrames(tester, count: 4);

            // Enviar incluso sin texto (solo cita) para validar el envío de cita pura.
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(
              tester,
              find.text("Baldur's Gate 3"),
            );

            final citedComments = backend.tableRows('review_comments').where(
                  (c) => c['attached_game'] != null,
                );
            expect(citedComments, hasLength(1));

            // Tocar la tarjeta citada navega a GameDetailsScreen de Baldur's Gate 3.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text("Baldur's Gate 3"),
              useLast: true,
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );
            Navigator.of(tester.element(find.byType(GameDetailsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            Navigator.of(
              tester.element(find.byType(ReviewDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 2. Abrir el post agrupado (primer card) y citar un juego sugerido desde el bottom sheet.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline).first,
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupedPostDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(tester, find.byTooltip('Citar juego'));
            await harness.pumpUntilFound(tester, find.text('Citar un juego'));
            await harness.tapWhenReady(
              tester,
              find.text('Hollow Knight'),
              useLast: true,
            );
            await harness.settleFrames(tester, count: 4);

            final input = find.descendant(
              of: find.byType(GroupedPostDetailsScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.hintText == 'Escribe un comentario...',
              ),
            );
            await tester.enterText(input, 'Recomiendo empezar por este.');
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(
              tester,
              find.text('Recomiendo empezar por este.'),
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Aislamiento de hilos (20261113000000): interacciones en post agrupado no se filtran a la reseña individual',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true);
        final grouped = seeded.seedGroupedFriendReviews(
          userId: FakeSupabaseBackend.friendUserId,
          gameIds: const <int>[
            FakeSupabaseBackend.eldenRingId,
            FakeSupabaseBackend.hollowKnightId,
          ],
          commentPrefix: 'Reseña agrupada aislada',
        );
        final hollowReviewId = grouped.reviewIds[1];

        await harness.run(
          tester,
          (backend) async {
            // 1. Entrar en Actividad -> abrir GroupedPostDetailsScreen -> dar like y comentar.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline).first,
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupedPostDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(GroupedPostDetailsScreen),
                matching: harness.findCorpusIcon(
                  CorpusIconKind.ThumbUpAltOutlined,
                ),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.descendant(
                of: find.byType(GroupedPostDetailsScreen),
                matching: harness.findCorpusIcon(CorpusIconKind.ThumbUp),
              ),
            );

            final groupedInput = find.descendant(
              of: find.byType(GroupedPostDetailsScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.hintText == 'Escribe un comentario...',
              ),
            );
            const groupedComment = 'Comentario exclusivo del post agrupado';
            await tester.enterText(groupedInput, groupedComment);
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(tester, find.text(groupedComment));

            Navigator.of(
              tester.element(find.byType(GroupedPostDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(GroupedPostDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 2. Abrir la reseña individual de Hollow Knight desde Perfil del amigo -> Reseñas.
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
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Amigo Gamer'));
            await harness.pumpUntilFound(tester, find.byType(ProfileScreen));

            await harness.tapWhenReady(tester, find.text('Reseñas'));
            await harness.pumpUntilFound(
              tester,
              find.text('Hollow Knight'),
            );
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Reseña agrupada aislada #${FakeSupabaseBackend.hollowKnightId}'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // El hilo de la reseña individual NO debe mostrar el like ni el comentario del post agrupado.
            expect(find.text(groupedComment), findsNothing);
            expect(
              find.descendant(
                of: find.byType(ReviewDetailsScreen),
                matching: harness.findCorpusIcon(CorpusIconKind.ThumbUp),
              ),
              findsNothing,
            );

            // Comentar en la reseña individual crea un post_id aislado distinto del post agrupado.
            final reviewInput = find.descendant(
              of: find.byType(ReviewDetailsScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.hintText == 'Escribe un comentario...',
              ),
            );
            const singleComment = 'Comentario aislado en Hollow Knight';
            await tester.enterText(reviewInput, singleComment);
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(tester, find.text(singleComment));

            final isolatedCommentRow = backend
                .tableRows('review_comments')
                .firstWhere((c) => c['content'] == singleComment);
            expect(isolatedCommentRow['post_id'], isNot(grouped.postId));
            expect(isolatedCommentRow['review_id'], hollowReviewId);
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Triggers automáticos de notificaciones generan avisos de like, comentario y solicitud entre usuarios reales',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true)
          ..seedBeatenGame(
            userId: FakeSupabaseBackend.primaryUserId,
            gameId: FakeSupabaseBackend.eldenRingId,
            comment: 'Reseña propia para recibir interacciones.',
          );

        await harness.run(
          tester,
          (backend) async {
            // Sesión 1: Amigo Gamer da Like y comenta la reseña de Player One.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.text('Reseña propia para recibir interacciones.'),
            );
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUpAltOutlined),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUp),
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
            final input = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Escribe un comentario...',
            );
            await tester.enterText(input, '¡Buenísima partida!');
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(
              tester,
              find.text('¡Buenísima partida!'),
            );
            Navigator.of(
              tester.element(find.byType(ReviewDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );

            // Cerrar sesión de Amigo Gamer -> entrar como Explorador Pro para enviar solicitud de amistad.
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
            await tester.dragUntilVisible(
              find.text('Cerrar sesión'),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            await harness.tapWhenReady(tester, find.text('Cerrar sesión'));
            await harness.settleFrames(tester, count: 8);

            await harness.loginViaUi(
              tester,
              email: 'buscable@corpus.test',
              password: 'Password123!',
            );

            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 6);
            await harness.waitForPushDebounce(tester);
            final friendsBtn1 = find.byTooltip('Amigos');
            if (friendsBtn1.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, friendsBtn1);
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
            await tester.enterText(searchUserField, 'playerone');
            await tester.pump(const Duration(milliseconds: 650));
            await harness.settleFrames(tester, count: 6);
            await harness.tapWhenReady(tester, find.text('Añadir'));
            await harness.pumpUntilFound(tester, find.text('Enviado'));
            Navigator.of(tester.element(find.byType(FriendsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(FriendsScreen));

            // Cerrar sesión de Explorador -> volver como Player One y comprobar las 3 notificaciones automáticas.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.Settings),
            );
            await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
            await tester.dragUntilVisible(
              find.text('Cerrar sesión'),
              find.byType(ListView).last,
              const Offset(0, -300),
            );
            await harness.tapWhenReady(tester, find.text('Cerrar sesión'));
            await harness.settleFrames(tester, count: 8);

            await harness.loginViaUi(
              tester,
              email: FakeSupabaseBackend.primaryEmail,
              password: FakeSupabaseBackend.primaryPassword,
            );

            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.byTooltip('Notificaciones'),
            );
            await harness.settleFrames(tester, count: 6);
            expect(unreadNotificationsCount.value, 3);

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Notificaciones'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(NotificationsFeedScreen),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Amigo Gamer le dio like a tu reseña de Elden Ring'),
            );
            expect(
              find.text('Amigo Gamer comentó tu reseña de Elden Ring'),
              findsOneWidget,
            );
            expect(
              find.text('Explorador Pro te envió una solicitud de amistad'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
          customBackend: seeded,
          loggedIn: true,
          email: 'amigo@corpus.test',
          password: 'Password123!',
        );
      },
    );
  });
}
