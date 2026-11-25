import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/screens/main/main_screen_controller.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;
}

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {
  _FakeRealtimeChannel(this.name);

  final String name;
  int subscribeCalls = 0;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload payload) callback,
  }) => this;

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    subscribeCalls++;
    return this;
  }
}

class _FakeMainSupabaseClient extends Fake implements SupabaseClient {
  _FakeMainSupabaseClient({
    required this.authClient,
    this.friendRequestsGate,
    this.activitySummaryGate,
    this.notificationsCountGate,
  });

  final _FakeAuthClient authClient;
  final Completer<List<Map<String, dynamic>>>? friendRequestsGate;
  final Completer<Map<String, dynamic>>? activitySummaryGate;
  final Completer<int>? notificationsCountGate;

  final List<_FakeRealtimeChannel> createdChannels = [];
  final List<RealtimeChannel> removedChannels = [];

  @override
  GoTrueClient get auth => authClient;

  @override
  RealtimeChannel channel(
    String topic, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final ch = _FakeRealtimeChannel(topic);
    createdChannels.add(ch);
    return ch;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removedChannels.add(channel);
    return 'ok';
  }

  @override
  SupabaseQueryBuilder from(String table) => _FakeMainQueryBuilder(this);

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    if (fn == 'get_unread_activity_summary') {
      return _FakeMainFilterBuilder<T>(
        () async {
          if (activitySummaryGate != null) {
            return (await activitySummaryGate!.future) as T;
          }
          return {'unread_count': 0} as T;
        },
        singleOverride: () async {
          if (activitySummaryGate != null) {
            return await activitySummaryGate!.future;
          }
          return {'unread_count': 0};
        },
      );
    }
    return _FakeMainFilterBuilder<T>(() async {
      if (notificationsCountGate != null) {
        return (await notificationsCountGate!.future) as T;
      }
      return 0 as T;
    });
  }
}

class _FakeMainQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeMainQueryBuilder(this._client);

  final _FakeMainSupabaseClient _client;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return _FakeMainFilterBuilder<PostgrestList>(() async {
      if (_client.friendRequestsGate != null) {
        return await _client.friendRequestsGate!.future;
      }
      return const <Map<String, dynamic>>[];
    });
  }
}

class _FakeMainFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _FakeMainFilterBuilder(this._execute, {this.singleOverride});

  final Future<T> Function() _execute;
  final Future<PostgrestMap> Function()? singleOverride;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> count([
    CountOption option = CountOption.exact,
  ]) {
    return _FakeMainResponseBuilder<T>(() async {
      final data = await _execute();
      final count = data is List ? data.length : 0;
      return PostgrestResponse<T>(data: data, count: count);
    });
  }

  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    return _FakeMainTransformBuilder<PostgrestMap>(
      singleOverride ?? () async => (await _execute()) as PostgrestMap,
    );
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _execute().catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);

  @override
  Stream<T> asStream() => _execute().asStream();
}

class _FakeMainTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  _FakeMainTransformBuilder(this._execute);

  final Future<T> Function() _execute;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _execute().catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);

  @override
  Stream<T> asStream() => _execute().asStream();
}

class _FakeMainResponseBuilder<T> extends Fake
    implements ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> {
  _FakeMainResponseBuilder(this._execute);

  final Future<PostgrestResponse<T>> Function() _execute;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestResponse<T> value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<PostgrestResponse<T>> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _execute().catchError(onError, test: test);

  @override
  Future<PostgrestResponse<T>> whenComplete(
    FutureOr<void> Function() action,
  ) => _execute().whenComplete(action);

  @override
  Stream<PostgrestResponse<T>> asStream() => _execute().asStream();
}

User _makeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2025-01-01T00:00:00.000Z',
);

void main() {
  setUp(() {
    unreadActivityCount.value = 0;
    unreadFriendRequestsCount.value = 0;
    unreadNotificationsCount.value = 0;
  });

  group('MainScreenController lifecycle & channels (BUG-81)', () {
    test('init crea canales por userId y dispose llama removeChannel en todos', () {
      final client = _FakeMainSupabaseClient(
        authClient: _FakeAuthClient(_makeUser('user-abc')),
      );
      final controller = MainScreenController(
        isOnActivityTab: () => false,
        client: client,
      );

      controller.init();

      expect(
        client.createdChannels.map((c) => c.name),
        containsAll([
          'pending_friend_requests:user-abc',
          'main_activity_feed_badge:user-abc',
          'unread_notifications_badge:user-abc',
        ]),
      );

      controller.dispose();

      expect(client.removedChannels.length, 3);
      expect(
        client.removedChannels,
        containsAll(client.createdChannels),
      );
    });

    test('ignora respuestas tardías si dispose() se llamó mientras estaban en vuelo', () async {
      final friendGate = Completer<List<Map<String, dynamic>>>();
      final activityGate = Completer<Map<String, dynamic>>();
      final notifGate = Completer<int>();

      final client = _FakeMainSupabaseClient(
        authClient: _FakeAuthClient(_makeUser('user-abc')),
        friendRequestsGate: friendGate,
        activitySummaryGate: activityGate,
        notificationsCountGate: notifGate,
      );
      final controller = MainScreenController(
        isOnActivityTab: () => false,
        client: client,
      );

      final badgesFuture = controller.fetchInitialBadges();
      final notifFuture = controller.fetchNotificationsCount();

      controller.dispose();

      friendGate.complete([
        {'requester_id': 'r1'},
        {'requester_id': 'r2'},
      ]);
      activityGate.complete({'unread_count': 9});
      notifGate.complete(4);

      await Future.wait([badgesFuture, notifFuture]);

      expect(unreadFriendRequestsCount.value, 0);
      expect(unreadActivityCount.value, 0);
      expect(unreadNotificationsCount.value, 0);
    });
  });
}
