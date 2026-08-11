import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/screens/library/review_modal.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:cross_file/cross_file.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      publishableKey: 'mock-key',
    );
  });

  group('ReviewModal Widget Tests (Prioridad 4 - Modal de Reseñas)', () {
    testWidgets(
      'Al pulsar el chip "Quiero" (wishlist), los sliders de nota, tiempo jugadas y fechas desaparecen al instante',
      (WidgetTester tester) async {
        final commentController = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [CorpusThemeExtension()]),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      ReviewModal.show(
                        context: context,
                        gameData: {'title': 'The Legend of Zelda'},
                        enrichedData: {},
                        isSaving: false,
                        currentRating: 9.0,
                        currentRatingGameplay: 0,
                        currentRatingNarrative: 0,
                        currentRatingSoundtrack: 0,
                        currentRatingVisuals: 0,
                        currentStatus: 'beaten',
                        commentController: commentController,
                        onSave:
                            ({
                              String? reviewId,
                              required double rating,
                              required double ratingGameplay,
                              required double ratingNarrative,
                              required double ratingSoundtrack,
                              required double ratingVisuals,
                              required String comment,
                              required String status,
                              required String completionType,
                              required bool isReplay,
                              required int? replayNumber,
                              required String? platform,
                              required double? playTimeHours,
                              required DateTime? playedFrom,
                              required DateTime? playedUntil,
                              required int? progressPercent,
                              required List<XFile> newImages,
                              required List<String> existingImages,
                              required List<String> partnerIds,
                              required DateTime? reviewDate,
                            }) async {},
                      );
                    },
                    child: const Text('Abrir Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        // 1. Pulsar para abrir el modal
        await tester.tap(find.text('Abrir Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verificar que aparece el título del modal y los campos de notas/extras porque status='beaten'
        expect(find.text('Añadir Reseña'), findsOneWidget);
        expect(find.text('Nota'), findsOneWidget);
        expect(find.text('Desglosar nota'), findsOneWidget);
        expect(find.text('Información Extra'), findsOneWidget);

        // 2. Pulsar el chip de "Quiero" (wishlist)
        await tester.tap(find.text('Quiero'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 3. Verificar que los sliders de nota y los campos de tiempo/información extra han desaparecido
        expect(find.text('Nota'), findsNothing);
        expect(find.text('Desglosar nota'), findsNothing);
        expect(find.text('Información Extra'), findsNothing);

        // Pero el botón de guardar y los chips de estado siguen presentes y sin lanzar errores
        expect(find.text('Quiero'), findsOneWidget);
        expect(find.text('Guardar'), findsOneWidget);

        // 4. Volver a pulsar "Terminado" y verificar que reaparecen
        await tester.tap(find.text('Terminado'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Nota'), findsOneWidget);
        expect(find.text('Información Extra'), findsOneWidget);
      },
    );
  });
}
