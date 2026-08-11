// test/models/game_test.dart
//
// Tests unitarios para Game.fromMap / toMap y sus helpers de parsing.
// No requieren Flutter ni Supabase — solo Dart puro.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/game.dart';

void main() {
  group('Game.fromMap', () {
    group('Campos obligatorios', () {
      test('parsea igdb_id y title mínimos', () {
        final game = Game.fromMap({'igdb_id': 1942, 'title': 'Hades'});
        expect(game.igdbId, 1942);
        expect(game.title, 'Hades');
      });

      test('acepta id como alias de igdb_id', () {
        final game = Game.fromMap({'id': 999, 'title': 'Celeste'});
        expect(game.igdbId, 999);
      });

      test('title usa name como fallback', () {
        final game = Game.fromMap({'igdb_id': 1, 'name': 'Hollow Knight'});
        expect(game.title, 'Hollow Knight');
      });

      test('title es cadena vacía si no viene ningún campo', () {
        final game = Game.fromMap({'igdb_id': 1});
        expect(game.title, '');
      });
    });

    group('cover_url', () {
      test('usa cover_url directo si está presente', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'cover_url': 'https://example.com/cover.jpg',
        });
        expect(game.coverUrl, 'https://example.com/cover.jpg');
      });

      test('construye URL desde cover.image_id si no hay cover_url', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'cover': {'image_id': 'abc123'},
        });
        expect(
          game.coverUrl,
          'https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg',
        );
      });

      test('cover_url es null si no viene ningún campo de cover', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.coverUrl, isNull);
      });

      test('cover_url es null si cover.image_id es null', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'cover': {'image_id': null},
        });
        expect(game.coverUrl, isNull);
      });
    });

    group('release_date', () {
      test('parsea first_release_date como timestamp Unix en segundos', () {
        // 2011-10-11 = 1318291200
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'first_release_date': 1318291200,
        });
        expect(game.releaseDate, isNotNull);
        expect(game.releaseDate, contains('2011-10-11'));
      });

      test('usa release_date como string si no hay first_release_date', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'release_date': '2017-03-03',
        });
        expect(game.releaseDate, '2017-03-03');
      });

      test('releaseDate es null si no vienen fechas', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.releaseDate, isNull);
      });
    });

    group('Listas (genres, platforms, etc.)', () {
      test('parsea lista de strings planos', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'genres': ['RPG', 'Action'],
        });
        expect(game.genres, ['RPG', 'Action']);
      });

      test('parsea lista de objetos IGDB con campo name', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'platforms': [
            {'name': 'PC'},
            {'name': 'PlayStation 5'},
          ],
        });
        expect(game.platforms, ['PC', 'PlayStation 5']);
      });

      test('filtra strings vacíos de objetos IGDB sin name', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'themes': [
            {'name': 'Fantasy'},
            {'name': null},
          ],
        });
        expect(game.themes, ['Fantasy']);
      });

      test('acepta un único string como lista de un elemento', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'genres': 'Action',
        });
        expect(game.genres, ['Action']);
      });

      test('devuelve lista vacía si genres es null', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.genres, isEmpty);
        expect(game.themes, isEmpty);
        expect(game.platforms, isEmpty);
        expect(game.gameModes, isEmpty);
        expect(game.gameEngines, isEmpty);
        expect(game.franchises, isEmpty);
      });
    });

    group('collection', () {
      test('parsea collection como mapa IGDB con campo name', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'collection': {'name': 'The Witcher Series'},
        });
        expect(game.collection, 'The Witcher Series');
      });

      test('parsea collection como string directo', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'collection': 'Dark Souls',
        });
        expect(game.collection, 'Dark Souls');
      });

      test('collection es null si el string está vacío', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'collection': '',
        });
        expect(game.collection, isNull);
      });

      test('collection es null si es null', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.collection, isNull);
      });
    });

    group('Metacritic', () {
      test('parsea todos los campos de metacritic', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'metacritic_score': 94,
          'metacritic_url': 'https://metacritic.com/game/hades',
          'metacritic_user_score': 8.7,
          'metacritic_slug': 'hades',
          'metacritic_updated_at': '2024-01-15T00:00:00.000Z',
        });
        expect(game.metacriticScore, 94);
        expect(game.metacriticUrl, 'https://metacritic.com/game/hades');
        expect(game.metacriticUserScore, closeTo(8.7, 0.001));
        expect(game.metacriticSlug, 'hades');
        expect(game.metacriticUpdatedAt, isNotNull);
      });

      test('campos metacritic son null si no vienen', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.metacriticScore, isNull);
        expect(game.metacriticUrl, isNull);
        expect(game.metacriticUserScore, isNull);
        expect(game.metacriticUpdatedAt, isNull);
      });

      test('metacritic_score acepta num y lo convierte a int', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'metacritic_score': 91.0, // puede venir como double de JSON
        });
        expect(game.metacriticScore, 91);
        expect(game.metacriticScore, isA<int>());
      });
    });

    group('Campos opcionales', () {
      test('isSteamOnly es false por defecto', () {
        final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
        expect(game.isSteamOnly, isFalse);
      });

      test('isSteamOnly se parsea correctamente como true', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'is_steam_only': true,
        });
        expect(game.isSteamOnly, isTrue);
      });

      test('category y parentGameId se parsean como int', () {
        final game = Game.fromMap({
          'igdb_id': 1,
          'title': 'X',
          'category': 3,
          'parent_game': 42,
        });
        expect(game.category, 3);
        expect(game.parentGameId, 42);
      });
    });
  });

  group('Game.toMap', () {
    test('round-trip: fromMap → toMap preserva los datos esenciales', () {
      final original = Game.fromMap({
        'igdb_id': 1942,
        'title': 'Hades',
        'cover_url': 'https://example.com/cover.jpg',
        'release_date': '2020-09-17',
        'genres': ['Action', 'RPG'],
        'platforms': ['PC', 'Nintendo Switch'],
        'metacritic_score': 93,
      });

      final map = original.toMap();

      expect(map['igdb_id'], 1942);
      expect(map['title'], 'Hades');
      expect(map['cover_url'], 'https://example.com/cover.jpg');
      expect(map['release_date'], '2020-09-17');
      expect(map['genres'], ['Action', 'RPG']);
      expect(map['platforms'], ['PC', 'Nintendo Switch']);
      expect(map['metacritic_score'], 93);
    });

    test('toMap omite campos nulos y listas vacías', () {
      final game = Game.fromMap({'igdb_id': 1, 'title': 'Minimal'});
      final map = game.toMap();

      expect(map.containsKey('cover_url'), isFalse);
      expect(map.containsKey('summary'), isFalse);
      expect(map.containsKey('metacritic_score'), isFalse);
      expect(map.containsKey('genres'), isFalse);
      expect(map.containsKey('platforms'), isFalse);
    });

    test('toMap incluye is_steam_only solo si es true', () {
      final steamGame = Game.fromMap({
        'igdb_id': 1,
        'title': 'X',
        'is_steam_only': true,
      });
      expect(steamGame.toMap()['is_steam_only'], isTrue);

      final normalGame = Game.fromMap({'igdb_id': 1, 'title': 'X'});
      expect(normalGame.toMap().containsKey('is_steam_only'), isFalse);
    });
  });

  group('Game.hasRecentMetacriticData', () {
    test('es false si metacriticScore es null', () {
      final game = Game.fromMap({'igdb_id': 1, 'title': 'X'});
      expect(game.hasRecentMetacriticData, isFalse);
    });

    test('es false si metacriticUpdatedAt es null', () {
      const game = Game(igdbId: 1, title: 'X', metacriticScore: 90);
      expect(game.hasRecentMetacriticData, isFalse);
    });

    test('es true si la fecha es reciente (ayer)', () {
      final game = Game(
        igdbId: 1,
        title: 'X',
        metacriticScore: 90,
        metacriticUpdatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(game.hasRecentMetacriticData, isTrue);
    });

    test('es false si la fecha tiene más de 30 días', () {
      final game = Game(
        igdbId: 1,
        title: 'X',
        metacriticScore: 90,
        metacriticUpdatedAt: DateTime.now().subtract(const Duration(days: 31)),
      );
      expect(game.hasRecentMetacriticData, isFalse);
    });
  });

  group('Game equality y hashCode', () {
    test('dos Game con mismo igdbId son iguales', () {
      final a = Game.fromMap({'igdb_id': 42, 'title': 'Foo'});
      final b = Game.fromMap({'igdb_id': 42, 'title': 'Bar'});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('dos Game con distinto igdbId no son iguales', () {
      final a = Game.fromMap({'igdb_id': 1, 'title': 'X'});
      final b = Game.fromMap({'igdb_id': 2, 'title': 'X'});
      expect(a, isNot(equals(b)));
    });
  });
}
