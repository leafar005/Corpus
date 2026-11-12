import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/routes/tab_deep_route.dart';

void main() {
  group('parseTabDeepRoute', () {
    test('empty segments returns null', () {
      expect(parseTabDeepRoute([]), isNull);
    });

    // ── Juegos (igdb_id numérico) ────────────────────────────────────────
    test('numeric segment resolves to GameDeepRoute', () {
      final route = parseTabDeepRoute(['12345']);
      expect(route, isA<GameDeepRoute>());
      expect((route as GameDeepRoute).igdbId, 12345);
    });

    test('zero is a valid igdb_id', () {
      final route = parseTabDeepRoute(['0']);
      expect(route, isA<GameDeepRoute>());
      expect((route as GameDeepRoute).igdbId, 0);
    });

    // ── Reseñas ──────────────────────────────────────────────────────────
    test('resena/{id} resolves to ReviewDeepRoute', () {
      final route = parseTabDeepRoute(['resena', 'abc-123']);
      expect(route, isA<ReviewDeepRoute>());
      expect((route as ReviewDeepRoute).reviewId, 'abc-123');
    });

    test('resena without id returns null', () {
      expect(parseTabDeepRoute(['resena']), isNull);
    });

    test('resena with empty id returns null', () {
      expect(parseTabDeepRoute(['resena', '']), isNull);
    });

    // ── Posts agrupados ──────────────────────────────────────────────────
    test('post/{id} resolves to GroupedPostDeepRoute', () {
      final route = parseTabDeepRoute(['post', 'post-123']);
      expect(route, isA<GroupedPostDeepRoute>());
      expect((route as GroupedPostDeepRoute).postId, 'post-123');
    });

    test('post without id returns null', () {
      expect(parseTabDeepRoute(['post']), isNull);
    });

    test('post with empty id returns null', () {
      expect(parseTabDeepRoute(['post', '']), isNull);
    });

    // ── Bundles ──────────────────────────────────────────────────────────
    test('bundle/{id} resolves to BundleDeepRoute', () {
      final route = parseTabDeepRoute(['bundle', 'hb-summer-2026']);
      expect(route, isA<BundleDeepRoute>());
      expect((route as BundleDeepRoute).bundleId, 'hb-summer-2026');
    });

    test('bundle without id returns null', () {
      expect(parseTabDeepRoute(['bundle']), isNull);
    });

    // ── Logros ────────────────────────────────────────────────────────────
    test('logros resolves to AchievementsDeepRoute (own)', () {
      final route = parseTabDeepRoute(['logros']);
      expect(route, isA<AchievementsDeepRoute>());
      expect((route as AchievementsDeepRoute).userId, isNull);
    });

    test('logros/{achievementId} resolves to AchievementGamesDeepRoute', () {
      final route = parseTabDeepRoute(['logros', 'zelda-master']);
      expect(route, isA<AchievementGamesDeepRoute>());
      expect(
        (route as AchievementGamesDeepRoute).achievementId,
        'zelda-master',
      );
    });

    // ── Logros de otro usuario ────────────────────────────────────────────
    const sampleUuid = '3f2a0000-0000-4000-8000-000000000001';

    test('{userId}/logros resolves to AchievementsDeepRoute with userId', () {
      final route = parseTabDeepRoute([sampleUuid, 'logros']);
      expect(route, isA<AchievementsDeepRoute>());
      expect((route as AchievementsDeepRoute).userId, sampleUuid);
    });

    test(
      '{userId}/logros/{achievementId} resolves to AchievementGamesDeepRoute',
      () {
        final route = parseTabDeepRoute([sampleUuid, 'logros', 'zelda-master']);
        expect(route, isA<AchievementGamesDeepRoute>());
        final ach = route as AchievementGamesDeepRoute;
        expect(ach.userId, sampleUuid);
        expect(ach.achievementId, 'zelda-master');
      },
    );

    // ── Amigos y Notificaciones ──────────────────────────────────────────
    test('amigos resolves to FriendsDeepRoute', () {
      expect(parseTabDeepRoute(['amigos']), isA<FriendsDeepRoute>());
    });

    test('notificaciones resolves to NotificationsFeedDeepRoute', () {
      expect(
        parseTabDeepRoute(['notificaciones']),
        isA<NotificationsFeedDeepRoute>(),
      );
    });

    // ── Perfil de usuario (UUID válido) y rechazo de segmentos inválidos ─
    test('valid UUID segment resolves to ProfileDeepRoute', () {
      final route = parseTabDeepRoute([sampleUuid]);
      expect(route, isA<ProfileDeepRoute>());
      expect((route as ProfileDeepRoute).userId, sampleUuid);
    });

    test('non-UUID unknown segment returns null', () {
      expect(parseTabDeepRoute(['unknown-segment']), isNull);
    });
  });

  group('publicPathForTabRoute', () {
    test('tab 0 root path', () {
      expect(publicPathForTabRoute(0, null), '/inicio');
    });

    test('tab 1 root path', () {
      expect(publicPathForTabRoute(1, null), '/buscar');
    });

    test('tab 4 root path', () {
      expect(publicPathForTabRoute(4, null), '/perfil');
    });

    test('game deep route in search tab', () {
      expect(
        publicPathForTabRoute(1, const GameDeepRoute(1942)),
        '/buscar/1942',
      );
    });

    test('review deep route in activity tab', () {
      expect(
        publicPathForTabRoute(2, const ReviewDeepRoute('abc')),
        '/actividad/resena/abc',
      );
    });

    test('profile deep route in profile tab', () {
      expect(
        publicPathForTabRoute(4, const ProfileDeepRoute('user-123')),
        '/perfil/user-123',
      );
    });

    test('achievements with userId', () {
      expect(
        publicPathForTabRoute(4, const AchievementsDeepRoute(userId: 'uid')),
        '/perfil/uid/logros',
      );
    });
  });

  group('TabDeepRoute.toSegments', () {
    test('GameDeepRoute', () {
      expect(const GameDeepRoute(42).toSegments(), ['42']);
    });

    test('ReviewDeepRoute', () {
      expect(const ReviewDeepRoute('r1').toSegments(), ['resena', 'r1']);
    });

    test('GroupedPostDeepRoute', () {
      expect(const GroupedPostDeepRoute('p1').toSegments(), ['post', 'p1']);
    });

    test('BundleDeepRoute', () {
      expect(const BundleDeepRoute('b1').toSegments(), ['bundle', 'b1']);
    });

    test('AchievementsDeepRoute (own)', () {
      expect(const AchievementsDeepRoute().toSegments(), ['logros']);
    });

    test('FriendsDeepRoute', () {
      expect(const FriendsDeepRoute().toSegments(), ['amigos']);
    });

    test('NotificationsFeedDeepRoute', () {
      expect(const NotificationsFeedDeepRoute().toSegments(), [
        'notificaciones',
      ]);
    });
  });

  group('TabDeepRoute equality', () {
    test('GameDeepRoute equality by igdbId', () {
      expect(const GameDeepRoute(1), equals(const GameDeepRoute(1)));
      expect(const GameDeepRoute(1), isNot(equals(const GameDeepRoute(2))));
    });

    test('ReviewDeepRoute equality by reviewId', () {
      expect(const ReviewDeepRoute('a'), equals(const ReviewDeepRoute('a')));
      expect(
        const ReviewDeepRoute('a'),
        isNot(equals(const ReviewDeepRoute('b'))),
      );
    });

    test('FriendsDeepRoute singleton equality', () {
      expect(const FriendsDeepRoute(), equals(const FriendsDeepRoute()));
    });
  });
}
