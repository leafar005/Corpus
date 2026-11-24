import 'package:flutter_test/flutter_test.dart';

import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  group('Smoke test en viewport móvil', () {
    testWidgets(
      'Navega por las 5 pestañas sin overflows y añade Elden Ring como Wishlist',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            for (final tab in const <String>[
              'Inicio',
              'Explorar',
              'Actividad',
              'Mis juegos',
              'Perfil',
            ]) {
              await harness.tapTab(tester, tab);
              expect(
                tester.takeException(),
                isNull,
                reason: 'Excepción o overflow en pestaña móvil "$tab"',
              );
            }

            await harness.searchAndOpenGame(tester, 'Elden Ring');
            expect(tester.takeException(), isNull);

            await harness.tapWhenReady(
              tester,
              find.text('Añadir a Biblioteca'),
            );
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 6);

            await harness.tapWhenReady(
              tester,
              find.text('Wishlist'),
              useLast: true,
            );
            await harness.tapWhenReady(
              tester,
              find.text('Guardar'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));
            await harness.settleFrames(tester, count: 8);

            expect(tester.takeException(), isNull);
            final rows = backend.tableRows('user_games');
            expect(rows, hasLength(1));
            expect(rows.first['status'], 'wishlist');
          },
          viewportSize: CorpusTestHarness.mobileSize,
          floatingMobileNav: false,
          loggedIn: true,
        );
      },
    );
  });
}
