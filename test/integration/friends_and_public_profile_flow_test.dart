import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/screens/profile/collection_shelf_screen.dart';
import 'package:corpus/screens/profile/profile_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/screens/social/user_friends_screen.dart';
import 'package:corpus/services/deep_link_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/friendship_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Amigos, Perfiles Públicos y Protección Privada', () {
    testWidgets(
      'Rechazar solicitud recibida, cancelar solicitud enviada y eliminar amigo existente en FriendsScreen',
      (tester) async {
        final seededBackend = FakeSupabaseBackend(seedSocialData: true)
          ..seedFriendship(
            requesterId: FakeSupabaseBackend.primaryUserId,
            addresseeId: FakeSupabaseBackend.searchableUserId,
            status: 'pending',
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(
              tester,
              find.byTooltip('Amigos'),
            );

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.byTooltip('Amigos'));
            await harness.pumpUntilFound(tester, find.byType(FriendsScreen));

            // 1. Pestaña Solicitudes: rechazar entrante y cancelar enviada.
            await harness.tapWhenReady(tester, find.text('Solicitudes'));
            await harness.pumpUntilFound(tester, find.text('Nuevo Jugador'));
            expect(find.text('Explorador Pro'), findsOneWidget);

            await harness.tapWhenReady(tester, find.byTooltip('Rechazar'));
            await harness.pumpUntilGone(tester, find.text('Nuevo Jugador'));
            expect(
              backend.tableRows('friendships').any(
                    (f) =>
                        f['requester_id'] ==
                        FakeSupabaseBackend.pendingRequesterId,
                  ),
              isFalse,
            );

            await harness.tapWhenReady(tester, find.text('Cancelar'));
            await harness.pumpUntilGone(tester, find.text('Explorador Pro'));
            expect(
              backend.tableRows('friendships').any(
                    (f) =>
                        f['addressee_id'] ==
                        FakeSupabaseBackend.searchableUserId,
                  ),
              isFalse,
            );

            // 2. Pestaña Mis amigos: eliminar amistad aceptada con confirmación.
            await harness.tapWhenReady(tester, find.text('Mis amigos'));
            await harness.pumpUntilFound(tester, find.text('Amigo Gamer'));

            await harness.tapWhenReady(
              tester,
              find.byTooltip('Eliminar amigo'),
            );
            await harness.pumpUntilFound(tester, find.byType(AlertDialog));

            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Eliminar'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Todavía no tienes amigos en Corpus.'),
            );
            expect(backend.tableRows('friendships'), isEmpty);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Perfil público de amigo muestra colecciones y reseñas en solo lectura y abre UserFriendsScreen',
      (tester) async {
        final seededBackend = FakeSupabaseBackend(seedSocialData: true)
          ..seedFriendship(
            requesterId: FakeSupabaseBackend.friendUserId,
            addresseeId: FakeSupabaseBackend.searchableUserId,
            status: 'accepted',
          )
          ..seedCollection(
            userId: FakeSupabaseBackend.friendUserId,
            name: 'Joyas de Amigo',
            gameIds: const <int>[FakeSupabaseBackend.witcher3Id],
          );

        await harness.run(
          tester,
          (backend) async {
            await harness.tapTab(tester, 'Perfil');
            await harness.pumpUntilFound(tester, find.byTooltip('Amigos'));

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.byTooltip('Amigos'));
            await harness.pumpUntilFound(tester, find.byType(FriendsScreen));

            // Navega desde Mis amigos al perfil público de @amigogamer.
            await harness.tapWhenReady(tester, find.text('Mis amigos'));
            await harness.pumpUntilFound(tester, find.text('Amigo Gamer'));

            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(tester, find.text('Amigo Gamer'));
            await harness.pumpUntilFound(
              tester,
              find.text('@amigogamer'),
            );
            await harness.settleFrames(tester, count: 8);

            // En perfil ajeno aparece FriendshipButton pero NO botón de Ajustes ni Edición.
            final friendProfile = find.byType(ProfileScreen).last;
            expect(
              find.descendant(
                of: friendProfile,
                matching: find.byType(FriendshipButton),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: friendProfile,
                matching: harness.findCorpusIcon(CorpusIconKind.Settings),
              ),
              findsNothing,
            );

            // Colecciones de solo lectura.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: friendProfile,
                matching: find.text('Colecciones'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Joyas de Amigo'),
            );
            expect(
              find.descendant(
                of: friendProfile,
                matching: find.text('Nueva colección'),
              ),
              findsNothing,
            );

            // Reseñas del amigo.
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: friendProfile,
                matching: find.text('Reseñas'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('Una aventura inolvidable en los Reinos del Norte.'),
            );

            // Amigos del amigo -> UserFriendsScreen.
            await harness.waitForPushDebounce(tester);
            await harness.tapWhenReady(
              tester,
              find.descendant(
                of: friendProfile,
                matching: find.text('2 amigos'),
              ),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(UserFriendsScreen),
            );
            expect(find.text('Amigos de @amigogamer'), findsOneWidget);
            await harness.pumpUntilFound(tester, find.text('Explorador Pro'));
            expect(find.text('Tú'), findsOneWidget);
          },
          customBackend: seededBackend,
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'Estantería privada (/private/collection) bloquea edición y acciones a invitados',
      (tester) async {
        await harness.run(tester, (backend) async {
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
          expect(
            find.text('Inicia sesión para ver tu estantería'),
            findsOneWidget,
          );
          expect(find.text('Añadir juego'), findsNothing);
        });
      },
    );
  });
}
