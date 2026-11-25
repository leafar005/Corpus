import 'dart:async';

import 'package:corpus/repositories/social_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.user);
  User? user;

  @override
  User? get currentUser => user;
}

class _FakeSocialClient extends Fake implements SupabaseClient {
  _FakeSocialClient({
    required this.auth,
    required this.responses,
  });

  @override
  final _FakeAuthClient auth;
  final List<List<Map<String, dynamic>>> responses;
  int _idx = 0;
  int queryCount = 0;

  @override
  SupabaseQueryBuilder from(String table) => _FakeSocialQueryBuilder(this);
}

class _FakeSocialQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeSocialQueryBuilder(this._client);

  final _FakeSocialClient _client;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    _client.queryCount++;
    final rows = _client._idx < _client.responses.length
        ? _client.responses[_client._idx++]
        : const <Map<String, dynamic>>[];
    return _FakeFilterBuilder<PostgrestList>(rows);
  }
}

class _FakeFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._rows);

  final T _rows;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> or(String filters, {String? referencedTable}) =>
      this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) =>
      this;

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future.value(_rows).then(onValue, onError: onError);
}

User _makeUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2025-01-01T00:00:00Z',
);

const _myUuid = '11111111-1111-4111-8111-111111111111';

void main() {
  test('mutaciones sociales lanzan StateError si es invitado (BUG-114)', () async {
    final repo = SocialRepository(
      client: _FakeSocialClient(auth: _FakeAuthClient(null), responses: const []),
    );

    await expectLater(
      () => repo.sendFriendRequest('22222222-2222-4222-8222-222222222222'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      () => repo.removeFriend('22222222-2222-4222-8222-222222222222'),
      throwsA(isA<StateError>()),
    );
  });

  test('fetchFriendsOf ignora filas con join null y fetchSentOrAcceptedIds usa 1 sola consulta (BUG-25, OPT-52)', () async {
    final client = _FakeSocialClient(
      auth: _FakeAuthClient(_makeUser(_myUuid)),
      responses: [
        [
          {'friend': null},
          {
            'friend': {'id': 'f-1', 'username': 'alice'},
          },
        ],
        [
          {
            'friend': {'id': 'f-2', 'username': 'bob'},
          },
        ],
        [
          {
            'requester_id': _myUuid,
            'addressee_id': 'u-pending',
            'status': 'pending',
          },
          {
            'requester_id': 'u-friend',
            'addressee_id': _myUuid,
            'status': 'accepted',
          },
        ],
      ],
    );
    final repo = SocialRepository(client: client);

    final friends = await repo.fetchFriendsOf(_myUuid);
    expect(friends, hasLength(2));

    final before = client.queryCount;
    final ids = await repo.fetchSentOrAcceptedIds();
    expect(client.queryCount - before, 1);
    expect(ids, {'u-pending', 'u-friend'});
  });

  test('fetchFriendshipStatuses resuelve estados en bloque para listas grandes (OPT-02)', () async {
    final client = _FakeSocialClient(
      auth: _FakeAuthClient(_makeUser(_myUuid)),
      responses: [
        [
          {'addressee_id': 'u-2', 'status': 'pending'},
        ],
        [
          {'requester_id': 'u-3', 'status': 'accepted'},
        ],
      ],
    );
    final repo = SocialRepository(client: client);

    final map = await repo.fetchFriendshipStatuses([_myUuid, 'u-2', 'u-3']);
    expect(map.containsKey(_myUuid), isFalse);
    expect(map['u-2'], (status: 'pending', iSent: true));
    expect(map['u-3'], (status: 'accepted', iSent: false));
    expect(client.queryCount, 2);
  });
}
