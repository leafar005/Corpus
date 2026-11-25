import 'dart:convert';
import 'dart:typed_data';

import 'package:corpus/screens/settings/import_preview_screen.dart';
import 'package:corpus/screens/settings/integrations_screen.dart';
import 'package:corpus/screens/settings_screen.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_supabase_backend.dart';
import 'helpers/integration_test_harness.dart';

void main() {
  late CorpusTestHarness harness;

  setUp(() {
    harness = CorpusTestHarness();
  });

  Future<void> openIntegrations(WidgetTester tester) async {
    await harness.tapTab(tester, 'Perfil');
    await harness.settleFrames(tester, count: 8);
    await harness.waitForPushDebounce(tester);
    await harness.tapWhenReady(
      tester,
      harness.findCorpusIcon(CorpusIconKind.Settings),
    );
    await harness.pumpUntilFound(tester, find.byType(SettingsScreen));
    await harness.waitForPushDebounce(tester);
    await harness.tapWhenReady(tester, find.text('Integraciones'));
    await harness.pumpUntilFound(tester, find.byType(IntegrationsScreen));
    await harness.settleFrames(tester, count: 6);
  }

  group('Importación Stash CSV/JSON y Resolución en ImportPreviewScreen', () {
    testWidgets(
      'IntegrationsScreen rechaza archivos vacíos, mayores de 25 MB y cancelación de FilePicker',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openIntegrations(tester);

            // 1. Cancelación del selector -> sin error ni navegación.
            harness.enqueueCancelledFilePick();
            await harness.tapWhenReady(
              tester,
              find.text('Importar desde Stash'),
            );
            expect(harness.filePickerCallCount, 1);
            expect(find.byType(ImportPreviewScreen), findsNothing);

            // 2. Archivo vacío.
            harness.enqueuePickedFile(
              name: 'empty.csv',
              bytes: Uint8List(0),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Importar desde Stash'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('El archivo seleccionado está vacío.'),
            );
            await tester.pump(const Duration(seconds: 4));

            // 3. Archivo > 25 MB.
            harness.enqueuePickedFile(
              name: 'huge.csv',
              bytes: Uint8List(25 * 1024 * 1024 + 1024),
            );
            await harness.tapWhenReady(
              tester,
              find.text('Importar desde Stash'),
            );
            await harness.pumpUntilFound(
              tester,
              find.textContaining('El máximo permitido es 25 MB.'),
            );
            expect(find.byType(ImportPreviewScreen), findsNothing);
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'CSV E2E: Listos, resolución en Dudas, No encontrados, filtro, edición en ReviewModal y guardado',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openIntegrations(tester);

            const csvData =
                'title,status,rating,comment,platform\n'
                'Elden Ring,beaten,9.5,Obra maestra,PC\n'
                'Hollow,playing,,En progreso,PC\n'
                'Juego Inexistente XYZ 9999,wishlist,,Deseado,PC\n';

            harness.enqueuePickedFile(
              name: 'stash_library.csv',
              bytes: Uint8List.fromList(utf8.encode(csvData)),
            );

            await harness.tapWhenReady(
              tester,
              find.text('Importar desde Stash'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ImportPreviewScreen),
              timeout: const Duration(seconds: 8),
            );
            await harness.settleFrames(tester, count: 6);

            // 1. Verificar pestañas iniciales: 1 listo (Elden Ring), 1 duda (Hollow), 1 no encontrado.
            expect(find.text('Listos (1)'), findsOneWidget);
            expect(find.text('Dudas (1)'), findsOneWidget);
            expect(find.text('No encontrados (1)'), findsOneWidget);

            // 2. Verificar pestaña "No encontrados".
            await harness.tapWhenReady(tester, find.text('No encontrados (1)'));
            await harness.pumpUntilFound(
              tester,
              find.text('Juego Inexistente XYZ 9999'),
            );

            // 3. Resolver ambigüedad en "Dudas" eligiendo "Hollow Knight (2017)".
            await harness.tapWhenReady(tester, find.text('Dudas (1)'));
            await harness.pumpUntilFound(tester, find.text('CSV: "Hollow"'));
            await harness.tapWhenReady(
              tester,
              find.textContaining('Hollow Knight (2017)'),
            );
            await harness.pumpUntilFound(tester, find.text('Listos (2)'));
            expect(find.text('Dudas (0)'), findsOneWidget);

            // 4. Volver a Listos, filtrar por estado y editar la fila resuelta en ReviewModal.
            await harness.tapWhenReady(tester, find.text('Listos (2)'));
            await harness.pumpUntilFound(tester, find.text('Elden Ring'));
            expect(find.text('Hollow Knight'), findsOneWidget);

            await harness.tapWhenReady(tester, find.text('Todos'));
            await harness.tapWhenReady(
              tester,
              find.text('Completado'),
              useLast: true,
            );
            await harness.settleFrames(tester, count: 4);
            expect(find.text('Elden Ring'), findsOneWidget);
            expect(find.text('Hollow Knight'), findsNothing);

            await harness.tapWhenReady(tester, find.text('Completado'));
            await harness.tapWhenReady(
              tester,
              find.text('Todos'),
              useLast: true,
            );
            await harness.settleFrames(tester, count: 4);

            // Pulsar sobre Hollow Knight para editarlo con ReviewModal (_editRow).
            await harness.tapWhenReady(tester, find.text('Hollow Knight'));
            await harness.pumpUntilFound(tester, find.text('Añadir Reseña'));
            await harness.tapWhenReady(
              tester,
              find.byTooltip('Cambiar estado'),
            );
            await harness.tapWhenReady(tester, find.text('Terminado'));
            await harness.tapWhenReady(
              tester,
              find.text('Guardar Reseña'),
              useLast: true,
            );
            await harness.pumpUntilGone(tester, find.text('Añadir Reseña'));

            // 5. Guardar los 2 juegos en Supabase.
            await harness.tapWhenReady(
              tester,
              find.text('Importar 2 juegos a mi biblioteca'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¡Importación completada con éxito! (2 juegos)'),
            );
            await harness.pumpUntilGone(
              tester,
              find.byType(ImportPreviewScreen),
            );

            final savedIds = backend
                .tableRows('user_games')
                .where((ug) => ug['user_id'] == FakeSupabaseBackend.primaryUserId)
                .map((ug) => ug['game_id'])
                .toSet();
            expect(
              savedIds,
              containsAll(<int>[
                FakeSupabaseBackend.eldenRingId,
                FakeSupabaseBackend.hollowKnightId,
              ]),
            );
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );

    testWidgets(
      'JSON nativo de Stash importa juegos y reseñas vía IntegrationsScreen -> ImportPreviewScreen',
      (tester) async {
        await harness.run(
          tester,
          (backend) async {
            await openIntegrations(tester);

            final stashJson = jsonEncode(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'game': <String, dynamic>{
                    'id': FakeSupabaseBackend.witcher3Id,
                    'name': 'The Witcher 3: Wild Hunt',
                    'firstReleaseDate': 1431993600,
                  },
                  'review': <String, dynamic>{
                    'status': 'BEATEN',
                    'ratingFloat': 9.2,
                    'comment': 'Importado desde JSON de Stash.',
                    'modificationDate': 1700000000,
                    'markers': <String>['completionists'],
                    'detailInfo': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'type': 'playingTime',
                        'seconds': 306000,
                      },
                    ],
                  },
                },
              ],
            });

            harness.enqueuePickedFile(
              name: 'stash_export.json',
              bytes: Uint8List.fromList(utf8.encode(stashJson)),
            );

            await harness.tapWhenReady(
              tester,
              find.text('Importar desde Stash'),
            );
            await harness.pumpUntilFound(
              tester,
              find.byType(ImportPreviewScreen),
              timeout: const Duration(seconds: 8),
            );
            await harness.settleFrames(tester, count: 6);

            expect(find.text('The Witcher 3: Wild Hunt'), findsOneWidget);
            await harness.tapWhenReady(
              tester,
              find.text('Importar 1 juegos a mi biblioteca'),
            );
            await harness.pumpUntilFound(
              tester,
              find.text('¡Importación completada con éxito! (1 juegos)'),
            );

            final witcherReview = backend
                .tableRows('reviews')
                .firstWhere(
                  (r) =>
                      r['user_id'] == FakeSupabaseBackend.primaryUserId &&
                      r['game_id'] == FakeSupabaseBackend.witcher3Id,
                );
            expect(witcherReview['status'], 'beaten');
            expect(witcherReview['completion_type'], '100_percent');
            expect(
              witcherReview['comment'],
              'Importado desde JSON de Stash.',
            );
            expect(tester.takeException(), isNull);
          },
          loggedIn: true,
        );
      },
    );
  });
}
