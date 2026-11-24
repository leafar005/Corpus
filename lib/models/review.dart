// lib/models/review.dart
//
// Modelo tipado para una reseña de juego.
// Sustituye Map<String, dynamic> en ReviewRepository, ReviewModal,
// GameDetailsScreen y ReviewDetailsScreen.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'game_status.dart';
import 'user_profile.dart';

const Object _sentinel = Object();

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
    var sum = 0.0;
    var count = 0;
    if (ratingGameplay != null) {
      sum += ratingGameplay!;
      count++;
    }
    if (ratingNarrative != null) {
      sum += ratingNarrative!;
      count++;
    }
    if (ratingSoundtrack != null) {
      sum += ratingSoundtrack!;
      count++;
    }
    if (ratingVisuals != null) {
      sum += ratingVisuals!;
      count++;
    }
    if (count > 0) return sum / count;
    return rating;
  }

  /// Construye un [Review] desde una fila de Supabase.
  factory Review.fromMap(Map<String, dynamic> map) {
    List<UserProfile> partners = const [];
    final partnersRaw = map['partners'];
    if (partnersRaw is List) {
      final parsed = <UserProfile>[];
      for (final p in partnersRaw) {
        if (p is Map) {
          parsed.add(UserProfile.fromMap(Map<String, dynamic>.from(p)));
        }
      }
      if (parsed.isNotEmpty) {
        partners = List<UserProfile>.unmodifiable(parsed);
      }
    }

    UserProfile? user;
    // El join puede venir como 'users' o como el alias de FK
    final userRaw = map['users'] ?? map['user'];
    if (userRaw is Map) {
      user = UserProfile.fromMap(Map<String, dynamic>.from(userRaw));
    }

    final imageUrls = _parseImageUrls(map['image_urls']);
    final partnerIds = _parsePartnerIds(map['partner_ids']);

    return Review(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      gameId: _parseInt(map['game_id']) ?? 0,
      status: GameStatus.fromStringOrDefault(map['status']?.toString()),
      rating: _parseDouble(map['rating']),
      ratingGameplay: _parseDouble(map['rating_gameplay']),
      ratingNarrative: _parseDouble(map['rating_narrative']),
      ratingSoundtrack: _parseDouble(map['rating_soundtrack']),
      ratingVisuals: _parseDouble(map['rating_visuals']),
      comment: map['comment']?.toString(),
      completionType: map['completion_type']?.toString(),
      platform: map['platform']?.toString(),
      playTimeHours: _parseDouble(map['play_time_hours']),
      playedFrom: _parseDateTime(map['played_from']),
      playedUntil: _parseDateTime(map['played_until']),
      progressPercent: _parseInt(map['progress_percent']),
      replayNumber: _parseInt(map['replay_number']),
      isReplay: map['is_replay'] == true,
      imageUrls: imageUrls,
      partnerIds: partnerIds,
      partners: partners,
      user: user,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static List<String> _parseImageUrls(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      final out = <String>[];
      for (final e in raw) {
        if (e == null) continue;
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
      return out.isEmpty ? const [] : List<String>.unmodifiable(out);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) return _parseImageUrls(decoded);
        } catch (_) {}
      }
      return List<String>.unmodifiable([trimmed]);
    }
    return const [];
  }

  static List<String> _parsePartnerIds(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const [];
    final out = <String>[];
    for (final e in raw) {
      if (e == null) continue;
      final s = e.toString().trim();
      if (s.isNotEmpty) out.add(s);
    }
    return out.isEmpty ? const [] : List<String>.unmodifiable(out);
  }

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
    if (playedFrom != null)
      'played_from': playedFrom!.toIso8601String().split('T')[0],
    if (playedUntil != null)
      'played_until': playedUntil!.toIso8601String().split('T')[0],
    if (progressPercent != null) 'progress_percent': progressPercent,
    if (replayNumber != null) 'replay_number': replayNumber,
    'is_replay': isReplay,
    if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    if (partnerIds.isNotEmpty) 'partner_ids': partnerIds,
    if (partners.isNotEmpty)
      'partners': partners.map((p) => p.toMap()).toList(),
    if (user != null) 'users': user!.toMap(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  Review copyWith({
    GameStatus? status,
    Object? rating = _sentinel,
    Object? ratingGameplay = _sentinel,
    Object? ratingNarrative = _sentinel,
    Object? ratingSoundtrack = _sentinel,
    Object? ratingVisuals = _sentinel,
    Object? comment = _sentinel,
    Object? completionType = _sentinel,
    Object? platform = _sentinel,
    Object? playTimeHours = _sentinel,
    Object? playedFrom = _sentinel,
    Object? playedUntil = _sentinel,
    Object? progressPercent = _sentinel,
    Object? replayNumber = _sentinel,
    bool? isReplay,
    List<String>? imageUrls,
    List<String>? partnerIds,
    List<UserProfile>? partners,
    Object? user = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return Review(
      id: id,
      userId: userId,
      gameId: gameId,
      status: status ?? this.status,
      rating: identical(rating, _sentinel) ? this.rating : rating as double?,
      ratingGameplay: identical(ratingGameplay, _sentinel)
          ? this.ratingGameplay
          : ratingGameplay as double?,
      ratingNarrative: identical(ratingNarrative, _sentinel)
          ? this.ratingNarrative
          : ratingNarrative as double?,
      ratingSoundtrack: identical(ratingSoundtrack, _sentinel)
          ? this.ratingSoundtrack
          : ratingSoundtrack as double?,
      ratingVisuals: identical(ratingVisuals, _sentinel)
          ? this.ratingVisuals
          : ratingVisuals as double?,
      comment: identical(comment, _sentinel) ? this.comment : comment as String?,
      completionType: identical(completionType, _sentinel)
          ? this.completionType
          : completionType as String?,
      platform: identical(platform, _sentinel)
          ? this.platform
          : platform as String?,
      playTimeHours: identical(playTimeHours, _sentinel)
          ? this.playTimeHours
          : playTimeHours as double?,
      playedFrom: identical(playedFrom, _sentinel)
          ? this.playedFrom
          : playedFrom as DateTime?,
      playedUntil: identical(playedUntil, _sentinel)
          ? this.playedUntil
          : playedUntil as DateTime?,
      progressPercent: identical(progressPercent, _sentinel)
          ? this.progressPercent
          : progressPercent as int?,
      replayNumber: identical(replayNumber, _sentinel)
          ? this.replayNumber
          : replayNumber as int?,
      isReplay: isReplay ?? this.isReplay,
      imageUrls: imageUrls != null
          ? List<String>.unmodifiable(imageUrls)
          : this.imageUrls,
      partnerIds: partnerIds != null
          ? List<String>.unmodifiable(partnerIds)
          : this.partnerIds,
      partners: partners != null
          ? List<UserProfile>.unmodifiable(partners)
          : this.partners,
      user: identical(user, _sentinel) ? this.user : user as UserProfile?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
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
