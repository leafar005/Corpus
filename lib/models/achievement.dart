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
    final achMap = (map['achievements'] as Map<String, dynamic>?) ?? map;

    return Achievement(
      id: achMap['id'] as String? ?? '',
      name: achMap['name'] as String? ?? '',
      description: achMap['description'] as String? ?? '',
      category: achMap['category'] as String? ?? '',
      xpReward: (achMap['xp_reward'] as num?)?.toInt() ?? 0,
      rarity: achMap['rarity'] as String? ?? 'common',
      iconName: achMap['icon_name'] as String? ?? 'star',
      unlockedAt: map['unlocked_at'] != null 
          ? DateTime.tryParse(map['unlocked_at'] as String) 
          : null,
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
      if (unlockedAt != null) 'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
