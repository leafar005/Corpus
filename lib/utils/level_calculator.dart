import 'dart:math';

class LevelCalculator {
  /// Calcula el nivel de un usuario basado en su experiencia total
  /// Usando la fórmula polinomial: L = floor( (1 + sqrt(1 + XP / 12.5)) / 2 )
  static int getLevel(int xp) {
    if (xp <= 0) return 1;
    final double result = (1 + sqrt(1 + (xp / 12.5))) / 2;
    return result.floor();
  }

  /// Calcula la XP total necesaria para alcanzar un nivel específico
  /// Usando la fórmula: TotalXP(L) = 50 * L * (L - 1)
  static int getXpForLevel(int level) {
    if (level <= 1) return 0;
    return 50 * level * (level - 1);
  }

  /// Calcula la XP requerida para pasar de un nivel actual al siguiente
  /// Usando la fórmula: XP_to_Next(L) = 100 * L
  static int getXpRequiredForNextLevel(int currentLevel) {
    return 100 * currentLevel;
  }

  /// Calcula el progreso actual en el nivel (0.0 a 1.0)
  static double getProgressFraction(int xp) {
    int currentLevel = getLevel(xp);
    int xpBaseForCurrentLevel = getXpForLevel(currentLevel);
    int xpRequiredForNext = getXpRequiredForNextLevel(currentLevel);
    
    int xpIntoCurrentLevel = xp - xpBaseForCurrentLevel;
    
    if (xpRequiredForNext <= 0) return 0.0;
    return (xpIntoCurrentLevel / xpRequiredForNext).clamp(0.0, 1.0);
  }

  /// Formatea la XP a mostrar, e.g. "250 / 600"
  static String getProgressString(int xp) {
    int currentLevel = getLevel(xp);
    int xpBaseForCurrentLevel = getXpForLevel(currentLevel);
    int xpRequiredForNext = getXpRequiredForNextLevel(currentLevel);
    
    int xpIntoCurrentLevel = xp - xpBaseForCurrentLevel;
    return '$xpIntoCurrentLevel / $xpRequiredForNext';
  }
}
