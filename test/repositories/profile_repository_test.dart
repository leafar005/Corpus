// test/repositories/profile_repository_test.dart
//
// Tests unitarios para los helpers estáticos de ProfileRepository.
// Prueban la lógica de parseo y ordenado sin necesitar Supabase real.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/repositories/profile_repository.dart';

void main() {
  Map<String, dynamic> makeRow({
    required Map<String, dynamic> game,
    double rating = 0,
    String? updatedAt,
    String? lastPlayedAt,
  }) => {
    'games': game,
    'rating': rating,
    'updated_at': updatedAt ?? '2024-01-10T00:00:00',
    'last_played_at': lastPlayedAt,
  };

  final gameA = {'id': 1, 'title': 'Hades'};
  final gameB = {'id': 2, 'title': 'Celeste'};

  group('ProfileRepository.enrichList', () {
    test('excluye filas sin gameData (games = null)', () {
      final rows = [
        {'games': null, 'rating': 0, 'updated_at': '2024-01-01'},
        makeRow(game: gameB),
      ];

      final result = ProfileRepository.enrichList(rows);
      expect(result.length, 1);
    });

    test('ordena por _sort_date descendente', () {
      final rows = [
        makeRow(game: gameA, updatedAt: '2024-01-01T00:00:00'),
        makeRow(game: gameB, updatedAt: '2024-03-15T00:00:00'),
      ];

      final result = ProfileRepository.enrichList(rows);

      expect(result[0]['title'], 'Celeste'); // 2024-03-15
      expect(result[1]['title'], 'Hades'); // 2024-01-01
    });

    test('inyecta user_rating y _sort_date en el gameData', () {
      final rows = [
        makeRow(game: gameA, rating: 7.5, updatedAt: '2024-01-10T00:00:00'),
      ];

      final result = ProfileRepository.enrichList(rows);

      expect(result.first['user_rating'], 7.5);
      expect(result.first['_sort_date'], '2024-01-10T00:00:00');
    });

    test('usa last_played_at para _sort_date si useLastPlayed es true', () {
      final rows = [
        makeRow(
          game: gameA,
          updatedAt: '2024-06-01T00:00:00',
          lastPlayedAt: '2024-01-01T00:00:00',
        ),
      ];

      final result = ProfileRepository.enrichList(rows, useLastPlayed: true);
      expect(result.first['_sort_date'], '2024-01-01T00:00:00');
    });

    test('no muta el gameData original', () {
      final originalGame = {'id': 1, 'title': 'Hades'};
      final rows = [makeRow(game: originalGame, rating: 9.0)];

      ProfileRepository.enrichList(rows);

      expect(originalGame.containsKey('user_rating'), isFalse);
      expect(originalGame.containsKey('_sort_date'), isFalse);
    });
  });

  group('ProfileRepository.parseHallOfFame', () {
    test('convierte lista raw en lista fija de 5 posiciones', () {
      final raw = [
        {'pin_order': 1, 'games': gameA},
        {'pin_order': 3, 'games': gameB},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);

      expect(result.length, 5);
      expect(result[0]?['title'], 'Hades');
      expect(result[1], isNull);
      expect(result[2]?['title'], 'Celeste');
      expect(result[3], isNull);
      expect(result[4], isNull);
    });

    test('devuelve lista de 5 nulls si la entrada está vacía', () {
      final result = ProfileRepository.parseHallOfFame([]);
      expect(result.length, 5);
      expect(result.every((e) => e == null), isTrue);
    });

    test('ignora filas con pin_order fuera de rango', () {
      final raw = [
        {'pin_order': 0, 'games': gameA},
        {'pin_order': 6, 'games': gameA},
        {'pin_order': 2, 'games': gameB},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      expect(result[1]?['title'], 'Celeste');
      expect(result.where((e) => e != null).length, 1);
    });

    test('ignora filas con games = null', () {
      final raw = [
        {'pin_order': 1, 'games': null},
        {'pin_order': 2, 'games': gameB},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      expect(result[0], isNull);
      expect(result[1]?['title'], 'Celeste');
    });

    test('no muta los mapas originales de los juegos', () {
      final originalGame = {'id': 1, 'title': 'Hades'};
      final raw = [
        {'pin_order': 1, 'games': originalGame},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      result[0]!['extra_field'] = 'test';
      expect(originalGame.containsKey('extra_field'), isFalse);
    });
  });
}
