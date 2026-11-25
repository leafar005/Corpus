import 'dart:async';

import 'package:corpus/repositories/collection_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.user);
  User? user;

  @override
  User? get currentUser => user;
}

class _FakeCollectionClient extends Fake implements SupabaseClient {
  _FakeCollectionClient(this.auth);

  @override
  final _FakeAuthClient auth;
  int upsertCount = 0;
  int deleteCount = 0;
  List<String> initialPlatforms = const [];
  List<Object>? lastDeletedPlatforms;

  @override
  SupabaseQueryBuilder from(String table) =>
      _FakeCollectionQueryBuilder(this, table);
}

class _FakeCollectionQueryBuilder extends Fake
    implements SupabaseQueryBuilder {
  _FakeCollectionQueryBuilder(this._client, this._table);

  final _FakeCollectionClient _client;
  final String _table;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder<PostgrestList>(
        _client,
        () async => [
          for (final p in _client.initialPlatforms) {'platform_name': p},
        ],
      );

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    if (_table == 'user_game_platforms') _client.upsertCount++;
    return _FakeFilterBuilder<dynamic>(_client, () async => const []);
  }

  @override
  PostgrestFilterBuilder<dynamic> delete() {
    if (_table == 'user_game_platforms') _client.deleteCount++;
    return _FakeFilterBuilder<dynamic>(_client, () async => const []);
  }
}

class _FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._client, this._execute);

  final _FakeCollectionClient _client;
  final Future<T> Function() _execute;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) {
    if (column == 'platform_name') {
      _client.lastDeletedPlatforms = List<Object>.from(values);
    }
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

void main() {
  test('rechaza mutaciones de invitado o sesión ajena (BUG-114)', () async {
    final repo = CollectionRepository(
      client: _FakeCollectionClient(_FakeAuthClient(null)),
    );
    await expectLater(
      () => repo.setPlatformsForGame(
        userId: 'u-1',
        gameId: 10,
        selectedPlatforms: const ['pc'],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('setPlatformsForGame aplica altas y bajas en lote sin bucle N+1 (OPT-10)', () async {
    final client = _FakeCollectionClient(
      _FakeAuthClient(
        const User(
          id: 'u-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2025-01-01T00:00:00Z',
        ),
      ),
    )..initialPlatforms = ['ps4', 'ps5', 'xbox'];

    final repo = CollectionRepository(client: client);
    await repo.setPlatformsForGame(
      userId: 'u-1',
      gameId: 99,
      selectedPlatforms: const ['pc', 'switch', 'ps5'],
      currentOwnedPlatforms: const ['ps4', 'ps5', 'xbox'],
    );

    expect(client.upsertCount, 1);
    expect(client.deleteCount, 1);
    expect(client.lastDeletedPlatforms?.toSet(), {'ps4', 'xbox'});
  });
}
