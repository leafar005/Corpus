import 'dart:async';

import 'package:corpus/repositories/activity_repository.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/deep_route_resolver.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/routes/tab_url_sync.dart';
import 'package:corpus/services/deep_link_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

class _FakeAchievementsDbClient extends Fake implements SupabaseClient {
  _FakeAchievementsDbClient(this.rows);

  final List<Map<String, dynamic>> rows;
  String? lastLikePattern;

  @override
  GoTrueClient get auth => _FakeAuthClient();

  @override
  SupabaseQueryBuilder from(String table) => _FakeQueryBuilder(this);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._client);

  final _FakeAchievementsDbClient _client;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder(_client);
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder(this._client);

  final _FakeAchievementsDbClient _client;

  @override
  PostgrestFilterBuilder<PostgrestList> like(String column, String pattern) {
    _client.lastLikePattern = pattern;
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) => this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => Future.value(_client.rows).then(onValue, onError: onError);
}

class _ThrowingActivityRepo extends ActivityRepository {
  _ThrowingActivityRepo() : super(client: _FakeAchievementsDbClient(const []));

  @override
  Future<String?> resolvePostIdForReview(
    String reviewId, {
    bool create = true,
  }) async {
    throw StateError('network error');
  }
}

class _PushRecorder extends NavigatorObserver {
  _PushRecorder(this.pushedRoutes);

  final List<String?> pushedRoutes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
  }
}

