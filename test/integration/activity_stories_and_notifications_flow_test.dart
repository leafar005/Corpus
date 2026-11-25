import 'package:corpus/globals.dart';
import 'package:corpus/screens/activity/activity_story_viewer.dart';
import 'package:corpus/screens/activity/grouped_post_details_screen.dart';
import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/screens/social/notifications_feed_screen.dart';
import 'package:corpus/widgets/activity_story_ring.dart';
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

  group('Actividad, Historias, Posts Agrupados y Notificaciones', () {
    testWidgets(
      'Badge de actividad no leída se limpia al abrir Actividad, unlike y borrar comentario raíz propio',
      (tester) async {
        final seededBackend = FakeSupabaseBackend(seedSocialData: true)
          ..setLastActivityReadAt(
            FakeSupabaseBackend.primaryUserId,
            DateTime.now().toUtc().subtract(const Duration(hours: 4)),
          )
          ..seedRecentFriendActivity(
            userId: FakeSupabaseBackend.friendUserId,
            gameId: FakeSupabaseBackend.eldenRingId,
            comment: 'Nueva actividad reciente',
            age: const Duration(minutes: 10),
          );

        await harness.run(
          tester,
          (backend) async {
            // 1. El badge de actividad no leída se carga en MainScreen al iniciar en Inicio.
            final deadline = DateTime.now().add(const Duration(seconds: 6));
            while (unreadActivityCount.value == 0 &&
                DateTime.now().isBefore(deadline)) {
              await tester.pump(const Duration(milliseconds: 50));
            }
            expect(unreadActivityCount.value, greaterThan(0));

            // 2. Abrir Actividad limpia el badge y llama a mark_activity_read.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.text('Nueva actividad reciente'),
            );
            await harness.settleFrames(tester, count: 6);

            expect(unreadActivityCount.value, 0);
            expect(
              backend.requestedPaths
                  .contains('POST /rest/v1/rpc/mark_activity_read'),
              isTrue,
            );

            // 3. Dar Like y quitar Like (unlike) en la primera publicación.
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUpAltOutlined),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUp),
            );
            expect(backend.tableRows('review_likes'), hasLength(1));

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUp),
            );
            await harness.pumpUntilGone(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUp),
            );
            expect(backend.tableRows('review_likes'), isEmpty);

            // 4. Entrar al hilo de ReviewDetailsScreen, publicar comentario raíz y eliminarlo.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline),
            );

            final threadInput = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Escribe un comentario...',
            );
            await harness.pumpUntilFound(tester, threadInput);
            await harness.settleFrames(tester, count: 6);

            const myComment = 'Comentario raíz propio';
            await tester.enterText(threadInput, myComment);
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(tester, find.text(myComment));
            expect(backend.tableRows('review_comments'), hasLength(1));

            await harness.tapWhenReady(tester, find.byTooltip('Eliminar'));
            await harness.pumpUntilFound(tester, find.byType(AlertDialog));

            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Eliminar'),
              ),
            );
            await harness.pumpUntilGone(tester, find.text(myComment));
            await harness.settleFrames(tester, count: 6);

            expect(backend.tableRows('review_comments'), isEmpty);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Visor de historias de amigo avanza, retrocede y persiste lecturas en story_views',
      (tester) async {
        final seededBackend = FakeSupabaseBackend(seedSocialData: true)
          ..seedRecentFriendActivity(
            userId: FakeSupabaseBackend.friendUserId,
            gameId: FakeSupabaseBackend.eldenRingId,
            comment: 'Historia uno',
            age: const Duration(minutes: 40),
          )
          ..seedRecentFriendActivity(
            userId: FakeSupabaseBackend.friendUserId,
            gameId: FakeSupabaseBackend.hollowKnightId,
            comment: 'Historia dos',
            age: const Duration(minutes: 20),
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.byType(ActivityStoryRing),
            );
            await harness.settleFrames(tester, count: 6);

            // 1. Abrir visor tocando el aro del amigo en la franja superior.
            await harness.tapWhenReady(
              tester,
              find.byType(ActivityStoryRing).first,
              scrollIntoView: false,
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ActivityStoryViewer),
            );
            await harness.settleFrames(tester, count: 8);
            expect(backend.tableRows('story_views'), hasLength(1));

            // 2. Avanzar al segundo slide tocando la zona derecha.
            final box = tester.getRect(find.byType(ActivityStoryViewer));
            await tester.tapAt(
              Offset(box.left + box.width * 0.85, box.top + box.height * 0.5),
            );
            await harness.settleFrames(tester, count: 8);
            expect(backend.tableRows('story_views'), hasLength(2));

            // 3. Retroceder al slide anterior tocando la zona izquierda.
            await tester.tapAt(
              Offset(box.left + box.width * 0.15, box.top + box.height * 0.5),
            );
            await harness.settleFrames(tester, count: 6);
            expect(find.byType(ActivityStoryViewer), findsOneWidget);

            // 4. Cerrar visor antes del tearDown.
            Navigator.of(
              tester.element(find.byType(ActivityStoryViewer)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ActivityStoryViewer),
            );
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Publicación agrupada (GroupedPostDetailsScreen) y Feed de Notificaciones (NotificationsFeedScreen)',
      (tester) async {
        final seededBackend = FakeSupabaseBackend(seedSocialData: true);
        seededBackend.seedBeatenGame(
          userId: FakeSupabaseBackend.primaryUserId,
          gameId: FakeSupabaseBackend.eldenRingId,
          comment: 'Reseña propia notificada',
        );
        final myReviewId = seededBackend.tableRows('reviews').last['id'] as String;

        final groupedPostId = seededBackend.seedGroupedFriendActivity(
          userId: FakeSupabaseBackend.friendUserId,
          gameIds: const <int>[
            FakeSupabaseBackend.eldenRingId,
            FakeSupabaseBackend.hollowKnightId,
          ],
          status: 'wishlist',
          age: const Duration(minutes: 15),
        );

        seededBackend.seedNotification(
          recipientId: FakeSupabaseBackend.primaryUserId,
          actorId: FakeSupabaseBackend.friendUserId,
          type: 'like',
          reviewId: myReviewId,
          metadata: const <String, dynamic>{'game_title': 'Elden Ring'},
        );
        seededBackend.seedNotification(
          recipientId: FakeSupabaseBackend.primaryUserId,
          actorId: FakeSupabaseBackend.pendingRequesterId,
          type: 'friend_request',
        );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline),
            );
            await harness.settleFrames(tester, count: 6);

            expect(unreadNotificationsCount.value, 2);

            // 1. Abrir la publicación agrupada (es el card más reciente en el feed).
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GroupedPostDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            expect(find.text('Elden Ring'), findsWidgets);
            expect(find.text('Hollow Knight'), findsWidgets);

            // Like y comentario dentro del post agrupado.
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
            expect(
              backend
                  .tableRows('review_likes')
                  .any((l) => l['post_id'] == groupedPostId),
              isTrue,
            );

            final commentInput = find.descendant(
              of: find.byType(GroupedPostDetailsScreen),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                    w.decoration?.hintText == 'Escribe un comentario...',
              ),
            );
            await tester.enterText(commentInput, '¡Buena lista de deseos!');
            await tester.pump();
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(GroupedPostDetailsScreen),
                matching: find.byTooltip('Enviar'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¡Buena lista de deseos!'),
            );
            expect(
              backend
                  .tableRows('review_comments')
                  .any((c) => c['post_id'] == groupedPostId),
              isTrue,
            );

            // Abrir juego desde la cuadrícula de GroupedPostDetailsScreen.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(GroupedPostDetailsScreen),
                matching: find.text('Elden Ring'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(GameDetailsScreen),
            );

            Navigator.of(tester.element(find.byType(GameDetailsScreen))).pop();
            await harness.pumpUntilGone(tester, find.byType(GameDetailsScreen));
            Navigator.of(
              tester.element(find.byType(GroupedPostDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(GroupedPostDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // 2. Abrir Feed de Notificaciones, comprobar lectura global y navegación al destino.
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
              find.text('Nuevo Jugador te envió una solicitud de amistad'),
              findsOneWidget,
            );

            await harness.settleFrames(tester, count: 6);
            expect(unreadNotificationsCount.value, 0);
            expect(
              backend
                  .tableRows('notifications')
                  .where(
                    (n) => n['recipient_id'] == FakeSupabaseBackend.primaryUserId,
                  )
                  .every((n) => n['read_at'] != null),
              isTrue,
            );

            // Navegar a la reseña notificada.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Amigo Gamer le dio like a tu reseña de Elden Ring'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            expect(find.text('Elden Ring'), findsWidgets);

            Navigator.of(
              tester.element(find.byType(ReviewDetailsScreen)),
            ).pop();
            await harness.pumpUntilGone(
              tester,
              find.byType(ReviewDetailsScreen),
            );
            await harness.settleFrames(tester, count: 6);

            // Navegar a FriendsScreen desde notificación de solicitud de amistad.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.text('Nuevo Jugador te envió una solicitud de amistad'),
            );
            await harness.pumpUntilFound(tester, find.byType(FriendsScreen));
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );
  });
}
