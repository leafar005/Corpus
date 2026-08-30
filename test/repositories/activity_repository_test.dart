// test/repositories/activity_repository_test.dart
//
// Tests unitarios para el helper estático ActivityRepository.mergeActivityItems.
// Prueba la lógica de enriquecimiento y merge de eventos sin necesitar Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/repositories/activity_repository.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> makeItem({
    required String actionType,
    String userId = 'u1',
    int gameId = 1,
    String? createdAt,
    String? reviewId,
  }) {
    final now = createdAt ?? '2024-06-01T12:00:00';
    return {
      'action_type': actionType,
      'user_id': userId,
      'game_id': gameId,
      'created_at': now,
      'metadata': reviewId != null ? {'review_id': reviewId} : null,
    };
  }

  // ── mergeActivityItems ────────────────────────────────────────────────────

  group('ActivityRepository.mergeActivityItems', () {
    test('inyecta _review en eventos "reviewed" si está en el mapa', () {
      final reviewData = {'id': 'r1', 'rating': 8.0};
      final items = [makeItem(actionType: 'reviewed', reviewId: 'r1')];

      final result = ActivityRepository.mergeActivityItems(
        feedItems: items,
        reviewsById: {'r1': reviewData},
        partnersByUserGame: {},
      );

      expect(result.length, 1);
      expect(result.first['_review'], reviewData);
    });

    test('no inyecta _review si el review_id no está en el mapa', () {
      final items = [makeItem(actionType: 'reviewed', reviewId: 'r_missing')];

      final result = ActivityRepository.mergeActivityItems(
        feedItems: items,
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result.first.containsKey('_review'), isFalse);
    });

    test('inyecta _partners para items con user_id y game_id', () {
      final partnerData = [
        {'id': 'p1', 'username': 'copiloto'},
      ];
      final items = [makeItem(actionType: 'status_change')];

      final result = ActivityRepository.mergeActivityItems(
        feedItems: items,
        reviewsById: {},
        partnersByUserGame: {'u1_1': partnerData},
      );

      expect(result.first['_partners'], partnerData);
    });

    test('no inyecta _partners si no hay entrada en el mapa', () {
      final items = [makeItem(actionType: 'status_change')];

      final result = ActivityRepository.mergeActivityItems(
        feedItems: items,
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result.first['_partners'], isNull);
    });

    // ── Reglas de merge ────────────────────────────────────────────────────

    test(
      'fusiona status_change sobre reviewed del mismo usuario+juego en <24h',
      () {
        // reviewed primero, luego status_change del mismo user+juego en la misma hora
        final reviewed = makeItem(
          actionType: 'reviewed',
          createdAt: '2024-06-01T12:00:00',
          reviewId: 'r1',
        );
        final statusChange = makeItem(
          actionType: 'status_change',
          createdAt: '2024-06-01T13:00:00',
        );
        statusChange['metadata'] = {'status': 'beaten'};

        final result = ActivityRepository.mergeActivityItems(
          feedItems: [reviewed, statusChange],
          reviewsById: {},
          partnersByUserGame: {},
        );

        // Solo debe quedar 1 item fusionado
        expect(result.length, 1);
        // El tipo cambia al del nuevo evento (status_change prevalece)
        expect(result.first['action_type'], 'status_change');
        // Pero el status viene del segundo evento
        expect((result.first['metadata'] as Map)['status'], 'beaten');
      },
    );

    test(
      'fusiona reviewed sobre status_change del mismo usuario+juego en <24h',
      () {
        final statusChange = makeItem(
          actionType: 'status_change',
          createdAt: '2024-06-01T12:00:00',
        );
        final reviewed = makeItem(
          actionType: 'reviewed',
          createdAt: '2024-06-01T13:00:00',
          reviewId: 'r1',
        );

        final reviewData = {'id': 'r1', 'rating': 9.0};
        final result = ActivityRepository.mergeActivityItems(
          feedItems: [statusChange, reviewed],
          reviewsById: {'r1': reviewData},
          partnersByUserGame: {},
        );

        // Solo debe quedar 1 item fusionado
        expect(result.length, 1);
        // El _review se añade al status_change previo
        expect(result.first['_review'], reviewData);
      },
    );

    test('fusiona dos status_change del mismo usuario+juego en <24h', () {
      final sc1 = makeItem(
        actionType: 'status_change',
        createdAt: '2024-06-01T12:00:00',
      );
      final sc2 = makeItem(
        actionType: 'status_change',
        createdAt: '2024-06-01T14:00:00',
      );

      final result = ActivityRepository.mergeActivityItems(
        feedItems: [sc1, sc2],
        reviewsById: {},
        partnersByUserGame: {},
      );

      // Deben quedar solo 1 (el segundo se descarta)
      expect(result.length, 1);
    });

    test('NO fusiona eventos a más de 24 horas de diferencia', () {
      final sc1 = makeItem(
        actionType: 'status_change',
        createdAt: '2024-06-01T12:00:00',
      );
      final sc2 = makeItem(
        actionType: 'status_change',
        createdAt: '2024-06-03T12:00:00', // >24h después
      );

      final result = ActivityRepository.mergeActivityItems(
        feedItems: [sc1, sc2],
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result.length, 2);
    });

    test(
      'NO fusiona eventos de distintos usuarios aunque sean el mismo juego',
      () {
        final sc1 = makeItem(
          actionType: 'status_change',
          userId: 'u1',
          createdAt: '2024-06-01T12:00:00',
        );
        final sc2 = makeItem(
          actionType: 'status_change',
          userId: 'u2',
          createdAt: '2024-06-01T13:00:00',
        );

        final result = ActivityRepository.mergeActivityItems(
          feedItems: [sc1, sc2],
          reviewsById: {},
          partnersByUserGame: {},
        );

        expect(result.length, 2);
      },
    );

    test('NO fusiona eventos del mismo usuario en distintos juegos', () {
      final sc1 = makeItem(
        actionType: 'status_change',
        gameId: 1,
        createdAt: '2024-06-01T12:00:00',
      );
      final sc2 = makeItem(
        actionType: 'status_change',
        gameId: 2,
        createdAt: '2024-06-01T13:00:00',
      );

      final result = ActivityRepository.mergeActivityItems(
        feedItems: [sc1, sc2],
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result.length, 2);
    });

    test('devuelve lista vacía si feedItems está vacío', () {
      final result = ActivityRepository.mergeActivityItems(
        feedItems: [],
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result, isEmpty);
    });

    test('items sin user_id o game_id nunca se fusionan', () {
      final noUser = {
        'action_type': 'status_change',
        'user_id': null,
        'game_id': 1,
        'created_at': '2024-06-01T12:00:00',
        'metadata': null,
      };
      final noGame = {
        'action_type': 'status_change',
        'user_id': 'u1',
        'game_id': null,
        'created_at': '2024-06-01T13:00:00',
        'metadata': null,
      };

      final result = ActivityRepository.mergeActivityItems(
        feedItems: [noUser, noGame],
        reviewsById: {},
        partnersByUserGame: {},
      );

      expect(result.length, 2);
    });

    // ── Escenario integrado ────────────────────────────────────────────────

    test(
      'escenario completo: dos usuarios, múltiples juegos, merge selectivo',
      () {
        final items = [
          // u1 + juego 1: reviewed + status_change en 2h → merge en 1
          makeItem(
            actionType: 'reviewed',
            userId: 'u1',
            gameId: 1,
            createdAt: '2024-06-01T10:00:00',
            reviewId: 'r1',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'u1',
            gameId: 1,
            createdAt: '2024-06-01T12:00:00',
          )..['metadata'] = {'status': 'beaten'},
          // u1 + juego 2: evento independiente
          makeItem(
            actionType: 'status_change',
            userId: 'u1',
            gameId: 2,
            createdAt: '2024-06-01T11:00:00',
          ),
          // u2 + juego 1: evento independiente (diferente usuario)
          makeItem(
            actionType: 'status_change',
            userId: 'u2',
            gameId: 1,
            createdAt: '2024-06-01T11:30:00',
          ),
        ];

        final result = ActivityRepository.mergeActivityItems(
          feedItems: items,
          reviewsById: {
            'r1': {'id': 'r1'},
          },
          partnersByUserGame: {},
        );

        // u1+juego1 → 1 (merge), u1+juego2 → 1, u2+juego1 → 1 = 3 total
        expect(result.length, 3);
      },
    );
  });
  group('ActivityRepository.sortFriendsStrip', () {
    Map<String, dynamic> friend(String id, {int xp = 0}) => {
      'id': id,
      'display_name': id,
      'xp': xp,
    };

    test(
      'reproduce el bug reportado: no-vista entre dos vistas → no-vista debe ir primero',
      () {
        final friends = [friend('seen1'), friend('unseen'), friend('seen2')];
        final stories = {
          'seen1': [
            {'id': 'a1'},
          ],
          'unseen': [
            {'id': 'a2'},
          ],
          'seen2': [
            {'id': 'a3'},
          ],
        };
        final viewed = {'a1', 'a3'}; // a2 (de 'unseen') no está vista

        final result = ActivityRepository.sortFriendsStrip(
          friends: friends,
          userStories: stories,
          onlineUserIds: {},
          viewedStoryIds: viewed,
        );

        expect(result.first['id'], 'unseen');
        expect(
          result.skip(1).map((f) => f['id']),
          containsAll(['seen1', 'seen2']),
        );
      },
    );

    test(
      'historia sin ver > historia vista > jugando sin historia > online sin historia',
      () {
        final friends = [
          {
            'id': 'playing',
            'currently_playing_appid': 1,
            'currently_playing_name': 'X',
          },
          {'id': 'unseen'},
          {'id': 'seen'},
          {'id': 'online'},
        ];
        final stories = {
          'unseen': [
            {'id': 's1'},
          ],
          'seen': [
            {'id': 's2'},
          ],
        };
        final result = ActivityRepository.sortFriendsStrip(
          friends: friends,
          userStories: stories,
          onlineUserIds: {'online'},
          viewedStoryIds: {'s2'},
        );
        expect(result.map((f) => f['id']).toList(), [
          'unseen',
          'seen',
          'playing',
          'online',
        ]);
      },
    );

    test('empate de score se rompe por XP descendente', () {
      final friends = [friend('low', xp: 10), friend('high', xp: 500)];
      final result = ActivityRepository.sortFriendsStrip(
        friends: friends,
        userStories: {},
        onlineUserIds: {},
        viewedStoryIds: {},
      );
      expect(result.map((f) => f['id']).toList(), ['high', 'low']);
    });

    test('empate total se rompe alfabéticamente', () {
      final friends = [friend('Zoe'), friend('Ana')];
      final result = ActivityRepository.sortFriendsStrip(
        friends: friends,
        userStories: {},
        onlineUserIds: {},
        viewedStoryIds: {},
      );
      expect(result.map((f) => f['id']).toList(), ['Ana', 'Zoe']);
    });
  });

  group('ActivityRepository.groupAndMergeByUser', () {
    test(
      'fusiona reviewed+status_change del mismo amigo aunque haya 5 amigos entre medias',
      () {
        final items = <Map<String, dynamic>>[
          makeItem(
            actionType: 'reviewed',
            userId: 'target',
            gameId: 1,
            createdAt: '2024-06-01T18:00:00',
            reviewId: 'r1',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'f1',
            createdAt: '2024-06-01T17:00:00',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'f2',
            createdAt: '2024-06-01T16:00:00',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'f3',
            createdAt: '2024-06-01T15:00:00',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'f4',
            createdAt: '2024-06-01T14:00:00',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'f5',
            createdAt: '2024-06-01T13:00:00',
          ),
          makeItem(
            actionType: 'status_change',
            userId: 'target',
            gameId: 1,
            createdAt: '2024-06-01T12:00:00',
          )..['metadata'] = {'status': 'beaten'},
        ];

        final result = ActivityRepository.groupAndMergeByUser(
          feedItems: items,
          reviewsById: {
            'r1': {'id': 'r1'},
          },
          partnersByUserGame: {},
          maxPerUser: 15,
        );

        // 'target' debe tener 1 sola historia (fusionada), no 2
        expect(result['target']!.length, 1);
      },
    );
  });
}
