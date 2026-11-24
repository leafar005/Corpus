import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/services/user_settings_service.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.user);

  User? user;

  @override
  User? get currentUser => user;
}

class _FakeSettingsSupabaseClient extends Fake implements SupabaseClient {
  _FakeSettingsSupabaseClient({
    required this._authClient,
    required this.onUpsert,
    this.remoteRow,
  });

  final _FakeAuthClient _authClient;
  final Future<void> Function(Map<String, dynamic> payload) onUpsert;
  Map<String, dynamic>? remoteRow;

  @override
  GoTrueClient get auth => _authClient;

  @override
  SupabaseQueryBuilder from(String table) =>
      _FakeSettingsQueryBuilder(this);
}

class _FakeSettingsQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeSettingsQueryBuilder(this._client);

  final _FakeSettingsSupabaseClient _client;

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    final map = Map<String, dynamic>.from(values as Map);
    return _FakeFilterBuilder<dynamic>(() async {
      await _client.onUpsert(map);
      return [map];
    });
  }

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return _FakeFilterBuilder<PostgrestList>(() async {
      final row = _client.remoteRow;
      return row == null ? <PostgrestMap>[] : <PostgrestMap>[row];
    }, singleRow: _client.remoteRow);
  }
}

class _FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._execute, {this.singleRow});

  final Future<T> Function() _execute;
  final Map<String, dynamic>? singleRow;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    return _FakeTransformBuilder<PostgrestMap?>(() async => singleRow);
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
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _execute().asStream();
}

class _FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  _FakeTransformBuilder(this._execute);

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
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<T> asStream() => _execute().asStream();
}

User _makeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2025-01-01T00:00:00.000Z',
);

void main() {
  final service = UserSettingsService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.resetForTesting();
  });

  tearDown(() {
    service.resetForTesting();
  });

  group('UserSettingsService sincronización y carreras (BUG-05, BUG-34, BUG-35)', () {
    test('serializa _flush y conserva valores editados mientras otro upsert está en vuelo', () async {
      final firstUpsertStarted = Completer<void>();
      final allowFirstUpsertFinish = Completer<void>();
      final upserts = <Map<String, dynamic>>[];

      final auth = _FakeAuthClient(_makeUser('u-1'));
      final client = _FakeSettingsSupabaseClient(
        authClient: auth,
        onUpsert: (payload) async {
          upserts.add(payload);
          if (upserts.length == 1) {
            firstUpsertStarted.complete();
            await allowFirstUpsertFinish.future;
          }
        },
      );
      service.setClientForTesting(client);

      service.push({'theme_mode': 'dark'});
      final firstFlush = service.flushNow();
      await firstUpsertStarted.future;

      // Mientras el primer upsert está en vuelo, el usuario cambia a 'light'
      service.push({'theme_mode': 'light'});
      expect(service.pendingSnapshotForTesting['theme_mode'], 'light');

      allowFirstUpsertFinish.complete();
      final ok = await firstFlush;

      expect(ok, isTrue);
      expect(upserts.length, 2);
      expect(upserts[0]['theme_mode'], 'dark');
      expect(upserts[1]['theme_mode'], 'light');
      expect(service.pendingSnapshotForTesting, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_settings_dirty'), isFalse);
      expect(prefs.getString('user_settings_pending_json'), isNull);
    });

    test('preserva _pending en memoria si userId es null transitoriamente', () async {
      final auth = _FakeAuthClient(_makeUser('u-1'));
      final client = _FakeSettingsSupabaseClient(
        authClient: auth,
        onUpsert: (_) async {},
      );
      service.setClientForTesting(client);

      service.push({'mobile_grid_columns': 4});
      auth.user = null;

      final ok = await service.flushNow();

      expect(ok, isFalse);
      expect(service.pendingSnapshotForTesting['mobile_grid_columns'], 4);
    });

    test('pullAndApplyToLocalCache sube cambios offline persistidos en user_settings_pending_json antes de aplicar remoto', () async {
      SharedPreferences.setMockInitialValues({
        'user_settings_dirty': true,
        'user_settings_pending_json': jsonEncode({
          'mobile_grid_columns': 5,
        }),
        'mobile_grid_columns': 5,
      });

      final upserted = <Map<String, dynamic>>[];
      final auth = _FakeAuthClient(_makeUser('u-1'));
      final client = _FakeSettingsSupabaseClient(
        authClient: auth,
        remoteRow: {'user_id': 'u-1', 'mobile_grid_columns': 5, 'theme_mode': 'dark'},
        onUpsert: (payload) async => upserted.add(payload),
      );
      service.setClientForTesting(client);

      await service.pullAndApplyToLocalCache();

      expect(upserted, hasLength(1));
      expect(upserted.single['mobile_grid_columns'], 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_settings_dirty'), isFalse);
      expect(prefs.getString('user_settings_pending_json'), isNull);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('resetLocalCacheToDefaults limpia _pending, dirty y caché local en logout', () async {
      final auth = _FakeAuthClient(_makeUser('u-1'));
      final client = _FakeSettingsSupabaseClient(
        authClient: auth,
        onUpsert: (_) async {},
      );
      service.setClientForTesting(client);

      service.push({'theme_mode': 'dark'});
      await service.resetLocalCacheToDefaults();

      expect(service.pendingSnapshotForTesting, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_settings_dirty'), isFalse);
      expect(prefs.getString('user_settings_pending_json'), isNull);
    });
  });
}
