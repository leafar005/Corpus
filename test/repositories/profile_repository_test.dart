// test/repositories/profile_repository_test.dart
//
// Tests unitarios para los helpers estáticos de ProfileRepository.
// Prueban la lógica de parseo y filtrado sin necesitar Supabase real.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/repositories/profile_repository.dart';

void main() {
  // ── Datos de prueba ────────────────────────────────────────────────────────

  Map<String, dynamic> makeRow({
    required String status,
    required Map<String, dynamic> game,
    double rating = 0,
    String? updatedAt,
    String? lastPlayedAt,
    bool isSteamOnly = false,
  }) => {
    'status': status,
    'games': game,
    'rating': rating,
    'updated_at': updatedAt ?? '2024-01-10T00:00:00',
    'last_played_at': lastPlayedAt,
    'is_steam_only': isSteamOnly,
  };

  final gameA = {'id': 1, 'title': 'Hades'};
  final gameB = {'id': 2, 'title': 'Celeste'};
  final gameC = {'id': 3, 'title': 'Hollow Knight'};
  final gameD = {'id': 4, 'title': 'Disco Elysium'};

  // ── extractWishlist ────────────────────────────────────────────────────────

  group('ProfileRepository.extractWishlist', () {
    test('extrae solo los juegos con status wishlist', () {
      final rows = [
        makeRow(
          status: 'wishlist',
          game: gameA,
          updatedAt: '2024-01-10T00:00:00',
        ),
        makeRow(
          status: 'playing',
          game: gameB,
          updatedAt: '2024-01-10T00:00:00',
        ),
        makeRow(
          status: 'beaten',
          game: gameC,
          updatedAt: '2024-01-10T00:00:00',
        ),
      ];

      final result = ProfileRepository.extractWishlist(rows);

      expect(result.length, 1);
      expect(result.first['title'], 'Hades');
    });

    test('excluye juegos is_steam_only aunque sean wishlist', () {
      final rows = [
        makeRow(status: 'wishlist', game: gameA, isSteamOnly: true),
        makeRow(status: 'wishlist', game: gameB),
      ];

      final result = ProfileRepository.extractWishlist(rows);

      expect(result.length, 1);
      expect(result.first['title'], 'Celeste');
    });

    test('excluye filas sin gameData (games = null)', () {
      final rows = [
        {
          'status': 'wishlist',
          'games': null,
          'rating': 0,
          'updated_at': '2024-01-01',
        },
        makeRow(status: 'wishlist', game: gameB),
      ];

      final result = ProfileRepository.extractWishlist(rows);
      expect(result.length, 1);
    });

    test('ordena por updated_at descendente', () {
      final rows = [
        makeRow(
          status: 'wishlist',
          game: gameA,
          updatedAt: '2024-01-01T00:00:00',
        ),
        makeRow(
          status: 'wishlist',
          game: gameB,
          updatedAt: '2024-03-15T00:00:00',
        ),
        makeRow(
          status: 'wishlist',
          game: gameC,
          updatedAt: '2024-02-10T00:00:00',
        ),
      ];

      final result = ProfileRepository.extractWishlist(rows);

      expect(result[0]['title'], 'Celeste'); // 2024-03-15 más reciente
      expect(result[1]['title'], 'Hollow Knight'); // 2024-02-10
      expect(result[2]['title'], 'Hades'); // 2024-01-01 más antiguo
    });

    test('inyecta user_rating y _sort_date en el gameData', () {
      final rows = [
        makeRow(
          status: 'wishlist',
          game: gameA,
          rating: 7.5,
          updatedAt: '2024-01-10T00:00:00',
        ),
      ];

      final result = ProfileRepository.extractWishlist(rows);

      expect(result.first['user_rating'], 7.5);
      expect(result.first['_sort_date'], '2024-01-10T00:00:00');
    });

    test('devuelve lista vacía si no hay juegos wishlist', () {
      final rows = [
        makeRow(status: 'playing', game: gameA),
        makeRow(status: 'beaten', game: gameB),
      ];

      expect(ProfileRepository.extractWishlist(rows), isEmpty);
    });

    test('no muta el gameData original de la respuesta de Supabase', () {
      final originalGame = {'id': 1, 'title': 'Hades'};
      final rows = [
        makeRow(status: 'wishlist', game: originalGame, rating: 9.0),
      ];

      ProfileRepository.extractWishlist(rows);

      // El mapa original NO debe tener user_rating ni _sort_date
      expect(originalGame.containsKey('user_rating'), isFalse);
      expect(originalGame.containsKey('_sort_date'), isFalse);
    });
  });

  // ── extractPlaying ─────────────────────────────────────────────────────────

  group('ProfileRepository.extractPlaying', () {
    test('extrae solo los juegos con status playing', () {
      final rows = [
        makeRow(status: 'playing', game: gameA),
        makeRow(status: 'wishlist', game: gameB),
        makeRow(status: 'beaten', game: gameC),
      ];

      final result = ProfileRepository.extractPlaying(rows);
      expect(result.length, 1);
      expect(result.first['title'], 'Hades');
    });

    test('ordena por updated_at descendente', () {
      final rows = [
        makeRow(
          status: 'playing',
          game: gameA,
          updatedAt: '2024-01-01T00:00:00',
        ),
        makeRow(
          status: 'playing',
          game: gameB,
          updatedAt: '2024-06-01T00:00:00',
        ),
      ];

      final result = ProfileRepository.extractPlaying(rows);
      expect(result.first['title'], 'Celeste'); // más reciente primero
    });

    test('no excluye juegos is_steam_only en playing (solo en wishlist)', () {
      final rows = [
        makeRow(status: 'playing', game: gameA, isSteamOnly: true),
        makeRow(status: 'playing', game: gameB),
      ];

      final result = ProfileRepository.extractPlaying(rows);
      expect(result.length, 2);
    });
  });

  // ── extractBeaten ──────────────────────────────────────────────────────────

  group('ProfileRepository.extractBeaten', () {
    test('extrae solo los juegos con status beaten', () {
      final rows = [
        makeRow(status: 'beaten', game: gameA),
        makeRow(status: 'playing', game: gameB),
      ];

      final result = ProfileRepository.extractBeaten(rows);
      expect(result.length, 1);
      expect(result.first['title'], 'Hades');
    });

    test('usa last_played_at para ordenar si está disponible', () {
      final rows = [
        makeRow(
          status: 'beaten',
          game: gameA,
          updatedAt: '2024-06-01T00:00:00',
          lastPlayedAt: '2024-01-01T00:00:00', // last_played_at más antiguo
        ),
        makeRow(
          status: 'beaten',
          game: gameB,
          updatedAt: '2024-01-01T00:00:00',
          lastPlayedAt: '2024-06-01T00:00:00', // last_played_at más reciente
        ),
      ];

      final result = ProfileRepository.extractBeaten(rows);
      // Ordenado por last_played_at → Celeste (2024-06-01) antes que Hades (2024-01-01)
      expect(result.first['title'], 'Celeste');
    });

    test('usa updated_at si last_played_at es null', () {
      final rows = [
        makeRow(
          status: 'beaten',
          game: gameA,
          updatedAt: '2024-03-01T00:00:00',
          lastPlayedAt: null,
        ),
      ];

      final result = ProfileRepository.extractBeaten(rows);
      expect(result.first['_sort_date'], '2024-03-01T00:00:00');
    });

    test('inyecta user_rating con precisión double', () {
      final rows = [makeRow(status: 'beaten', game: gameA, rating: 8.5)];
      final result = ProfileRepository.extractBeaten(rows);
      expect(result.first['user_rating'], 8.5);
    });
  });

  // ── parseHallOfFame ────────────────────────────────────────────────────────

  group('ProfileRepository.parseHallOfFame', () {
    test('convierte lista raw en lista fija de 5 posiciones', () {
      final raw = [
        {'pin_order': 1, 'games': gameA},
        {'pin_order': 3, 'games': gameC},
        {'pin_order': 5, 'games': gameD},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);

      expect(result.length, 5);
      expect(result[0]?['title'], 'Hades');
      expect(result[1], isNull); // posición 2 vacía
      expect(result[2]?['title'], 'Hollow Knight');
      expect(result[3], isNull); // posición 4 vacía
      expect(result[4]?['title'], 'Disco Elysium');
    });

    test('devuelve lista de 5 nulls si la entrada está vacía', () {
      final result = ProfileRepository.parseHallOfFame([]);
      expect(result.length, 5);
      expect(result.every((e) => e == null), isTrue);
    });

    test('ignora filas con pin_order fuera de rango [1, 5]', () {
      final raw = [
        {'pin_order': 0, 'games': gameA}, // fuera de rango
        {'pin_order': 6, 'games': gameB}, // fuera de rango
        {'pin_order': 2, 'games': gameC}, // válido
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      expect(result[1]?['title'], 'Hollow Knight');
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

    test('ignora filas con pin_order = null', () {
      final raw = [
        {'pin_order': null, 'games': gameA},
        {'pin_order': 3, 'games': gameC},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      expect(result.where((e) => e != null).length, 1);
      expect(result[2]?['title'], 'Hollow Knight');
    });

    test('no muta los mapas originales de los juegos', () {
      final originalGame = {'id': 1, 'title': 'Hades'};
      final raw = [
        {'pin_order': 1, 'games': originalGame},
      ];

      final result = ProfileRepository.parseHallOfFame(raw);
      // Modificar el resultado no debe afectar al original
      result[0]!['extra_field'] = 'test';
      expect(originalGame.containsKey('extra_field'), isFalse);
    });
  });

  // ── Integración de los tres extractores ───────────────────────────────────

  group('Extracción combinada (wishlist + playing + beaten)', () {
    test(
      'un mismo lote de filas se separa correctamente en los tres grupos',
      () {
        final rows = [
          makeRow(
            status: 'wishlist',
            game: gameA,
            updatedAt: '2024-01-01T00:00:00',
          ),
          makeRow(status: 'wishlist', game: gameB, isSteamOnly: true),
          makeRow(
            status: 'playing',
            game: gameC,
            updatedAt: '2024-01-01T00:00:00',
          ),
          makeRow(
            status: 'beaten',
            game: gameD,
            updatedAt: '2024-01-01T00:00:00',
          ),
          // Statuses que no mapean a ningún grupo:
          makeRow(status: 'abandoned', game: {'id': 5, 'title': 'X'}),
          makeRow(status: 'on_hold', game: {'id': 6, 'title': 'Y'}),
        ];

        final wishlist = ProfileRepository.extractWishlist(rows);
        final playing = ProfileRepository.extractPlaying(rows);
        final beaten = ProfileRepository.extractBeaten(rows);

        // Solo Hades (no steam_only) en wishlist
        expect(wishlist.map((g) => g['title']), ['Hades']);
        expect(playing.map((g) => g['title']), ['Hollow Knight']);
        expect(beaten.map((g) => g['title']), ['Disco Elysium']);
      },
    );

    test('devuelve listas vacías para categorías sin juegos', () {
      final rows = [makeRow(status: 'playing', game: gameA)];

      expect(ProfileRepository.extractWishlist(rows), isEmpty);
      expect(ProfileRepository.extractBeaten(rows), isEmpty);
    });
  });
}
