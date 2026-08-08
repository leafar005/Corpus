// lib/models/review.dart
//
// Modelo tipado para una reseña de juego.
// Sustituye Map<String, dynamic> en ReviewRepository, ReviewModal,
// GameDetailsScreen y ReviewDetailsScreen.

import 'package:flutter/foundation.dart';
import 'game_status.dart';
import 'user_profile.dart';

/// Una reseña de un juego por parte de un usuario.
@immutable
class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.status,
    this.rating,
    this.ratingGameplay,
    this.ratingNarrative,
    this.ratingSoundtrack,
    this.ratingVisuals,
    this.comment,
    this.completionType,
    this.platform,
    this.playTimeHours,
    this.playedFrom,
    this.playedUntil,
    this.progressPercent,
    this.replayNumber,
    this.isReplay = false,
    this.imageUrls = const [],
    this.partnerIds = const [],
    this.partners = const [],
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final int gameId;
  final GameStatus status;

  // Ratings individuales (1–10, null = no valorado)
  final double? rating;
  final double? ratingGameplay;
  final double? ratingNarrative;
  final double? ratingSoundtrack;
  final double? ratingVisuals;

  final String? comment;
  final String? completionType;
  final String? platform;
  final double? playTimeHours;
  final DateTime? playedFrom;
  final DateTime? playedUntil;
  final int? progressPercent;
  final int? replayNumber;
  final bool isReplay;
  final List<String> imageUrls;

  // Copilotos de juego cooperativo
  final List<String> partnerIds;
  final List<UserProfile> partners;

  // Datos del autor (cuando se hace join)
  final UserProfile? user;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Rating global calculado como promedio de los ratings individuales,
  /// o el rating global si no hay individuales.
  double? get effectiveRating {
    final individual = [ratingGameplay, ratingNarrative, ratingSoundtrack, ratingVisuals]
        .whereType<double>()
        .toList();
    if (individual.isNotEmpty) {
      return individual.reduce((a, b) => a + b) / individual.length;
    }
    return rating;
  }

  /// Construye un [Review] desde una fila de Supabase.
  factory Review.fromMap(Map<String, dynamic> map) {
    List<UserProfile> partners = [];
    final partnersRaw = map['partners'];
    if (partnersRaw is List) {
      partners = partnersRaw
          .whereType<Map<String, dynamic>>()
          .map((p) => UserProfile.fromMap(p))
          .toList();
    }

    UserProfile? user;
    // El join puede venir como 'users' o como el alias de FK
    final userRaw = map['users'] ?? map['user'];
    if (userRaw is Map<String, dynamic>) {
      user = UserProfile.fromMap(userRaw);
    }

    List<String> imageUrls = [];
    final rawImages = map['image_urls'];
    if (rawImages is List) {
      imageUrls = rawImages.whereType<String>().toList();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      imageUrls = [rawImages];
    }

    return Review(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      gameId: (map['game_id'] as num).toInt(),
      status: GameStatus.fromStringOrDefault(map['status'] as String?),
      rating: (map['rating'] as num?)?.toDouble(),
      ratingGameplay: (map['rating_gameplay'] as num?)?.toDouble(),
      ratingNarrative: (map['rating_narrative'] as num?)?.toDouble(),
      ratingSoundtrack: (map['rating_soundtrack'] as num?)?.toDouble(),
      ratingVisuals: (map['rating_visuals'] as num?)?.toDouble(),
      comment: map['comment'] as String?,
      completionType: map['completion_type'] as String?,
      platform: map['platform'] as String?,
      playTimeHours: (map['play_time_hours'] as num?)?.toDouble(),
      playedFrom: map['played_from'] != null ? DateTime.tryParse(map['played_from'] as String) : null,
      playedUntil: map['played_until'] != null ? DateTime.tryParse(map['played_until'] as String) : null,
      progressPercent: (map['progress_percent'] as num?)?.toInt(),
      replayNumber: (map['replay_number'] as num?)?.toInt(),
      isReplay: map['is_replay'] as bool? ?? false,
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      partnerIds: List<String>.from(map['partner_ids'] ?? []),
      partners: partners,
      user: user,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'game_id': gameId,
    'status': status.dbValue,
    if (rating != null) 'rating': rating,
    if (ratingGameplay != null) 'rating_gameplay': ratingGameplay,
    if (ratingNarrative != null) 'rating_narrative': ratingNarrative,
    if (ratingSoundtrack != null) 'rating_soundtrack': ratingSoundtrack,
    if (ratingVisuals != null) 'rating_visuals': ratingVisuals,
    if (comment != null) 'comment': comment,
    if (completionType != null) 'completion_type': completionType,
    if (platform != null) 'platform': platform,
    if (playTimeHours != null) 'play_time_hours': playTimeHours,
    if (playedFrom != null) 'played_from': playedFrom!.toIso8601String().split('T')[0],
    if (playedUntil != null) 'played_until': playedUntil!.toIso8601String().split('T')[0],
    if (progressPercent != null) 'progress_percent': progressPercent,
    if (replayNumber != null) 'replay_number': replayNumber,
    'is_replay': isReplay,
    if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    if (partnerIds.isNotEmpty) 'partner_ids': partnerIds,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'game_id': gameId,
    'status': status.dbValue,
    if (rating != null) 'rating': rating,
    if (ratingGameplay != null) 'rating_gameplay': ratingGameplay,
    if (ratingNarrative != null) 'rating_narrative': ratingNarrative,
    if (ratingSoundtrack != null) 'rating_soundtrack': ratingSoundtrack,
    if (ratingVisuals != null) 'rating_visuals': ratingVisuals,
    if (comment != null) 'comment': comment,
    if (completionType != null) 'completion_type': completionType,
    if (platform != null) 'platform': platform,
    if (playTimeHours != null) 'play_time_hours': playTimeHours,
    if (playedFrom != null) 'played_from': playedFrom!.toIso8601String().split('T')[0],
    if (playedUntil != null) 'played_until': playedUntil!.toIso8601String().split('T')[0],
    if (progressPercent != null) 'progress_percent': progressPercent,
    if (replayNumber != null) 'replay_number': replayNumber,
    'is_replay': isReplay,
    if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    if (partnerIds.isNotEmpty) 'partner_ids': partnerIds,
    if (partners.isNotEmpty) 'partners': partners.map((p) => p.toMap()).toList(),
    if (user != null) 'users': user!.toMap(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  Review copyWith({
    GameStatus? status,
    double? rating,
    double? ratingGameplay,
    double? ratingNarrative,
    double? ratingSoundtrack,
    double? ratingVisuals,
    String? comment,
    String? completionType,
    String? platform,
    double? playTimeHours,
    DateTime? playedFrom,
    DateTime? playedUntil,
    int? progressPercent,
    int? replayNumber,
    bool? isReplay,
    List<String>? imageUrls,
    List<String>? partnerIds,
    List<UserProfile>? partners,
    UserProfile? user,
  }) {
    return Review(
      id: id,
      userId: userId,
      gameId: gameId,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      ratingGameplay: ratingGameplay ?? this.ratingGameplay,
      ratingNarrative: ratingNarrative ?? this.ratingNarrative,
      ratingSoundtrack: ratingSoundtrack ?? this.ratingSoundtrack,
      ratingVisuals: ratingVisuals ?? this.ratingVisuals,
      comment: comment ?? this.comment,
      completionType: completionType ?? this.completionType,
      platform: platform ?? this.platform,
      playTimeHours: playTimeHours ?? this.playTimeHours,
      playedFrom: playedFrom ?? this.playedFrom,
      playedUntil: playedUntil ?? this.playedUntil,
      progressPercent: progressPercent ?? this.progressPercent,
      replayNumber: replayNumber ?? this.replayNumber,
      isReplay: isReplay ?? this.isReplay,
      imageUrls: imageUrls ?? this.imageUrls,
      partnerIds: partnerIds ?? this.partnerIds,
      partners: partners ?? this.partners,
      user: user ?? this.user,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Review && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Review(id: $id, gameId: $gameId, status: ${status.name}, rating: $rating)';
}
