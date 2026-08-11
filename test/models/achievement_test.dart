// test/models/achievement_test.dart
//
// Tests unitarios para Achievement.fromMap / toMap.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/models/achievement.dart';

void main() {
  group('Achievement.fromMap', () {
    test('parsea todos los campos correctamente desde mapa plano', () {
      final ach = Achievement.fromMap({
        'id': 'ach-001',
        'name': 'Primer logro',
        'description': 'Completa tu primer juego',
        'category': 'progress',
        'xp_reward': 100,
        'rarity': 'common',
        'icon_name': 'star',
        'unlocked_at': '2024-01-10T12:00:00.000Z',
      });

      expect(ach.id, 'ach-001');
      expect(ach.name, 'Primer logro');
      expect(ach.description, 'Completa tu primer juego');
      expect(ach.category, 'progress');
      expect(ach.xpReward, 100);
      expect(ach.rarity, 'common');
      expect(ach.iconName, 'star');
      expect(ach.unlockedAt, isNotNull);
    });

    test('parsea desde un mapa anidado bajo la clave "achievements" (JOIN de Supabase)', () {
      // Cuando se consulta user_achievements con join, los datos llegan anidados.
      final ach = Achievement.fromMap({
        'unlocked_at': '2024-06-01T08:00:00.000Z',
        'achievements': {
          'id': 'ach-002',
          'name': 'Coleccionista',
          'description': 'Añade 10 juegos a tu biblioteca',
          'category': 'library',
          'xp_reward': 250,
          'rarity': 'rare',
          'icon_name': 'collection',
        },
      });

      expect(ach.id, 'ach-002');
      expect(ach.name, 'Coleccionista');
      expect(ach.xpReward, 250);
      expect(ach.rarity, 'rare');
      expect(ach.unlockedAt, isNotNull);
      expect(ach.unlockedAt?.year, 2024);
    });

    test('xp_reward acepta num (double de JSON) y convierte a int', () {
      final ach = Achievement.fromMap({
        'id': 'ach-003',
        'name': 'X',
        'description': '',
        'category': 'x',
        'xp_reward': 500.0,
        'rarity': 'common',
        'icon_name': 'star',
      });

      expect(ach.xpReward, 500);
      expect(ach.xpReward, isA<int>());
    });

    test('campos opcionales tienen valores por defecto si no vienen', () {
      final ach = Achievement.fromMap({});
      expect(ach.id, '');
      expect(ach.name, '');
      expect(ach.description, '');
      expect(ach.category, '');
      expect(ach.xpReward, 0);
      expect(ach.rarity, 'common');
      expect(ach.iconName, 'star');
      expect(ach.unlockedAt, isNull);
    });

    test('unlockedAt es null si no viene la clave', () {
      final ach = Achievement.fromMap({
        'id': 'ach-004',
        'name': 'X',
        'description': '',
        'category': 'x',
        'xp_reward': 50,
        'rarity': 'common',
        'icon_name': 'star',
      });

      expect(ach.unlockedAt, isNull);
    });
  });

  group('Achievement.toMap', () {
    test('round-trip: fromMap → toMap preserva los datos', () {
      final original = Achievement.fromMap({
        'id': 'ach-001',
        'name': 'Logro épico',
        'description': 'Descripción del logro',
        'category': 'social',
        'xp_reward': 1000,
        'rarity': 'legendary',
        'icon_name': 'trophy',
        'unlocked_at': '2024-03-15T00:00:00.000Z',
      });

      final map = original.toMap();

      expect(map['id'], 'ach-001');
      expect(map['name'], 'Logro épico');
      expect(map['description'], 'Descripción del logro');
      expect(map['category'], 'social');
      expect(map['xp_reward'], 1000);
      expect(map['rarity'], 'legendary');
      expect(map['icon_name'], 'trophy');
      expect(map.containsKey('unlocked_at'), isTrue);
    });

    test('toMap omite unlocked_at si es null', () {
      final ach = Achievement.fromMap({
        'id': 'ach-x',
        'name': 'X',
        'description': '',
        'category': 'x',
        'xp_reward': 0,
        'rarity': 'common',
        'icon_name': 'star',
      });

      final map = ach.toMap();
      expect(map.containsKey('unlocked_at'), isFalse);
    });
  });

  group('Achievement equality y hashCode', () {
    test('dos logros con mismo id son iguales', () {
      final a = Achievement.fromMap({
        'id': 'same',
        'name': 'A',
        'description': '',
        'category': 'x',
        'xp_reward': 100,
        'rarity': 'common',
        'icon_name': 'star',
      });
      final b = Achievement.fromMap({
        'id': 'same',
        'name': 'B', // distinto nombre, mismo id
        'description': 'diferente',
        'category': 'y',
        'xp_reward': 999,
        'rarity': 'legendary',
        'icon_name': 'crown',
      });
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('dos logros con distinto id no son iguales', () {
      final a = Achievement.fromMap({
        'id': 'aaa',
        'name': 'X',
        'description': '',
        'category': 'x',
        'xp_reward': 0,
        'rarity': 'common',
        'icon_name': 'star',
      });
      final b = Achievement.fromMap({
        'id': 'bbb',
        'name': 'X',
        'description': '',
        'category': 'x',
        'xp_reward': 0,
        'rarity': 'common',
        'icon_name': 'star',
      });
      expect(a, isNot(equals(b)));
    });
  });
}
