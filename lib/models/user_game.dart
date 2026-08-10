// lib/models/user_game.dart

import 'package:flutter/foundation.dart';
import 'game_status.dart';
import 'game.dart';
import 'user_profile.dart';
import 'achievement.dart';

/// Relación de un usuario con un juego (biblioteca, stash, etc.).
@immutable
class UserGame {
  const UserGame({
    required this.userId,
    required this.gameId,
    required this.status,
    this.rating,
    this.ratingGameplay,
    this.ratingNarrative,
    this.ratingSoundtrack,
    this.ratingVisuals,
    this.comment,
    this.partnerId,
    this.playCount = 1,
    this.playTimeHours,
    this.lastPlayedAt,
    this.updatedAt,
    this.game,
    this.partner,
    this.achievements = const [],
  });

  final String userId;
  final int gameId;
  final GameStatus status;

  final double? rating;
  final double? ratingGameplay;
  final double? ratingNarrative;
  final double? ratingSoundtrack;
  final double? ratingVisuals;
  final String? comment;

  final String? partnerId;
  final int playCount;
  final double? playTimeHours;
  final DateTime? lastPlayedAt;
  final DateTime? updatedAt;

  // Relaciones (JOINs)
  final Game? game;
  final UserProfile? partner;

  // Logros (JSONB array en user_games)
  final List<Achievement> achievements;

  /// Rating global calculado como promedio de los ratings individuales,
  /// o el rating global si no hay individuales.
  double? get effectiveRating {
    final individual = [
      ratingGameplay,
      ratingNarrative,
      ratingSoundtrack,
      ratingVisuals,
    ].whereType<double>().toList();
    if (individual.isNotEmpty) {
      return individual.reduce((a, b) => a + b) / individual.length;
    }
    return rating;
  }

  factory UserGame.fromMap(Map<String, dynamic> map) {
    Game? game;
    if (map['games'] != null) {
      game = Game.fromMap(map['games'] as Map<String, dynamic>);
    } else if (map['game'] != null) {
      game = Game.fromMap(map['game'] as Map<String, dynamic>);
    }

    UserProfile? partner;
    if (map['partner'] != null) {
      partner = UserProfile.fromMap(map['partner'] as Map<String, dynamic>);
    }

    List<Achievement> achievements = [];
    if (map['achievements'] != null && map['achievements'] is List) {
      achievements = (map['achievements'] as List)
          .map((e) => Achievement.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return UserGame(
      userId: map['user_id'] as String? ?? '',
      gameId: (map['game_id'] as num?)?.toInt() ?? 0,
      status: GameStatus.fromStringOrDefault(
        map['status'] as String?,
        fallback: GameStatus.wishlist,
      ),
      rating: (map['rating'] as num?)?.toDouble(),
      ratingGameplay: (map['rating_gameplay'] as num?)?.toDouble(),
      ratingNarrative: (map['rating_narrative'] as num?)?.toDouble(),
      ratingSoundtrack: (map['rating_soundtrack'] as num?)?.toDouble(),
      ratingVisuals: (map['rating_visuals'] as num?)?.toDouble(),
      comment: map['comment'] as String?,
      partnerId: map['partner_id'] as String?,
      playCount: (map['play_count'] as num?)?.toInt() ?? 1,
      playTimeHours: (map['play_time_hours'] as num?)?.toDouble(),
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.tryParse(map['last_played_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      game: game,
      partner: partner,
      achievements: achievements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'game_id': gameId,
      'status': status.dbValue,
      if (rating != null) 'rating': rating,
      if (ratingGameplay != null) 'rating_gameplay': ratingGameplay,
      if (ratingNarrative != null) 'rating_narrative': ratingNarrative,
      if (ratingSoundtrack != null) 'rating_soundtrack': ratingSoundtrack,
      if (ratingVisuals != null) 'rating_visuals': ratingVisuals,
      if (comment != null) 'comment': comment,
      if (partnerId != null) 'partner_id': partnerId,
      'play_count': playCount,
      if (playTimeHours != null) 'play_time_hours': playTimeHours,
      if (lastPlayedAt != null)
        'last_played_at': lastPlayedAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
      if (achievements.isNotEmpty)
        'achievements': achievements.map((e) => e.toMap()).toList(),
    };
  }
}
