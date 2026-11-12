// test/repositories/activity_repository_test.dart
//
// Tests unitarios para el helper estático ActivityRepository.mergeActivityItems.
// Prueba la lógica de enriquecimiento y merge de eventos sin necesitar Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/repositories/activity_repository.dart';
import 'package:corpus/screens/activity/activity_formatters.dart';

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

  // ── groupActivityItems ────────────────────────────────────────────────────

  group('ActivityRepository.groupActivityItems', () {
    Map<String, dynamic> makeStatusItem({
      required String id,
      String userId = 'u1',
      required int gameId,
      String status = 'to_play',
      required String createdAt,
      String? postId,
      Map<String, dynamic>? postStats,
      String? title,
      Map<String, dynamic>? review,
      List<dynamic>? partners,
    }) {
      return {
        'id': id,
        'action_type': 'status_change',
        'user_id': userId,
        'game_id': gameId,
        if (postId != null) 'post_id': postId,
        if (postStats != null) '_post': postStats,
        'created_at': createdAt,
        'metadata': {'status': status},
        'users': {'id': userId, 'display_name': 'User $userId'},
        'games': {
          'igdb_id': gameId,
          'title': title ?? 'Juego $gameId',
          'cover_url': 'https://example.com/$gameId.jpg',
        },
        if (review != null) '_review': review,
        if (partners != null) '_partners': partners,
      };
    }

    test('1 entrada: no se agrupa y se devuelve intacta', () {
      final single = makeStatusItem(
        id: 'a1',
        gameId: 10,
        postId: 'post-1',
        status: 'to_play',
        createdAt: '2026-11-09T12:00:00Z',
      );

      final result = ActivityRepository.groupActivityItems([single]);

      expect(result.length, 1);
      expect(ActivityRepository.isGroupedActivity(result.first), isFalse);
      expect(result.first['id'], 'a1');
      expect(result.first['game_id'], 10);
      expect(result.first['post_id'], 'post-1');
    });

    test(
      'varias entradas compartiendo post_id se agrupan en un post preservando _post y _games',
      () {
        final statsMap = {
          'post_id': 'post-group-1',
          'likes_count': 4,
          'comments_count': 2,
          'liked_by_me': true,
        };
        final items = [
          makeStatusItem(
            id: 'a5',
            gameId: 5,
            postId: 'post-group-1',
            postStats: statsMap,
            status: 'to_play',
            createdAt: '2026-11-09T12:40:00Z',
            title: 'Juego E',
          ),
          makeStatusItem(
            id: 'a4',
            gameId: 4,
            postId: 'post-group-1',
            postStats: statsMap,
            status: 'to_play',
            createdAt: '2026-11-09T12:30:00Z',
            title: 'Juego D',
          ),
          makeStatusItem(
            id: 'a3',
            gameId: 3,
            postId: 'post-group-1',
            postStats: statsMap,
            status: 'to_play',
            createdAt: '2026-11-09T12:20:00Z',
            title: 'Juego C',
          ),
          makeStatusItem(
            id: 'a2',
            gameId: 2,
            postId: 'post-group-1',
            postStats: statsMap,
            status: 'to_play',
            createdAt: '2026-11-09T12:10:00Z',
            title: 'Juego B',
          ),
          makeStatusItem(
            id: 'a1',
            gameId: 1,
            postId: 'post-group-1',
            postStats: statsMap,
            status: 'to_play',
            createdAt: '2026-11-09T12:00:00Z',
            title: 'Juego A',
          ),
        ];

        final result = ActivityRepository.groupActivityItems(items);

        expect(result.length, 1);
        final group = result.first;
        expect(ActivityRepository.isGroupedActivity(group), isTrue);
        expect(group['post_id'], 'post-group-1');
        expect(group['_post'], statsMap);
        expect(group['created_at'], '2026-11-09T12:40:00Z');
        expect((group['_games'] as List).length, 5);
        expect(ActivityRepository.activityIdsOf(group), [
          'a5',
          'a4',
          'a3',
          'a2',
          'a1',
        ]);
      },
    );

    test('entradas con post_id distintos o null se mantienen separadas', () {
      final items = [
        makeStatusItem(
          id: 'tp2',
          gameId: 2,
          postId: 'post-a',
          status: 'to_play',
          createdAt: '2026-11-09T12:25:00Z',
        ),
        makeStatusItem(
          id: 'tp1',
          gameId: 1,
          postId: 'post-b',
          status: 'to_play',
          createdAt: '2026-11-09T12:20:00Z',
        ),
        makeStatusItem(
          id: 'null1',
          gameId: 3,
          status: 'to_play',
          createdAt: '2026-11-09T12:15:00Z',
        ),
        makeStatusItem(
          id: 'null2',
          gameId: 4,
          status: 'to_play',
          createdAt: '2026-11-09T12:10:00Z',
        ),
      ];

      final result = ActivityRepository.groupActivityItems(items);

      expect(result.length, 4);
      for (final item in result) {
        expect(ActivityRepository.isGroupedActivity(item), isFalse);
      }
    });

    test(
      'agrupa por post_id aunque haya actividad de otros usuarios entre medias y ubica el grupo en la más reciente',
      () {
        final items = [
          makeStatusItem(
            id: 'u1_2',
            userId: 'u1',
            gameId: 2,
            postId: 'post-u1',
            status: 'to_play',
            createdAt: '2026-11-09T14:30:00Z',
          ),
          makeStatusItem(
            id: 'u2_1',
            userId: 'u2',
            gameId: 99,
            postId: 'post-u2',
            status: 'playing',
            createdAt: '2026-11-09T14:15:00Z',
          ),
          makeStatusItem(
            id: 'u1_1',
            userId: 'u1',
            gameId: 1,
            postId: 'post-u1',
            status: 'to_play',
            createdAt: '2026-11-09T14:00:00Z',
          ),
        ];

        final result = ActivityRepository.groupActivityItems(items);

        expect(result.length, 2);
        // Primero el grupo de u1 en la posición de su entrada más reciente (14:30)
        expect(result[0]['user_id'], 'u1');
        expect(ActivityRepository.isGroupedActivity(result[0]), isTrue);
        expect(result[0]['created_at'], '2026-11-09T14:30:00Z');
        expect((result[0]['_games'] as List).length, 2);
        // Después la entrada individual de u2 (14:15)
        expect(result[1]['user_id'], 'u2');
        expect(ActivityRepository.isGroupedActivity(result[1]), isFalse);
      },
    );

    test(
      'paginación y Realtime: rehace la agrupación sobre la lista acumulada sin partir grupos del mismo post_id',
      () {
        // Página 1 termina con 2 juegos del grupo
        final page1 = ActivityRepository.groupActivityItems([
          makeStatusItem(
            id: 'p1_2',
            gameId: 2,
            postId: 'post-paginated',
            status: 'to_play',
            createdAt: '2026-11-09T12:20:00Z',
          ),
          makeStatusItem(
            id: 'p1_1',
            gameId: 1,
            postId: 'post-paginated',
            status: 'to_play',
            createdAt: '2026-11-09T12:10:00Z',
          ),
        ]);
        expect(page1.length, 1);
        expect((page1.first['_games'] as List).length, 2);

        // Página 2 trae 2 juegos más del mismo post_id
        final page2 = ActivityRepository.groupActivityItems([
          makeStatusItem(
            id: 'p2_2',
            gameId: 4,
            postId: 'post-paginated',
            status: 'to_play',
            createdAt: '2026-11-09T12:00:00Z',
          ),
          makeStatusItem(
            id: 'p2_1',
            gameId: 3,
            postId: 'post-paginated',
            status: 'to_play',
            createdAt: '2026-11-09T11:50:00Z',
          ),
        ]);

        // Al acumular página 1 + página 2 y reagrupar, queda 1 solo grupo de 4
        final accumulated = ActivityRepository.groupActivityItems([
          ...page1,
          ...page2,
        ]);
        expect(accumulated.length, 1);
        expect((accumulated.first['_games'] as List).length, 4);

        // Llega una nueva entrada por Realtime con el mismo post_id a las 12:35
        final realtimeNew = makeStatusItem(
          id: 'rt_1',
          gameId: 5,
          postId: 'post-paginated',
          status: 'to_play',
          createdAt: '2026-11-09T12:35:00Z',
        );
        final afterRealtime = ActivityRepository.groupActivityItems([
          realtimeNew,
          ...accumulated,
        ]);
        expect(afterRealtime.length, 1);
        expect((afterRealtime.first['_games'] as List).length, 5);
        expect(afterRealtime.first['created_at'], '2026-11-09T12:35:00Z');
      },
    );

    test(
      'historias (stories): un grupo cuenta como no visto hasta que todos sus activity_ids están en viewedIds',
      () {
        final group = ActivityRepository.groupActivityItems([
          makeStatusItem(
            id: 's2',
            gameId: 2,
            postId: 'post-story',
            status: 'to_play',
            createdAt: '2026-11-09T12:10:00Z',
          ),
          makeStatusItem(
            id: 's1',
            gameId: 1,
            postId: 'post-story',
            status: 'to_play',
            createdAt: '2026-11-09T12:00:00Z',
          ),
        ]);

        expect(group.length, 1);
        // Ninguno visto -> unseen
        expect(ActivityRepository.groupHasUnseenStory(group, {}), isTrue);
        // Solo uno visto -> sigue unseen (ej: entró un juego nuevo al grupo)
        expect(ActivityRepository.groupHasUnseenStory(group, {'s1'}), isTrue);
        // Todos los IDs del grupo vistos -> seen
        expect(
          ActivityRepository.groupHasUnseenStory(group, {'s1', 's2'}),
          isFalse,
        );
      },
    );

    test(
      'mergeActivityItems conserva post_id más reciente y registra _merged_post_ids/_merged_posts',
      () {
        final newer = makeStatusItem(
          id: 'sc-new',
          gameId: 100,
          postId: 'post-beaten',
          postStats: {
            'post_id': 'post-beaten',
            'likes_count': 1,
            'comments_count': 0,
            'liked_by_me': false,
          },
          status: 'beaten',
          createdAt: '2026-11-10T18:00:00Z',
        );
        final older = makeStatusItem(
          id: 'sc-old',
          gameId: 100,
          postId: 'post-playing',
          postStats: {
            'post_id': 'post-playing',
            'likes_count': 2,
            'comments_count': 3,
            'liked_by_me': false,
          },
          status: 'playing',
          createdAt: '2026-11-10T10:00:00Z',
        );

        final merged = ActivityRepository.mergeActivityItems(
          feedItems: [newer, older],
          reviewsById: const {},
          partnersByUserGame: const {},
        );

        expect(merged.length, 1);
        expect(merged.first['post_id'], 'post-beaten');
        expect(merged.first['_merged_post_ids'], ['post-playing']);
        final mergedPosts = merged.first['_merged_posts'] as List;
        expect(mergedPosts.length, 1);
        expect(mergedPosts.first.postId, 'post-playing');
        expect(mergedPosts.first.commentsCount, 3);
      },
    );

    test('formateo de cabecera de grupo: máx 3 títulos y "y N más"', () {
      expect(
        ActivityFormatters.groupedActionText('to_play', isOwnActivity: false),
        'ha añadido a "Por jugar":',
      );
      expect(
        ActivityFormatters.formatGroupedGameTitles(['Juego A', 'Juego B']),
        'Juego A y Juego B',
      );
      expect(
        ActivityFormatters.formatGroupedGameTitles([
          'Juego A',
          'Juego B',
          'Juego C',
        ]),
        'Juego A, Juego B y Juego C',
      );
      expect(
        ActivityFormatters.formatGroupedGameTitles([
          'Juego A',
          'Juego B',
          'Juego C',
          'Juego D',
          'Juego E',
          'Juego F',
          'Juego G',
        ]),
        'Juego A, Juego B, Juego C y 4 más',
      );
    });
  });
}
