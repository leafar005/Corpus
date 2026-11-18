import 'dart:async';

import 'package:corpus/models/models.dart';
import 'package:corpus/repositories/game_group_repository.dart';
import 'package:corpus/screens/my_games/game_groups_controller.dart';
import 'package:corpus/utils/safe_change_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGameGroupRepository extends Mock implements GameGroupRepository {}

GameGroup _group(String id, {String name = 'Grupo', int sortOrder = 0}) =>
    GameGroup(
      id: id,
      userId: 'user-1',
      name: name,
      sortOrder: sortOrder,
    );

void main() {
  late MockGameGroupRepository repo;

  setUp(() {
    repo = MockGameGroupRepository();
  });

  group('GameGroupsController', () {
    test('hereda de SafeChangeNotifier', () {
      when(() => repo.fetchGroups('user-1')).thenAnswer((_) async => []);
      final controller = GameGroupsController(
        userId: 'user-1',
        repository: repo,
      );
      addTearDown(controller.dispose);

      expect(controller, isA<SafeChangeNotifier>());
    });

    test('load carga los grupos correctamente y limpia isLoading/hasError', () async {
      final groups = [_group('g1', name: 'Souls'), _group('g2', name: 'Indie')];
      when(() => repo.fetchGroups('user-1')).thenAnswer((_) async => groups);

      final controller = GameGroupsController(
        userId: 'user-1',
        repository: repo,
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.groups, equals(groups));
    });

    test('load marca hasError y errorMessage cuando falla el repositorio', () async {
      when(() => repo.fetchGroups('user-1')).thenThrow(Exception('network error'));

      final controller = GameGroupsController(
        userId: 'user-1',
        repository: repo,
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, isNotNull);
    });

    test(
      'no lanza excepción si se dispone antes de que resuelva load()',
      () async {
        final completer = Completer<List<GameGroup>>();
        when(() => repo.fetchGroups('user-1')).thenAnswer((_) => completer.future);

        final controller = GameGroupsController(
          userId: 'user-1',
          repository: repo,
        );

        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.dispose();
        expect(controller.isDisposed, isTrue);

        completer.complete([_group('g1')]);
        await Future<void>.delayed(Duration.zero);

        expect(notifications, equals(0));
        await controller.load();
        verify(() => repo.fetchGroups('user-1')).called(1);
      },
    );

    test('createGroup y deleteGroup actualizan groups', () async {
      final initial = _group('g1', name: 'Backlog');
      final created = _group('g2', name: 'Favoritos', sortOrder: 1);

      when(() => repo.fetchGroups('user-1')).thenAnswer((_) async => [initial]);
      when(
        () => repo.createGroup(
          userId: 'user-1',
          name: 'Favoritos',
          description: 'Top',
          isRanked: true,
        ),
      ).thenAnswer((_) async => created);
      when(() => repo.deleteGroup('g1')).thenAnswer((_) async {});

      final controller = GameGroupsController(
        userId: 'user-1',
        repository: repo,
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);

      final result = await controller.createGroup(
        name: 'Favoritos',
        description: 'Top',
        isRanked: true,
      );
      expect(result, equals(created));
      expect(controller.groups.map((g) => g.id), equals(['g1', 'g2']));

      final deleted = await controller.deleteGroup('g1');
      expect(deleted, isTrue);
      expect(controller.groups.map((g) => g.id), equals(['g2']));
    });

    test('reorderGroups recarga en silencio si falla la persistencia', () async {
      final g1 = _group('g1', sortOrder: 0);
      final g2 = _group('g2', sortOrder: 1);
      var fetchCount = 0;
      when(() => repo.fetchGroups('user-1')).thenAnswer((_) async {
        fetchCount++;
        return [g1, g2];
      });
      when(() => repo.reorderGroups(any())).thenThrow(Exception('db error'));

      final controller = GameGroupsController(
        userId: 'user-1',
        repository: repo,
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(fetchCount, equals(1));

      await controller.reorderGroups(0, 2);

      expect(fetchCount, equals(2));
      expect(controller.groups.map((g) => g.id), equals(['g1', 'g2']));
    });
  });
}
