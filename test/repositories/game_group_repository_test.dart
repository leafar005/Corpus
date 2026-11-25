import 'dart:async';

import 'package:corpus/repositories/game_group_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthClient extends Fake implements GoTrueClient {
  _FakeAuthClient(this.user);
  User? user;

  @override
  User? get currentUser => user;
}

class _FakeGroupClient extends Fake implements SupabaseClient {
  _FakeGroupClient(this.auth);

  @override
  final _FakeAuthClient auth;
  final List<String> tablesQueried = [];
  Map<dynamic, dynamic>? lastUpdatePayload;
  List<Map<String, dynamic>> groupsRows = const [];
  List<Map<String, dynamic>> previewGamesRows = const [];
  Map<String, dynamic>? singleGroupRow;

  @override
  SupabaseQueryBuilder from(String table) {
    tablesQueried.add(table);
    return _FakeGroupQueryBuilder(this, table);
  }
}

class _FakeGroupQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeGroupQueryBuilder(this._client, this._table);

  final _FakeGroupClient _client;
  final String _table;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    final rows = switch (_table) {
      'game_groups' => _client.groupsRows,
      'games' => _client.previewGamesRows,
      _ => const <Map<String, dynamic>>[],
    };
    return _FakeFilterBuilder<PostgrestList>(
      () async => List<PostgrestMap>.from(rows),
      singleValue: () async =>
          _client.singleGroupRow ??
          (_client.groupsRows.isNotEmpty ? _client.groupsRows.first : <String, dynamic>{}),
    );
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map<dynamic, dynamic> values) {
    _client.lastUpdatePayload = Map<dynamic, dynamic>.from(values);
    return _FakeFilterBuilder<dynamic>(
      () async => const [],
      singleValue: () async =>
          _client.singleGroupRow ?? <String, dynamic>{'id': 'g1', 'user_id': 'u-1', 'name': 'G'},
    );
  }
}

class _FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._execute, {this.singleValue});

  final Future<T> Function() _execute;
  final Future<PostgrestMap> Function()? singleValue;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List<dynamic> values) =>
      this;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      this;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder<PostgrestList>(
        () async => const <PostgrestMap>[],
        singleValue: singleValue,
      );

  @override
  PostgrestTransformBuilder<PostgrestMap> single() =>
      _FakeSingleBuilder(singleValue ?? () async => <String, dynamic>{});

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap> {
  _FakeSingleBuilder(this._execute);

  final Future<PostgrestMap> Function() _execute;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

User _makeUser() => const User(
  id: 'u-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2025-01-01T00:00:00Z',
);

void main() {
  test('updateGroup con actualizaciones vacías no hace UPDATE y clearCover limpia cover_game_id (BUG-115)', () async {
    final client = _FakeGroupClient(_FakeAuthClient(_makeUser()))
      ..singleGroupRow = {
        'id': 'g-1',
        'user_id': 'u-1',
        'name': 'RPGs',
        'cover_game_id': 42,
      };
    final repo = GameGroupRepository(client: client);

    final unchanged = await repo.updateGroup(groupId: 'g-1');
    expect(client.lastUpdatePayload, isNull);
    expect(unchanged.coverGameId, 42);

    await repo.updateGroup(groupId: 'g-1', clearCover: true);
    expect(client.lastUpdatePayload?.containsKey('cover_game_id'), isTrue);
    expect(client.lastUpdatePayload?['cover_game_id'], isNull);
  });

  test('fetchGroups hidrata solo hasta 4 portadas de vista previa en lote (OPT-07)', () async {
    final client = _FakeGroupClient(_FakeAuthClient(_makeUser()))
      ..groupsRows = [
        {
          'id': 'g-1',
          'user_id': 'u-1',
          'name': 'Favoritos',
          'game_group_items': [
            {'id': 'i1', 'group_id': 'g-1', 'game_id': 1, 'sort_order': 0},
            {'id': 'i2', 'group_id': 'g-1', 'game_id': 2, 'sort_order': 1},
            {'id': 'i3', 'group_id': 'g-1', 'game_id': 3, 'sort_order': 2},
            {'id': 'i4', 'group_id': 'g-1', 'game_id': 4, 'sort_order': 3},
            {'id': 'i5', 'group_id': 'g-1', 'game_id': 5, 'sort_order': 4},
          ],
        },
      ]
      ..previewGamesRows = [
        {'igdb_id': 1, 'title': 'G1', 'cover_url': 'u1'},
        {'igdb_id': 2, 'title': 'G2', 'cover_url': 'u2'},
        {'igdb_id': 3, 'title': 'G3', 'cover_url': 'u3'},
        {'igdb_id': 4, 'title': 'G4', 'cover_url': 'u4'},
      ];
    final repo = GameGroupRepository(client: client);

    final groups = await repo.fetchGroups('u-1');
    expect(groups, hasLength(1));
    expect(groups.first.gameCount, 5);
    expect(groups.first.items, hasLength(4));
    expect(client.tablesQueried, ['game_groups', 'games']);
  });
}
