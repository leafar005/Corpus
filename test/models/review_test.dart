// test/models/review_test.dart
//
// Tests unitarios para Review.fromMap / toMap / copyWith y Review.effectiveRating.
// No requieren Flutter ni Supabase — solo Dart puro.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/review.dart';
import 'package:corpus/models/game_status.dart';
import 'package:corpus/models/user_profile.dart';

void main() {
  // Mapa mínimo válido para construir un Review
  Map<String, dynamic> minimalMap({
    String id = 'review-uuid-1',
    String userId = 'user-uuid-1',
    int gameId = 1942,
    String status = 'beaten',
  }) => {
    'id': id,
    'user_id': userId,
    'game_id': gameId,
    'status': status,
  };

  group('Review.fromMap', () {
    group('Campos obligatorios', () {
      test('parsea id, userId, gameId y status mínimos', () {
        final review = Review.fromMap(minimalMap());

        expect(review.id, 'review-uuid-1');
        expect(review.userId, 'user-uuid-1');
        expect(review.gameId, 1942);
        expect(review.status, GameStatus.beaten);
      });

      test('convierte status string a GameStatus correctamente', () {
        final statuses = {
          'playing': GameStatus.playing,
          'beaten': GameStatus.beaten,
          'wishlist': GameStatus.wishlist,
          'abandoned': GameStatus.abandoned,
          'on_hold': GameStatus.onHold,
          'completed': GameStatus.completed,
        };

        for (final entry in statuses.entries) {
          final review = Review.fromMap(minimalMap(status: entry.key));
          expect(review.status, entry.value, reason: 'status: ${entry.key}');
        }
      });

      test('status desconocido cae a wishlist por defecto', () {
        final review = Review.fromMap(minimalMap(status: 'gibberish'));
        expect(review.status, GameStatus.wishlist);
      });
    });

    group('Ratings', () {
      test('parsea todos los ratings como double', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'rating': 8.5,
          'rating_gameplay': 9.0,
          'rating_narrative': 7.5,
          'rating_soundtrack': 10.0,
          'rating_visuals': 8.0,
        });

        expect(review.rating, 8.5);
        expect(review.ratingGameplay, 9.0);
        expect(review.ratingNarrative, 7.5);
        expect(review.ratingSoundtrack, 10.0);
        expect(review.ratingVisuals, 8.0);
      });

      test('ratings aceptan int de JSON y convierten a double', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'rating': 8,
          'rating_gameplay': 9,
        });

        expect(review.rating, 8.0);
        expect(review.rating, isA<double>());
      });

      test('ratings son null si no vienen', () {
        final review = Review.fromMap(minimalMap());
        expect(review.rating, isNull);
        expect(review.ratingGameplay, isNull);
        expect(review.ratingNarrative, isNull);
        expect(review.ratingSoundtrack, isNull);
        expect(review.ratingVisuals, isNull);
      });
    });

    group('Campos de texto', () {
      test('parsea comment, platform y completionType', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'comment': 'Juego increíble',
          'platform': 'PC',
          'completion_type': '100%',
        });

        expect(review.comment, 'Juego increíble');
        expect(review.platform, 'PC');
        expect(review.completionType, '100%');
      });

      test('campos de texto son null si no vienen', () {
        final review = Review.fromMap(minimalMap());
        expect(review.comment, isNull);
        expect(review.platform, isNull);
        expect(review.completionType, isNull);
      });
    });

    group('Fechas y tiempo de juego', () {
      test('parsea played_from y played_until como DateTime', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'played_from': '2024-01-01',
          'played_until': '2024-01-20',
        });

        expect(review.playedFrom, isA<DateTime>());
        expect(review.playedUntil, isA<DateTime>());
        expect(review.playedFrom?.year, 2024);
        expect(review.playedFrom?.month, 1);
        expect(review.playedFrom?.day, 1);
      });

      test('parsea created_at y updated_at', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'created_at': '2024-01-01T12:00:00.000Z',
          'updated_at': '2024-01-15T08:30:00.000Z',
        });

        expect(review.createdAt, isNotNull);
        expect(review.updatedAt, isNotNull);
      });

      test('play_time_hours se parsea como double', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'play_time_hours': 24.5,
        });
        expect(review.playTimeHours, 24.5);
      });

      test('fechas son null si no vienen', () {
        final review = Review.fromMap(minimalMap());
        expect(review.playedFrom, isNull);
        expect(review.playedUntil, isNull);
        expect(review.createdAt, isNull);
        expect(review.updatedAt, isNull);
      });
    });

    group('isReplay y flags', () {
      test('isReplay es false por defecto', () {
        final review = Review.fromMap(minimalMap());
        expect(review.isReplay, isFalse);
      });

      test('isReplay se parsea como true correctamente', () {
        final review = Review.fromMap({...minimalMap(), 'is_replay': true});
        expect(review.isReplay, isTrue);
      });

      test('progressPercent y replayNumber se parsean como int', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'progress_percent': 75,
          'replay_number': 2,
        });

        expect(review.progressPercent, 75);
        expect(review.replayNumber, 2);
      });
    });

    group('image_urls', () {
      test('parsea lista de URLs correctamente', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'image_urls': [
            'https://example.com/img1.jpg',
            'https://example.com/img2.jpg',
          ],
        });

        expect(review.imageUrls.length, 2);
        expect(review.imageUrls.first, 'https://example.com/img1.jpg');
      });

      test('imageUrls es lista vacía si no viene', () {
        final review = Review.fromMap(minimalMap());
        expect(review.imageUrls, isEmpty);
      });

      test('acepta un único string como lista', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'image_urls': 'https://example.com/single.jpg',
        });
        expect(review.imageUrls, ['https://example.com/single.jpg']);
      });
    });

    group('partners y user join', () {
      test('parsea partnerIds como lista de strings', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'partner_ids': ['uid-2', 'uid-3'],
        });

        expect(review.partnerIds, ['uid-2', 'uid-3']);
      });

      test('parsea partners como lista de UserProfile', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'partners': [
            {'id': 'uid-2', 'username': 'alice'},
            {'id': 'uid-3', 'username': 'bob'},
          ],
        });

        expect(review.partners.length, 2);
        expect(review.partners.first, isA<UserProfile>());
        expect(review.partners.first.username, 'alice');
      });

      test('parsea user desde clave "users" (JOIN de Supabase)', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'users': {'id': 'uid-1', 'username': 'leafar005'},
        });

        expect(review.user, isNotNull);
        expect(review.user?.username, 'leafar005');
      });

      test('parsea user desde clave "user" (alias alternativo)', () {
        final review = Review.fromMap({
          ...minimalMap(),
          'user': {'id': 'uid-1', 'username': 'leafar005'},
        });

        expect(review.user, isNotNull);
        expect(review.user?.username, 'leafar005');
      });

      test('user es null si no viene el join', () {
        final review = Review.fromMap(minimalMap());
        expect(review.user, isNull);
      });
    });
  });

  group('Review.effectiveRating', () {
    test('devuelve promedio de ratings individuales cuando existen', () {
      final review = Review.fromMap({
        ...minimalMap(),
        'rating_gameplay': 8.0,
        'rating_narrative': 6.0,
        'rating_soundtrack': 10.0,
        'rating_visuals': 8.0,
      });
      // Promedio: (8+6+10+8)/4 = 8.0
      expect(review.effectiveRating, closeTo(8.0, 0.001));
    });

    test('ignora ratings individuales null al calcular promedio', () {
      final review = Review.fromMap({
        ...minimalMap(),
        'rating_gameplay': 9.0,
        'rating_visuals': 7.0,
        // narrative y soundtrack son null
      });
      // Promedio: (9+7)/2 = 8.0
      expect(review.effectiveRating, closeTo(8.0, 0.001));
    });

    test('devuelve rating global si no hay individuales', () {
      final review = Review.fromMap({...minimalMap(), 'rating': 7.5});
      expect(review.effectiveRating, 7.5);
    });

    test('devuelve null si no hay rating global ni individuales', () {
      final review = Review.fromMap(minimalMap());
      expect(review.effectiveRating, isNull);
    });

    test('prefiere individuales sobre rating global si ambos existen', () {
      final review = Review.fromMap({
        ...minimalMap(),
        'rating': 5.0, // global
        'rating_gameplay': 9.0, // individual
        'rating_narrative': 9.0,
      });
      // Debe usar el promedio de individuales (9.0), no el global (5.0)
      expect(review.effectiveRating, closeTo(9.0, 0.001));
    });
  });

  group('Review.toInsertMap', () {
    test('incluye solo los campos necesarios para INSERT', () {
      final review = Review.fromMap({
        ...minimalMap(status: 'playing'),
        'rating': 8.0,
        'comment': 'Muy bueno',
        'platform': 'PC',
        'played_from': '2024-01-01',
        'played_until': '2024-01-20',
        'is_replay': true,
        'image_urls': ['https://example.com/img.jpg'],
      });

      final insertMap = review.toInsertMap();

      expect(insertMap['user_id'], 'user-uuid-1');
      expect(insertMap['game_id'], 1942);
      expect(insertMap['status'], 'playing');
      expect(insertMap['rating'], 8.0);
      expect(insertMap['comment'], 'Muy bueno');
      expect(insertMap['is_replay'], isTrue);
      // toInsertMap NO debe incluir 'id' (lo genera la BD)
      expect(insertMap.containsKey('id'), isFalse);
    });

    test('played_from se serializa como fecha (sin hora) en toInsertMap', () {
      final review = Review.fromMap({
        ...minimalMap(),
        'played_from': '2024-06-15',
      });

      final insertMap = review.toInsertMap();
      // Debe ser solo la parte de fecha, sin timestamp
      expect(insertMap['played_from'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    });
  });

  group('Review.copyWith', () {
    test('crea una copia con status modificado', () {
      final original = Review.fromMap(minimalMap(status: 'playing'));
      final updated = original.copyWith(status: GameStatus.beaten);

      expect(updated.id, original.id);
      expect(updated.status, GameStatus.beaten);
      expect(original.status, GameStatus.playing); // inmutable
    });

    test('copia modifica rating sin alterar el resto', () {
      final original = Review.fromMap({
        ...minimalMap(),
        'rating': 5.0,
        'comment': 'Ok',
      });

      final updated = original.copyWith(rating: 9.0);

      expect(updated.rating, 9.0);
      expect(updated.comment, 'Ok');
    });

    test('preserva createdAt aunque no esté en los parámetros de copyWith', () {
      final original = Review.fromMap({
        ...minimalMap(),
        'created_at': '2024-01-01T00:00:00.000Z',
      });

      final copy = original.copyWith(comment: 'Nuevo comentario');

      expect(copy.createdAt, original.createdAt);
    });
  });

  group('Review equality y hashCode', () {
    test('dos reviews con mismo id son iguales', () {
      final a = Review.fromMap(minimalMap(id: 'same-id'));
      final b = Review.fromMap(minimalMap(id: 'same-id', status: 'playing'));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('dos reviews con distinto id no son iguales', () {
      final a = Review.fromMap(minimalMap(id: 'id-1'));
      final b = Review.fromMap(minimalMap(id: 'id-2'));
      expect(a, isNot(equals(b)));
    });
  });
}
