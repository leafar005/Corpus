import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/repositories/review_repository.dart';

void main() {
  group('ReviewRepository.sanitizeReviewData (Lógica de Limpieza en Wishlist)', () {
    test(
      'Fuerza a null las notas de gameplay, narrativa, tiempo, etc. cuando status es "wishlist"',
      () {
        final sanitized = ReviewRepository.sanitizeReviewData(
          userId: 'user-123',
          igdbId: 100,
          status: 'wishlist',
          rating: 9.5,
          ratingGameplay: 9.0,
          ratingNarrative: 10.0,
          ratingSoundtrack: 8.5,
          ratingVisuals: 9.0,
          comment: 'Comentario que no debería guardarse',
          completionType: '100%',
          isReplay: true,
          replayNumber: 2,
          platform: 'PC',
          playTimeHours: 50.0,
          playedFrom: DateTime(2025, 1, 1),
          playedUntil: DateTime(2025, 1, 10),
          progressPercent: 100,
          imageUrls: ['https://ejemplo.com/foto1.jpg'],
          partnerIds: const [],
        );

        expect(sanitized['status'], 'wishlist');
        expect(sanitized['rating'], isNull);
        expect(sanitized['rating_gameplay'], isNull);
        expect(sanitized['rating_narrative'], isNull);
        expect(sanitized['rating_soundtrack'], isNull);
        expect(sanitized['rating_visuals'], isNull);
        expect(sanitized['comment'], isNull);
        expect(sanitized['completion_type'], 'none');
        expect(sanitized['is_replay'], isFalse);
        expect(sanitized['replay_number'], isNull);
        expect(sanitized['platform'], isNull);
        expect(sanitized['play_time_hours'], isNull);
        expect(sanitized['played_from'], isNull);
        expect(sanitized['played_until'], isNull);
        expect(sanitized['progress_percent'], isNull);
        expect(sanitized['image_urls'], isEmpty);
      },
    );

    test(
      'Conserva las notas, comentario e imágenes cuando status es "beaten" o "playing"',
      () {
        final sanitized = ReviewRepository.sanitizeReviewData(
          userId: 'user-123',
          igdbId: 100,
          status: 'beaten',
          rating: 9.5,
          ratingGameplay: 9.0,
          ratingNarrative: 10.0,
          ratingSoundtrack: 8.5,
          ratingVisuals: 9.0,
          comment: 'Juegazo increíble',
          completionType: 'story',
          isReplay: false,
          replayNumber: null,
          platform: 'PlayStation 5',
          playTimeHours: 40.0,
          playedFrom: DateTime(2025, 1, 1),
          playedUntil: DateTime(2025, 1, 10),
          progressPercent: 100,
          imageUrls: ['https://ejemplo.com/foto1.jpg'],
          partnerIds: const [],
        );

        expect(sanitized['status'], 'beaten');
        expect(sanitized['rating'], 9.5);
        expect(sanitized['rating_gameplay'], 9.0);
        expect(sanitized['rating_narrative'], 10.0);
        expect(sanitized['comment'], 'Juegazo increíble');
        expect(sanitized['platform'], 'PlayStation 5');
        expect(sanitized['play_time_hours'], 40.0);
        expect(sanitized['image_urls'], ['https://ejemplo.com/foto1.jpg']);
      },
    );
  });

  group(
    'ReviewRepository.computeUnlockedAchievements (Lógica de Logros Desbloqueados)',
    () {
      test(
        'Detecta exactamente el ID del logro recién desbloqueado (1 antes -> 2 después)',
        () {
          final before = {'logro-bienvenida'};
          final after = {'logro-bienvenida', 'logro-primer-juego'};

          final unlocked = ReviewRepository.computeUnlockedAchievements(
            before,
            after,
          );

          expect(unlocked.length, 1);
          expect(unlocked.first, 'logro-primer-juego');
        },
      );

      test('Devuelve conjunto vacío si no se desbloquearon nuevos logros', () {
        final before = {'logro-1', 'logro-2'};
        final after = {'logro-1', 'logro-2'};

        final unlocked = ReviewRepository.computeUnlockedAchievements(
          before,
          after,
        );

        expect(unlocked, isEmpty);
      });

      test(
        'Maneja correctamente cuando el usuario parte de 0 logros antes de guardar',
        () {
          final before = <String>{};
          final after = {'logro-1'};

          final unlocked = ReviewRepository.computeUnlockedAchievements(
            before,
            after,
          );

          expect(unlocked, {'logro-1'});
        },
      );
    },
  );

  group('SaveReviewResult Model Test', () {
    test('Almacena correctamente los IDs de logros y sus detalles', () {
      const result = SaveReviewResult(
        newlyUnlockedAchievementIds: {'logro-100'},
        newAchievementDetails: [
          {'id': 'logro-100', 'title': 'Coleccionista I', 'xp': 100},
        ],
      );

      expect(result.newlyUnlockedAchievementIds, contains('logro-100'));
      expect(result.newAchievementDetails.length, 1);
      expect(result.newAchievementDetails.first['title'], 'Coleccionista I');
    });
  });
}
