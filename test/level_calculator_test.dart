import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/level_calculator.dart';

void main() {
  group('LevelCalculator Gamification Logic', () {
    test('getLevel calcula el nivel correctamente usando la fórmula polinomial', () {
      expect(LevelCalculator.getLevel(0), 1);
      expect(LevelCalculator.getLevel(-50), 1);
      expect(LevelCalculator.getLevel(50), 1); // 50 XP está en Nivel 1
      expect(LevelCalculator.getLevel(100), 2); // 100 XP es exactamente Nivel 2
      expect(LevelCalculator.getLevel(299), 2);
      expect(LevelCalculator.getLevel(300), 3); // 300 XP es Nivel 3
    });

    test('getXpForLevel calcula la XP base necesaria para cada nivel', () {
      expect(LevelCalculator.getXpForLevel(1), 0);
      expect(LevelCalculator.getXpForLevel(2), 100);
      expect(LevelCalculator.getXpForLevel(3), 300);
      expect(LevelCalculator.getXpForLevel(4), 600);
    });

    test('getXpRequiredForNextLevel calcula la XP para el siguiente nivel', () {
      expect(LevelCalculator.getXpRequiredForNextLevel(1), 100);
      expect(LevelCalculator.getXpRequiredForNextLevel(2), 200);
      expect(LevelCalculator.getXpRequiredForNextLevel(3), 300);
    });

    test('getProgressFraction calcula la fracción de progreso en el nivel actual', () {
      expect(LevelCalculator.getProgressFraction(0), 0.0);
      expect(LevelCalculator.getProgressFraction(50), 0.5); // 50 de 100 XP en Nivel 1
      expect(LevelCalculator.getProgressFraction(100), 0.0); // Recién llegado al Nivel 2 (0 de 200 XP)
      expect(LevelCalculator.getProgressFraction(200), 0.5); // 100 de 200 XP en Nivel 2
    });

    test('getProgressString formatea el texto de progreso correctamente', () {
      expect(LevelCalculator.getProgressString(50), '50 / 100');
      expect(LevelCalculator.getProgressString(100), '0 / 200');
      expect(LevelCalculator.getProgressString(200), '100 / 200');
    });
  });
}
