// lib/models/achievement.dart

import 'package:flutter/foundation.dart';

/// Un logro dentro de la aplicación Corpus.
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.xpReward,
    required this.rarity,
    required this.iconName,
    this.unlockedAt,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int xpReward;
  final String rarity;
  final String iconName;

  /// Fecha de desbloqueo, presente si esta instancia proviene de un JOIN con `user_achievements`
  final DateTime? unlockedAt;

  factory Achievement.fromMap(Map<String, dynamic> map) {
    // Cuando se consulta 'user_achievements', los datos del logro suelen venir
    // anidados en un mapa 'achievements' debido al foreign key.
    final rawNested = map['achievements'];
    final achMap = rawNested is Map ? Map<String, dynamic>.from(rawNested) : map;
    final rawUnlocked = map['unlocked_at'];

    return Achievement(
      id: achMap['id']?.toString() ?? '',
      name: achMap['name']?.toString() ?? '',
      description: achMap['description']?.toString() ?? '',
      category: achMap['category']?.toString() ?? '',
      xpReward:
          (achMap['xp_reward'] as num?)?.toInt() ??
          int.tryParse(achMap['xp_reward']?.toString() ?? '') ??
          0,
      rarity: achMap['rarity']?.toString() ?? 'common',
      iconName: achMap['icon_name']?.toString() ?? 'star',
      unlockedAt: rawUnlocked is DateTime
          ? rawUnlocked
          : (rawUnlocked != null
                ? DateTime.tryParse(rawUnlocked.toString())
                : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'xp_reward': xpReward,
      'rarity': rarity,
      'icon_name': iconName,
      if (unlockedAt != null) 'unlocked_at': unlockedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
