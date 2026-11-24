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

  group('Flujos sociales, colecciones, perfil y ajustes', () {
    testWidgets(
      'Actividad de amigo (like + comentario), aceptar solicitud y buscar nuevo amigo',
      (tester) async {
        final seeded = FakeSupabaseBackend(seedSocialData: true);
        await harness.run(
          tester,
          (backend) async {
            // 1. Ver reseña del amigo en Actividad y darle Like.
            await harness.tapTab(tester, 'Actividad');
            await harness.pumpUntilFound(
              tester,
              find.textContaining(
                'Una aventura inolvidable en los Reinos del Norte.',
              ),
            );

            await harness.tapWhenReady(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUpAltOutlined),
            );
            await harness.pumpUntilFound(
              tester,
              harness.findCorpusIcon(CorpusIconKind.ThumbUp),
            );
            expect(backend.tableRows('review_likes'), hasLength(1));

            // 2. Abrir hilo de comentarios y publicar un comentario.
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
            await harness.settleFrames(tester, count: 8);

            const friendComment = 'Gran análisis, me lo apunto.';
            await tester.enterText(threadInput, friendComment);
            await tester.pump();
            await harness.tapWhenReady(tester, find.byTooltip('Enviar'));
            await harness.pumpUntilFound(tester, find.text(friendComment));
            expect(backend.tableRows('review_comments'), hasLength(1));

            // Volver a MainScreen.
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 10);

            // 3. Ir a Perfil y abrir FriendsScreen.
            await harness.tapTab(tester, 'Perfil');
            await harness.settleFrames(tester, count: 8);

            final friendsTooltip = find.byTooltip('Amigos');
            await harness.waitForPushDebounce(tester);
            if (friendsTooltip.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, friendsTooltip);
            } else {
              await harness.tapWhenReady(tester, find.textContaining('amigo'));
            }

            await harness.pumpUntilFound(tester, find.text('Solicitudes'));
            await harness.settleFrames(tester, count: 8);

            // 4. Aceptar solicitud pendiente de `nuevojugador`.
            await harness.tapWhenReady(tester, find.text('Solicitudes'));
            await harness.pumpUntilFound(
              tester,
              find.textContaining('nuevojugador'),
            );
            await harness.tapWhenReady(tester, find.byTooltip('Aceptar'));
            await harness.settleFrames(tester, count: 8);

            final acceptedPending = backend
                .tableRows('friendships')
                .where(
                  (f) =>
                      f['requester_id'] ==
                          FakeSupabaseBackend.pendingRequesterId &&
                      f['status'] == 'accepted',
                )
                .toList();
            expect(acceptedPending, hasLength(1));

            // 5. Buscar usuario `explorador` y enviar solicitud.
            await harness.tapWhenReady(tester, find.text('Buscar'));

            final userSearchField = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Buscar por nombre de usuario…',
            );
            await harness.pumpUntilFound(tester, userSearchField);
            await tester.enterText(userSearchField, 'explorador');
            await tester.pump(const Duration(milliseconds: 650));
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(tester, find.text('Añadir'));
            await harness.pumpUntilFound(tester, find.text('Enviado'));

            final sentRequest = backend
                .tableRows('friendships')
                .where(
                  (f) =>
                      f['requester_id'] == FakeSupabaseBackend.primaryUserId &&
                      f['addressee_id'] ==
                          FakeSupabaseBackend.searchableUserId &&
                      f['status'] == 'pending',
                )
                .toList();
            expect(sentRequest, hasLength(1));
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Crear colección en Mis juegos -> Colecciones y añadir juego completado',
      (tester) async {
        final seeded = FakeSupabaseBackend()..seedBeatenGame();
        await harness.run(
          tester,
          (backend) async {
            // 1. Abrir Mis juegos -> pestaña Colecciones.
            await harness.tapTab(tester, 'Mis juegos');
            await harness.tapWhenReady(tester, find.text('Colecciones'));
            await harness.settleFrames(tester, count: 8);

            // 2. Crear nueva colección `Favoritos RPG`.
            final newColBtn = find.text('Nueva colección');
            if (newColBtn.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, newColBtn);
            } else {
              await harness.tapWhenReady(tester, find.text('Nueva'));
            }
            await harness.pumpUntilFound(tester, find.byType(AlertDialog));

            final nameField = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            );
            await tester.enterText(nameField.first, 'Favoritos RPG');
            await tester.pump();
            await harness.tapWhenReady(
              tester,
              find.text('Crear'),
              useLast: true,
            );
            await harness.pumpUntilFound(tester, find.text('Favoritos RPG'));
            await harness.settleFrames(tester, count: 8);

            expect(backend.tableRows('game_groups'), hasLength(1));

            // 3. Entrar en la colección y añadir Elden Ring desde GameSearchPickerSheet.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Favoritos RPG'));
            await harness.settleFrames(tester, count: 8);

            final addGameTooltip = find.byTooltip('Añadir juego');
            if (addGameTooltip.hitTestable().evaluate().isNotEmpty) {
              await harness.tapWhenReady(tester, addGameTooltip);
            } else {
              await harness.tapWhenReady(tester, find.text('Añadir juego'));
            }

            await harness.tapWhenReady(
              tester,
              find.text('Elden Ring'),
              useLast: true,
            );
            await harness.settleFrames(tester, count: 8);

            expect(find.text('Elden Ring'), findsWidgets);
            expect(backend.tableRows('game_group_items'), hasLength(1));
          },
          customBackend: seeded,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Editar perfil en Cuenta y alternar preferencia en Ajustes',
      (tester) async {
        await harness.run(tester, (backend) async {
          await harness.tapTab(tester, 'Perfil');
          await harness.settleFrames(tester, count: 8);

          // 1. Abrir Ajustes -> Cuenta (EditProfileScreen).
          final settingsBtn = harness.findCorpusIcon(CorpusIconKind.Settings);
          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(tester, settingsBtn);
          await harness.pumpUntilFound(tester, find.text('Cuenta'));

          await harness.waitForPushDebounce(tester);
          await harness.tapWhenReady(tester, find.text('Cuenta'));
          await harness.pumpUntilFound(tester, find.text('Guardar Cambios'));
          await harness.settleFrames(tester, count: 8);

          // 2. Modificar nombre visible y biografía.
          final displayNameField = find.widgetWithText(
            TextField,
            FakeSupabaseBackend.primaryDisplayName,
          );
          final bioField = find.widgetWithText(
            TextField,
            'Jugador de Corpus en pruebas.',
          );
          await tester.enterText(displayNameField.first, 'Player One Editado');
          await tester.enterText(bioField.first, 'Bio actualizada en test.');
          await tester.pump();

          await harness.tapWhenReady(
            tester,
            find.text('Guardar Cambios'),
            useLast: true,
          );
          await harness.pumpUntilFound(
            tester,
            find.text('Perfil guardado correctamente'),
          );
          await harness.settleFrames(tester, count: 6);

          final updatedUser = backend
              .tableRows('users')
              .firstWhere((u) => u['id'] == FakeSupabaseBackend.primaryUserId);
          expect(updatedUser['display_name'], 'Player One Editado');
          expect(updatedUser['bio'], 'Bio actualizada en test.');

          // 3. Volver a Ajustes y alternar preferencia 'Traducir enlaces de tiendas'.
          if (find.text('Ajustes').hitTestable().evaluate().isEmpty) {
            tester.state<NavigatorState>(find.byType(Navigator).last).pop();
            await harness.settleFrames(tester, count: 8);
          }

          await harness.tapWhenReady(
            tester,
            find.text('Traducir enlaces de tiendas'),
          );
          await harness.settleFrames(tester, count: 6);

          expect(tester.takeException(), isNull);
        }, loggedIn: true);
      },
    );
  });
}
