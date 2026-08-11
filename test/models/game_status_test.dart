// test/models/game_status_test.dart
//
// Tests unitarios para el enum GameStatus: fromString, fromStringOrDefault,
// dbValue, label, shortLabel, icon, emoji y helpers estáticos.
// No requieren Flutter (evitamos los métodos que usan BuildContext).

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/game_status.dart';

void main() {
  group('GameStatus.fromString', () {
    test('parsea los valores canónicos de PostgreSQL', () {
      expect(GameStatus.fromString('playing'), GameStatus.playing);
      expect(GameStatus.fromString('beaten'), GameStatus.beaten);
      expect(GameStatus.fromString('wishlist'), GameStatus.wishlist);
      expect(GameStatus.fromString('abandoned'), GameStatus.abandoned);
      expect(GameStatus.fromString('on_hold'), GameStatus.onHold);
      expect(GameStatus.fromString('completed'), GameStatus.completed);
    });

    test('parsea alias en español', () {
      expect(GameStatus.fromString('jugando'), GameStatus.playing);
      expect(GameStatus.fromString('terminado'), GameStatus.beaten);
      expect(GameStatus.fromString('quiero'), GameStatus.wishlist);
      expect(GameStatus.fromString('abandonado'), GameStatus.abandoned);
      expect(GameStatus.fromString('pausado'), GameStatus.onHold);
      expect(GameStatus.fromString('en pausa'), GameStatus.onHold);
      expect(GameStatus.fromString('platino'), GameStatus.completed);
    });

    test('parsea alias en inglés alternativos', () {
      expect(GameStatus.fromString('want'), GameStatus.wishlist);
      expect(GameStatus.fromString('finished'), GameStatus.beaten);
      expect(GameStatus.fromString('in progress'), GameStatus.playing);
      expect(GameStatus.fromString('dropped'), GameStatus.abandoned);
      expect(GameStatus.fromString('on hold'), GameStatus.onHold);
      expect(GameStatus.fromString('paused'), GameStatus.onHold);
      expect(GameStatus.fromString('archived'), GameStatus.abandoned);
    });

    test('es case-insensitive', () {
      expect(GameStatus.fromString('PLAYING'), GameStatus.playing);
      expect(GameStatus.fromString('Beaten'), GameStatus.beaten);
      expect(GameStatus.fromString('ON_HOLD'), GameStatus.onHold);
    });

    test('ignora espacios al inicio y al final', () {
      expect(GameStatus.fromString('  playing  '), GameStatus.playing);
      expect(GameStatus.fromString(' on_hold '), GameStatus.onHold);
    });

    test('lanza ArgumentError si el valor es completamente desconocido', () {
      expect(
        () => GameStatus.fromString('gibberish_xyz'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GameStatus.fromStringOrDefault', () {
    test('devuelve wishlist por defecto si el string es null', () {
      expect(GameStatus.fromStringOrDefault(null), GameStatus.wishlist);
    });

    test('devuelve wishlist por defecto si el string está vacío', () {
      expect(GameStatus.fromStringOrDefault(''), GameStatus.wishlist);
      expect(GameStatus.fromStringOrDefault('   '), GameStatus.wishlist);
    });

    test('devuelve fallback personalizado si el valor es inválido', () {
      expect(
        GameStatus.fromStringOrDefault(
          'unknown',
          fallback: GameStatus.abandoned,
        ),
        GameStatus.abandoned,
      );
    });

    test('parsea valores válidos normalmente', () {
      expect(
        GameStatus.fromStringOrDefault('playing'),
        GameStatus.playing,
      );
    });
  });

  group('GameStatus.dbValue', () {
    test('los dbValues coinciden exactamente con el enum de PostgreSQL', () {
      // Estos valores son los que existen en la migración SQL de Supabase.
      // Si este test falla, hay un bug de sincronización DB↔Dart.
      expect(GameStatus.wishlist.dbValue, 'wishlist');
      expect(GameStatus.playing.dbValue, 'playing');
      expect(GameStatus.beaten.dbValue, 'beaten');
      expect(GameStatus.completed.dbValue, 'completed');
      expect(GameStatus.abandoned.dbValue, 'abandoned');
      expect(GameStatus.onHold.dbValue, 'on_hold');
    });

    test('round-trip: fromString(status.dbValue) devuelve el mismo status', () {
      for (final status in GameStatus.values) {
        // completed tiene dbValue 'completed' que puede no existir en la BD
        // real, pero el round-trip en Dart debe funcionar igual
        final roundTripped = GameStatus.fromString(status.dbValue);
        expect(roundTripped, status, reason: 'Fallo en round-trip para: $status');
      }
    });
  });

  group('GameStatus UI extensions', () {
    test('label devuelve texto legible para todos los valores', () {
      expect(GameStatus.wishlist.label, isNotEmpty);
      expect(GameStatus.playing.label, isNotEmpty);
      expect(GameStatus.beaten.label, isNotEmpty);
      expect(GameStatus.completed.label, isNotEmpty);
      expect(GameStatus.abandoned.label, isNotEmpty);
      expect(GameStatus.onHold.label, isNotEmpty);
    });

    test('shortLabel devuelve texto corto para todos los valores', () {
      for (final status in GameStatus.values) {
        expect(status.shortLabel, isNotEmpty, reason: 'shortLabel vacío para $status');
      }
    });

    test('icon devuelve un IconData para todos los valores', () {
      for (final status in GameStatus.values) {
        expect(status.icon, isNotNull, reason: 'icon null para $status');
      }
    });

    test('emoji devuelve un string no vacío para todos los valores', () {
      for (final status in GameStatus.values) {
        expect(status.emoji, isNotEmpty, reason: 'emoji vacío para $status');
      }
    });

    test('label de onHold NO dice paused (verificación de rename)', () {
      // Validamos que el renombre paused→onHold se reflejó en los textos UI
      expect(GameStatus.onHold.label.toLowerCase(), isNot(contains('paused')));
      expect(GameStatus.onHold.label.toLowerCase(), isNot(contains('pause')));
    });
  });

  group('GameStatus helpers estáticos', () {
    test('labelForString devuelve el shortLabel del status parseado', () {
      expect(
        GameStatus.labelForString('playing'),
        GameStatus.playing.shortLabel,
      );
    });

    test('labelForString con valor null devuelve label del fallback (wishlist)', () {
      expect(
        GameStatus.labelForString(null),
        GameStatus.wishlist.shortLabel,
      );
    });

    test('iconForString devuelve el icono del status parseado', () {
      expect(
        GameStatus.iconForString('beaten'),
        GameStatus.beaten.icon,
      );
    });

    test('iconForString con valor inválido devuelve icono del fallback', () {
      expect(
        GameStatus.iconForString('gibberish'),
        GameStatus.wishlist.icon,
      );
    });
  });
}
