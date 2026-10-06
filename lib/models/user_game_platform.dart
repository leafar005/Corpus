import 'package:flutter/foundation.dart';

/// Plataforma en la que un usuario posee un juego (tabla `user_game_platforms`).
@immutable
class UserGamePlatform {
  const UserGamePlatform({
    required this.userId,
    required this.gameId,
    required this.platformName,
    this.createdAt,
  });

  final String userId;
  final int gameId;
  final String platformName;
  final DateTime? createdAt;

  factory UserGamePlatform.fromMap(Map<String, dynamic> map) {
    return UserGamePlatform(
      userId: map['user_id'] as String? ?? '',
      gameId: (map['game_id'] as num?)?.toInt() ?? 0,
      platformName: map['platform_name'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'game_id': gameId,
      'platform_name': platformName,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
