import 'dart:async';

import 'package:corpus/repositories/achievements_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAchievementsClient extends Fake implements SupabaseClient {
  _FakeAchievementsClient({
    required this.tableRows,
    this.singleRowByTable = const {},
  });

  final Map<String, List<Map<String, dynamic>>> tableRows;
  final Map<String, Map<String, dynamic>?> singleRowByTable;
  final List<String> queriedTables = [];

  @override
  SupabaseQueryBuilder from(String table) {
    queriedTables.add(table);
    return _FakeAchievementsQueryBuilder(
      table: table,
      rows: tableRows[table] ?? const [],
      singleRow: singleRowByTable[table],
    );
  }
}

class _FakeAchievementsQueryBuilder extends Fake
    implements SupabaseQueryBuilder {
  _FakeAchievementsQueryBuilder({
    required this.table,
    required this.rows,
    required this.singleRow,
  });

  final String table;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? singleRow;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder(rows: rows, singleRow: singleRow);
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder({required this.rows, required this.singleRow});

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? singleRow;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

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
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeTransformBuilder(() async => singleRow);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => Future.value(rows).then(onValue, onError: onError);
}

class _FakeTransformBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  _FakeTransformBuilder(this._execute);

  final Future<PostgrestMap?> Function() _execute;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);
}

void main() {
  test('invitados con userId vacío solo cargan definiciones globales (BUG-114)', () async {
    final client = _FakeAchievementsClient(
      tableRows: {
        'achievements': [
          {'id': 'a1', 'xp_reward': 50},
        ],
      },
    );
    final repo = AchievementsRepository(client: client);

    final data = await repo.fetchAll('   ');
    expect(data.xp, 0);
    expect(data.achievements, hasLength(1));
    expect(data.unlocked, isEmpty);
    expect(client.queriedTables, ['achievements']);
  });

  test('tolera fechas unlocked_at corruptas sin lanzar FormatException (BUG-26)', () async {
    final client = _FakeAchievementsClient(
      tableRows: {
        'achievements': [
          {'id': 'a1', 'xp_reward': 50},
          {'id': 'a2', 'xp_reward': 100},
        ],
        'user_achievements': [
          {'achievement_id': 'a1', 'unlocked_at': 'not-a-date'},
          {'achievement_id': 'a2', 'unlocked_at': '2026-01-10T12:00:00Z'},
          {'achievement_id': null, 'unlocked_at': '2026-01-10T12:00:00Z'},
        ],
        'reviews': const [],
        'user_games': const [],
      },
      singleRowByTable: {
        'users': {'xp': '250'},
      },
    );
    final repo = AchievementsRepository(client: client);

    final data = await repo.fetchAll('user-1');
    expect(data.xp, 250);
    expect(data.unlocked.containsKey('a1'), isFalse);
    expect(data.unlocked['a2']?.year, 2026);
    expect(data.unlocked.length, 1);
  });
}
