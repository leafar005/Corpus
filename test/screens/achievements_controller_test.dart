import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/screens/profile/achievements/achievements_controller.dart';

void main() {
  group('AchievementsController - calculateSagaProgress', () {
    test('Ignores games that are not beaten or completed', () {
      final beatenList = [
        {
          'status': 'playing',
          'games': {'id': 1, 'title': 'Super Mario', 'category': 0},
        },
      ];

      final progress = AchievementsController.calculateSagaProgress(
        beatenList,
        [],
      );

      expect(progress['nintendo'], null);
    });

    test('Properly increments nintendo when title contains mario', () {
      final beatenList = [
        {
          'status': 'beaten',
          'games': {'id': 1, 'title': 'Super Mario Galaxy', 'category': 0},
        },
      ];

      final progress = AchievementsController.calculateSagaProgress(
        beatenList,
        [],
      );

      expect(progress['nintendo'], 1);
      expect(progress['mario'], 1);
    });
  });
}