void main() {
  tearDown(() {
    DeepLinkService.clearPendingForTesting();
    resetPushDebounceForTesting();
    kDisablePushDebounceForTests = false;
  });

  group('DeepRouteResolver.fetchAchievementGamesArgs (BUG-19)', () {
    test(
      'preserva IDs multi-palabra, lee saga_target y reenvía userId',
      () async {
        final fakeDb = _FakeAchievementsDbClient([
          {
            'id': 'dark_souls_1',
            'name': 'Alma Oscura (Dark Souls 1)',
            'description': 'Completa 1 juego',
            'xp_reward': 25,
            'saga_target': 1,
          },
          {
            'id': 'dark_souls_all',
            'name': 'Maestro de Lordran',
            'description': 'Completa todos',
            'xp_reward': 100,
            'saga_target': 3,
          },
          // Fila de prefijo distinto que NO debe mezclarse
          {
            'id': 'dark_souls_spin_1',
            'name': 'Otro grupo',
            'description': 'Ignorar',
            'xp_reward': 10,
            'saga_target': 1,
          },
        ]);

        final args = await DeepRouteResolver.fetchAchievementGamesArgs(
          'dark_souls_3',
          'friend-user-42',
          client: fakeDb,
        );

        expect(fakeDb.lastLikePattern, 'dark\\_souls%');
        expect(args, isNotNull);
        expect(args!.achievementId, 'dark_souls');
        expect(args.userId, 'friend-user-42');
        expect(args.franchiseId, 1124);
        expect(args.collectionId, 543);
        expect(args.milestones.map((m) => m['target']).toList(), [1, 3]);
      },
    );
  });

  group('CorpusRouter, TabUrlSync y AppRoutes (BUG-103, MICRO-04)', () {
    test('normaliza /bundles/{id} y corrige hashCode de rutas singleton', () {
      expect(AppRoutes.subSegmentsFromPublicPath('/bundles/hb-2026'), [
        'bundle',
        'hb-2026',
      ]);
      expect(
        parseTabDeepRoute(AppRoutes.subSegmentsFromPublicPath('/bundles/hb-2026')),
        const BundleDeepRoute('hb-2026'),
      );
      expect(
        const FriendsDeepRoute().hashCode,
        isNot(equals(const NotificationsFeedDeepRoute().hashCode)),
      );
    });

    test('TabUrlSync descarta IDs vacíos y tolera Supabase sin inicializar', () {
      expect(
        deepRouteFromRouteSettings(
          const RouteSettings(
            name: AppRoutes.reviewDetails,
            arguments: {'invalid': true},
          ),
        ),
        isNull,
      );
      expect(
        deepRouteFromRouteSettings(
          const RouteSettings(
            name: AppRoutes.groupedPostDetails,
            arguments: GroupedPostDetailsArgs(postId: '   '),
          ),
        ),
        isNull,
      );
      expect(
        deepRouteFromRouteSettings(
          const RouteSettings(
            name: AppRoutes.profile,
            arguments: ProfileArgs(userId: 'user-99'),
          ),
        ),
        const ProfileDeepRoute('user-99'),
      );
    });

    testWidgets(
      'CorpusRouter devuelve ruta controlada ante argumentos inválidos y debounce acotado por ruta',
      (tester) async {
        final route = CorpusRouter.route<void>(
          const RouteSettings(name: AppRoutes.gameDetails, arguments: 'bad'),
        );
        expect(route, isA<MaterialPageRoute<void>>());

        kDisablePushDebounceForTests = false;
        resetPushDebounceForTesting();

        final pushedRoutes = <String?>[];
        final observer = _PushRecorder(pushedRoutes);
        late BuildContext capturedCtx;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: Builder(
              builder: (ctx) {
                capturedCtx = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        pushedRoutes.clear();

        // Misma ruta dos veces seguidas: el segundo push queda frenado por el debounce.
        unawaited(capturedCtx.pushRoute<void>(AppRoutes.gameDetails));
        unawaited(capturedCtx.pushRoute<void>(AppRoutes.gameDetails));
        // Otra ruta distinta en el mismo instante NO queda bloqueada.
        unawaited(capturedCtx.pushRoute<void>(AppRoutes.bundleDetails));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(pushedRoutes, [AppRoutes.gameDetails, AppRoutes.bundleDetails]);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('DeepLinkService y AppNavigationController (BUG-20, BUG-40)', () {
    test('tolera game_id entero y fallos de resolvePostIdForReview', () async {
      final gameRoute = await DeepLinkService.resolveNotificationRoute({
        'type': 'friend_activity',
        'game_id': 1942,
      });
      expect(gameRoute, const GameDeepRoute(1942));

      final reviewRoute = await DeepLinkService.resolveNotificationRoute(
        {
          'type': 'reply_to_comment',
          'review_id': 'rev-1',
          'post_id': 'post-1',
        },
        activityRepo: _ThrowingActivityRepo(),
      );
      expect(reviewRoute, const ReviewDeepRoute('rev-1'));
      final typed = reviewRoute as ReviewDeepRoute;
      expect(typed.postId, 'post-1');
      expect(typed.focusComment, isTrue);

      await DeepLinkService.handle({
        'type': 'new_bundle',
        'bundle_title': 'Indie Gem',
      });
      expect(DeepLinkService.pendingTab.value, 1);
    });

    testWidgets(
      'popstate respeta PopScope(canPop: false) sin truncar prematuramente la pila',
      (tester) async {
        final navKey = GlobalKey<NavigatorState>();
        final tabKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
        tabKeys[0] = navKey;

        final ctrl = AppNavigationController.instance;
        ctrl.resetForSessionChange();
        ctrl.registerTabNavigatorKeys(tabKeys);

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              key: navKey,
              observers: [TabUrlSyncObserver(0)],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.tabHome),
                builder: (_) => const SizedBox(),
              ),
            ),
          ),
        );

        navKey.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.search),
            builder: (_) => const PopScope<void>(
              canPop: false,
              child: SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(ctrl.framesFor(0), hasLength(2));

        // handleBrowserPopState hacia depth 0 debe quedar intacto si canPop == false
        await ctrl.handleBrowserPopState(
          {'tab': 0, 'depth': 0, 'token': ctrl.framesFor(0).first.token},
          '/inicio',
        );
        await tester.pumpAndSettle();
        expect(ctrl.framesFor(0), hasLength(2));
        ctrl.resetForSessionChange();
      },
    );
  });
}
