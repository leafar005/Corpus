import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Flujo completo de búsqueda, reseña, actividad y comentarios', () {
    testWidgets(
      'Buscar Elden Ring, publicar reseña, verificar Perfil y Actividad, dar like, comentar, responder y borrar respuesta',
      (tester) async {
        await harness.run(tester, (backend) async {
          // 1. Buscar Elden Ring y abrir detalles.
          await harness.searchAndOpenGame(tester, 'Elden Ring');
          expect(backend.igdbProxyCalls, greaterThan(0));

          // 2. Añadir a biblioteca como Terminado con nota y reseña escrita.
          await harness.tapWhenReady(tester, find.text('Añadir a Biblioteca'));
          await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
          await harness.settleFrames(tester, count: 6);

          await harness.tapWhenReady(
            tester,
            find.text('Terminado'),
            useLast: true,
          );

          final slider = find.byType(Slider);
          if (slider.evaluate().isNotEmpty) {
            await tester.drag(slider.first, const Offset(120, 0));
            await harness.settleFrames(tester, count: 3);
          }

          const reviewText = 'Obra maestra total de exploración y combate.';
          final commentInput = find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == '¿Qué te pareció el juego?',
          );
          await harness.pumpUntilFound(tester, commentInput);
          await tester.enterText(commentInput, reviewText);
          await tester.pump();

          await harness.tapWhenReady(
            tester,
            find.text('Guardar Reseña'),
            useLast: true,
          );
          await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
          await harness.settleFrames(tester, count: 10);

          expect(backend.tableRows('reviews'), hasLength(1));
          expect(backend.tableRows('reviews').first['comment'], reviewText);
          expect(backend.tableRows('user_games').first['status'], 'beaten');

          // 3. Volver a MainScreen y comprobar Perfil.
          tester.state<NavigatorState>(find.byType(Navigator).last).pop();
          await harness.settleFrames(tester, count: 10);

          await harness.tapTab(tester, 'Perfil');
          await harness.settleFrames(tester, count: 8);
          expect(find.textContaining('playerone'), findsWidgets);

          // 4. Comprobar feed en Actividad y dar Like.
          await harness.tapTab(tester, 'Actividad');
          await harness.pumpUntilFound(
            tester,
            harness.findCorpusIcon(CorpusIconKind.ThumbUpAltOutlined),
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
          expect(backend.tableRows('review_likes'), hasLength(1));

          // 5. Abrir hilo de ReviewDetailsScreen desde el botón de comentarios.
          final chatBtn =
              harness.findCorpusIcon(CorpusIconKind.ChatBubbleOutline);
          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(tester, chatBtn);

          final threadInput = find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Escribe un comentario...',
          );
          await harness.pumpUntilFound(tester, threadInput);
          await harness.settleFrames(tester, count: 8);

          // 6. Escribir primer comentario.
          const comment1 = 'Totalmente de acuerdo, juegazo';
          await tester.enterText(threadInput, comment1);
          await tester.pump();
          await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
          await harness.pumpUntilFound(tester, find.text(comment1));
          await harness.settleFrames(tester, count: 6);

          expect(backend.tableRows('review_comments'), hasLength(1));

          // 7. Responder al comentario.
          await harness.tapWhenReady(tester, find.byTooltip('Responder'));
          await harness.pumpUntilFound(
            tester,
            find.textContaining('Respondiendo a @playerone'),
          );

          const reply1 = '¡Sobre todo el diseño de niveles!';
          await tester.enterText(threadInput, reply1);
          await tester.pump();
          await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
          await harness.pumpUntilFound(tester, find.text(reply1));
          await harness.settleFrames(tester, count: 6);

          expect(backend.tableRows('review_comments'), hasLength(2));

          // 8. Borrar la respuesta añadida.
          await harness.tapWhenReady(
            tester,
            find.byTooltip('Eliminar'),
            useLast: true,
          );
          await harness.pumpUntilFound(tester, find.byType(AlertDialog));

          final confirmDelete = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Eliminar'),
          );
          await harness.tapWhenReady(tester, confirmDelete, useLast: true);
          await harness.pumpUntilGone(tester, find.text(reply1));
          await harness.settleFrames(tester, count: 6);

          expect(backend.tableRows('review_comments'), hasLength(1));
          expect(find.text(comment1), findsOneWidget);
        }, loggedIn: true);
      },
    );

    testWidgets(
      'Añadir Hollow Knight como Jugando, verificar en Mis juegos, editar a Terminado y borrar de biblioteca',
      (tester) async {
        await harness.run(tester, (backend) async {
          // 1. Buscar Hollow Knight y guardarlo como Jugando.
          await harness.searchAndOpenGame(tester, 'Hollow Knight');
          await harness.tapWhenReady(tester, find.text('Añadir a Biblioteca'));
          await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
          await harness.settleFrames(tester, count: 6);

          await harness.tapWhenReady(
            tester,
            find.text('Jugando'),
            useLast: true,
          );
          await harness.tapWhenReady(
            tester,
            find.text('Guardar'),
            useLast: true,
          );
          await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
          await harness.settleFrames(tester, count: 8);

          expect(backend.tableRows('user_games').first['status'], 'playing');

          // 2. Volver a MainScreen -> Mis juegos -> verificar Hollow Knight en Jugando.
          tester.state<NavigatorState>(find.byType(Navigator).last).pop();
          await harness.settleFrames(tester, count: 10);

          await harness.tapTab(tester, 'Mis juegos');
          await harness.pumpUntilFound(
            tester,
            harness.findGameCardByTitle('Hollow Knight'),
          );
          expect(find.text('Jugando'), findsWidgets);

          // 3. Reabrir Hollow Knight desde Mis juegos y editar estado a Terminado.
          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(
            tester,
            harness.findGameCardByTitle('Hollow Knight'),
          );
          await harness.pumpUntilFound(tester, find.text('Hollow Knight'));
          await harness.settleFrames(tester, count: 10);

          await harness.tapWhenReady(tester, find.text('Jugando'));

          final changeStatusBtn = find.byTooltip('Cambiar estado');
          if (changeStatusBtn.evaluate().isNotEmpty) {
            await harness.tapWhenReady(tester, changeStatusBtn);
          }

          await harness.tapWhenReady(
            tester,
            find.text('Terminado'),
            useLast: true,
          );

          const editedComment = 'Hallownest es mágico.';
          final commentInput = find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == '¿Qué te pareció el juego?',
          );
          await harness.pumpUntilFound(tester, commentInput);
          await tester.enterText(commentInput, editedComment);
          await tester.pump();

          await harness.tapWhenReady(
            tester,
            find.text('Guardar Reseña'),
            useLast: true,
          );
          await harness.pumpUntilGone(tester, find.text('Guardar Reseña'));
          await harness.settleFrames(tester, count: 8);

          expect(backend.tableRows('user_games').first['status'], 'beaten');
          expect(find.textContaining(editedComment), findsWidgets);

          // 4. Borrar juego desde menú Opciones -> Borrar juego.
          await harness.tapWhenReady(tester, find.byTooltip('Opciones'));
          await harness.tapWhenReady(
            tester,
            find.text('Borrar juego'),
            useLast: true,
          );
          await harness.pumpUntilFound(tester, find.byType(AlertDialog));

          final confirmBorrar = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Borrar'),
          );
          await harness.tapWhenReady(tester, confirmBorrar, useLast: true);
          await harness.pumpUntilFound(
            tester,
            find.text('Añadir a Biblioteca'),
          );
          await harness.settleFrames(tester, count: 6);

          expect(backend.tableRows('user_games'), isEmpty);
          expect(backend.tableRows('reviews'), isEmpty);
        }, loggedIn: true);
      },
    );
  });
}
