// lib/utils/achievement_utils.dart

class AchievementUtils {
  static final RegExp _tierSuffixRegex = RegExp(r'_(\d+|all)$');
  static final RegExp _numericSuffixRegex = RegExp(r'_(\d+)$');
  static final RegExp _parenSuffixRegex = RegExp(r'\s*\(.*\)');
  static final RegExp _trailingNumberRegex = RegExp(r'\s+\d+$');

  /// Extrae el identificador de grupo/saga eliminando sufijos `_1`, `_3`, `_all`.
  static String extractSagaGroupId(String achievementId) {
    final trimmed = achievementId.trim();
    final match = _tierSuffixRegex.firstMatch(trimmed);
    if (match != null) {
      return trimmed.substring(0, trimmed.length - match.group(0)!.length);
    }
    return trimmed;
  }

  /// Limpia sufijos entre paréntesis o niveles numéricos finales del nombre de saga.
  static String cleanSagaBaseName(String rawName) {
    return rawName
        .replaceAll(_parenSuffixRegex, '')
        .replaceAll(_trailingNumberRegex, '')
        .trim();
  }

  /// Resuelve el `target` de un hito leyendo `saga_target` con fallback al sufijo del ID.
  static int resolveMilestoneTarget(Map<String, dynamic> row) {
    final rawSagaTarget = row['saga_target'];
    final explicit = rawSagaTarget is num
        ? rawSagaTarget.toInt()
        : int.tryParse(rawSagaTarget?.toString() ?? '');
    if (explicit != null && explicit > 0) {
      return explicit;
    }

    final aId = row['id']?.toString() ?? '';
    final matchSuffix = _numericSuffixRegex.firstMatch(aId);
    if (matchSuffix != null) {
      return int.tryParse(matchSuffix.group(1) ?? '') ?? 1;
    }
    if (aId.endsWith('_all')) {
      if (aId.startsWith('fromsoftware') || aId.startsWith('zelda')) {
        return 7;
      }
      if (aId.startsWith('mario')) {
        return 15;
      }
      if (aId.startsWith('dark_souls')) {
        return 3;
      }
    }
    return 1;
  }

  /// Busca la configuración de compañía/colección/franquicia IGDB para un [groupId].
  static Map<String, int?>? resolveIgdbIdsForGroup(String groupId) {
    final exact = achievementIgdbIds[groupId];
    if (exact != null) return exact;
    for (final entry in achievementIgdbIds.entries) {
      if (groupId.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// IDs de compañías IGDB cuyos logros de catálogo exigen `developer = true`
  /// para evitar atribuirles juegos donde solo actuaron como distribuidoras.
  static const Set<int> developerOnlyCompanyIds = {
    37,    // Capcom
    129,   // Konami
    1012,  // FromSoftware
    26,    // Square Enix
    56,    // Valve
    305,   // Remedy
    401,   // Naughty Dog
    908,   // CD Projekt RED
    170,   // Kojima Productions
    769,   // Team Ninja
  };

  static const Map<String, Map<String, int?>> achievementIgdbIds = {
    'kojima': {'companyId': 170},
    'fromsoftware': {'companyId': 1012},
    'nintendo': {'companyId': 70},
    'capcom': {'companyId': 37},
    'naughty_dog': {'companyId': 401},
    'rockstar': {'companyId': 29},
    'cd_projekt': {'companyId': 908},
    'valve': {'companyId': 56},
    'square_enix': {'companyId': 26},
    'bethesda': {'companyId': 16565},
    'konami': {'companyId': 129},
    'remedy': {'companyId': 305},
    'team_ninja': {'companyId': 769},
    'pokemon': {'companyId': 1617},
    'zelda': {'collectionId': 106},
    'mario': {'collectionId': 240},
    'halo': {'franchiseId': 137},
    'sonic': {'collectionId': 2156},
    'persona': {'franchiseId': 552, 'franchiseId2': 538},
    'dark_souls': {'collectionId': 543, 'franchiseId': 1124},
    'assassins_creed': {'franchiseId': 571},
    'yakuza': {'franchiseId': 1467},
    'resident_evil': {'franchiseId': 29},
    'final_fantasy': {'franchiseId': 4},
    'call_of_duty': {'franchiseId': 726},
    'elder_scrolls': {'franchiseId': 456},
    'god_of_war': {'franchiseId': 2098},
    'tomb_raider': {'franchiseId': 279},
    'monster_hunter': {'franchiseId': 824},
    'kingdom_hearts': {'franchiseId': 720},
    'silent_hill': {'franchiseId': 554},
    'metroid': {'franchiseId': 756},
    'kirby': {'franchiseId': 789},
    'devil_may_cry': {'franchiseId': 834},
    'castlevania': {'franchiseId': 895},
    'mass_effect': {'franchiseId': 1048},
    'doom': {'franchiseId': 798},
    'bioshock': {'collectionId': 1},
    'borderlands': {'franchiseId': 808},
    'metro': {'franchiseId': 1344},
    'dead_space': {'franchiseId': 1386},
    'xenoblade': {'franchiseId': 4564},
  };
}
