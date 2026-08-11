// test/models/user_profile_test.dart
//
// Tests unitarios para UserProfile.fromMap / toMap / copyWith.
// No requieren Flutter ni Supabase — solo Dart puro.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/user_profile.dart';

void main() {
  group('UserProfile.fromMap', () {
    test('parsea todos los campos correctamente', () {
      final profile = UserProfile.fromMap(const {
        'id': 'user-uuid-123',
        'username': 'leafar005',
        'display_name': 'Rafael',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Amante de los JRPGs',
        'xp': 4200,
        'level': 8,
      });

      expect(profile.id, 'user-uuid-123');
      expect(profile.username, 'leafar005');
      expect(profile.displayName, 'Rafael');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.bio, 'Amante de los JRPGs');
      expect(profile.xp, 4200);
      expect(profile.level, 8);
    });

    test('username cae a cadena vacía si viene null', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': null,
      });
      expect(profile.username, '');
    });

    test('campos opcionales son null si no vienen', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'user',
      });

      expect(profile.displayName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
      expect(profile.xp, isNull);
      expect(profile.level, isNull);
    });

    test('xp y level aceptan num (double de JSON) y convierten a int', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'user',
        'xp': 1500.0,
        'level': 5.0,
      });

      expect(profile.xp, 1500);
      expect(profile.xp, isA<int>());
      expect(profile.level, 5);
      expect(profile.level, isA<int>());
    });
  });

  group('UserProfile.effectiveName', () {
    test('devuelve displayName si existe y no está vacío', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'leafar005',
        'display_name': 'Rafael',
      });
      expect(profile.effectiveName, 'Rafael');
    });

    test('devuelve username si displayName es null', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'leafar005',
      });
      expect(profile.effectiveName, 'leafar005');
    });

    test('devuelve username si displayName es cadena vacía', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'leafar005',
        'display_name': '',
      });
      expect(profile.effectiveName, 'leafar005');
    });
  });

  group('UserProfile.toMap', () {
    test('round-trip: fromMap → toMap preserva los datos', () {
      final original = UserProfile.fromMap(const {
        'id': 'user-uuid-123',
        'username': 'leafar005',
        'display_name': 'Rafael',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Bio text',
        'xp': 4200,
        'level': 8,
      });

      final map = original.toMap();

      expect(map['id'], 'user-uuid-123');
      expect(map['username'], 'leafar005');
      expect(map['display_name'], 'Rafael');
      expect(map['avatar_url'], 'https://example.com/avatar.jpg');
      expect(map['bio'], 'Bio text');
      expect(map['xp'], 4200);
      expect(map['level'], 8);
    });

    test('toMap omite claves opcionales si son null', () {
      final profile = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'user',
      });
      final map = profile.toMap();

      expect(map.containsKey('display_name'), isFalse);
      expect(map.containsKey('avatar_url'), isFalse);
      expect(map.containsKey('bio'), isFalse);
      expect(map.containsKey('xp'), isFalse);
      expect(map.containsKey('level'), isFalse);
    });
  });

  group('UserProfile.copyWith', () {
    test('crea una copia con un solo campo modificado', () {
      final original = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'leafar005',
        'bio': 'Old bio',
        'xp': 100,
        'level': 1,
      });

      final updated = original.copyWith(bio: 'New bio');

      expect(updated.id, original.id);
      expect(updated.username, original.username);
      expect(updated.xp, original.xp);
      expect(updated.bio, 'New bio');
    });

    test('copyWith sin argumentos devuelve objeto con mismos valores', () {
      final original = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'user',
        'xp': 500,
        'level': 3,
      });

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.username, original.username);
      expect(copy.xp, original.xp);
      expect(copy.level, original.level);
    });

    test('copyWith puede actualizar xp y level a la vez', () {
      final original = UserProfile.fromMap(const {
        'id': 'abc',
        'username': 'user',
        'xp': 100,
        'level': 1,
      });

      final leveled = original.copyWith(xp: 2000, level: 5);

      expect(leveled.xp, 2000);
      expect(leveled.level, 5);
      expect(leveled.id, original.id);
    });
  });

  group('UserProfile equality y hashCode', () {
    test('dos perfiles con mismo id son iguales', () {
      final a = UserProfile.fromMap(const {'id': 'same', 'username': 'alice'});
      final b = UserProfile.fromMap(const {'id': 'same', 'username': 'bob'});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('dos perfiles con distinto id no son iguales', () {
      final a = UserProfile.fromMap(const {'id': 'aaa', 'username': 'user'});
      final b = UserProfile.fromMap(const {'id': 'bbb', 'username': 'user'});
      expect(a, isNot(equals(b)));
    });
  });
}
