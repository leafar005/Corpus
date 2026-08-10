// lib/models/game.dart
//
// Modelo tipado para un juego del catálogo de Corpus.
// Consolida los campos de IGDB + los campos propios de la tabla `games`.
// No reemplaza GameDetailsScreen de golpe — este modelo se adopta
// progresivamente: primero en repositorios, luego en pantallas.

import 'package:flutter/foundation.dart';

/// Datos de un juego tal como se almacenan en la tabla `games` de Supabase,
/// enriquecidos opcionalmente con datos de IGDB.
@immutable
class Game {
  const Game({
    required this.igdbId,
    required this.title,
    this.coverUrl,
    this.releaseDate,
    this.summary,
    this.genres = const [],
    this.themes = const [],
    this.gameModes = const [],
    this.platforms = const [],
    this.developer,
    this.gameEngines = const [],
    this.franchises = const [],
    this.collection,
    this.category,
    this.parentGameId,
    this.isSteamOnly = false,
    this.metacriticScore,
    this.metacriticUrl,
    this.metacriticUserScore,
    this.metacriticSlug,
    this.metacriticUpdatedAt,
  });

  final int igdbId;
  final String title;
  final String? coverUrl;
  final String? releaseDate;
  final String? summary;
  final List<String> genres;
  final List<String> themes;
  final List<String> gameModes;
  final List<String> platforms;
  final String? developer;
  final List<String> gameEngines;
  final List<String> franchises;
  final String? collection;
  final int? category;
  final int? parentGameId;
  final bool isSteamOnly;

  // Metacritic (persistido desde la Edge Function get-metacritic-score)
  final int? metacriticScore;
  final String? metacriticUrl;
  final double? metacriticUserScore;
  final String? metacriticSlug;
  final DateTime? metacriticUpdatedAt;

  /// Devuelve true si el dato de Metacritic existe y tiene menos de 30 días.
  bool get hasRecentMetacriticData {
    if (metacriticScore == null) return false;
    if (metacriticUpdatedAt == null) return false;
    return DateTime.now().difference(metacriticUpdatedAt!).inDays < 30;
  }

  /// Construye un [Game] desde una fila de Supabase.
  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      igdbId: (map['igdb_id'] ?? map['id']) as int,
      title: map['title'] as String? ?? map['name'] as String? ?? '',
      coverUrl:
          map['cover_url'] as String? ??
          (map['cover'] != null && map['cover']['image_id'] != null
              ? 'https://images.igdb.com/igdb/image/upload/t_cover_big/${map['cover']['image_id']}.jpg'
              : null),
      releaseDate: map['first_release_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['first_release_date'] as num).toInt() * 1000,
            ).toIso8601String()
          : map['release_date'] as String?,
      summary: map['summary'] as String?,
      genres: _parseStringList(map['genres']),
      themes: _parseStringList(map['themes']),
      gameModes: _parseStringList(map['game_modes']),
      platforms: _parseStringList(map['platforms']),
      developer: map['developer'] as String?,
      gameEngines: _parseStringList(map['game_engines']),
      franchises: _parseStringList(map['franchises']),
      collection: _parseCollectionName(map['collection']),
      category: (map['category'] as num?)?.toInt(),
      parentGameId: (map['parent_game'] as num?)?.toInt(),
      isSteamOnly: map['is_steam_only'] == true,
      metacriticScore: (map['metacritic_score'] as num?)?.toInt(),
      metacriticUrl: map['metacritic_url'] as String?,
      metacriticUserScore: (map['metacritic_user_score'] as num?)?.toDouble(),
      metacriticSlug: map['metacritic_slug'] as String?,
      metacriticUpdatedAt: map['metacritic_updated_at'] != null
          ? DateTime.tryParse(map['metacritic_updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'igdb_id': igdbId,
    'title': title,
    if (coverUrl != null) 'cover_url': coverUrl,
    if (releaseDate != null) 'release_date': releaseDate,
    if (summary != null) 'summary': summary,
    if (genres.isNotEmpty) 'genres': genres,
    if (themes.isNotEmpty) 'themes': themes,
    if (gameModes.isNotEmpty) 'game_modes': gameModes,
    if (platforms.isNotEmpty) 'platforms': platforms,
    if (developer != null) 'developer': developer,
    if (gameEngines.isNotEmpty) 'game_engines': gameEngines,
    if (franchises.isNotEmpty) 'franchises': franchises,
    if (collection != null) 'collection': collection,
    if (category != null) 'category': category,
    if (parentGameId != null) 'parent_game': parentGameId,
    if (isSteamOnly) 'is_steam_only': true,
    if (metacriticScore != null) 'metacritic_score': metacriticScore,
    if (metacriticUrl != null) 'metacritic_url': metacriticUrl,
    if (metacriticUserScore != null)
      'metacritic_user_score': metacriticUserScore,
    if (metacriticSlug != null) 'metacritic_slug': metacriticSlug,
    if (metacriticUpdatedAt != null)
      'metacritic_updated_at': metacriticUpdatedAt!.toIso8601String(),
  };

  // ── Helpers de parsing ──────────────────────────────────────────────────────

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map) return e['name']?.toString() ?? '';
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.isNotEmpty) return [raw];
    return const [];
  }

  static String? _parseCollectionName(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return raw['name']?.toString();
    if (raw is String) return raw.isNotEmpty ? raw : null;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Game &&
          runtimeType == other.runtimeType &&
          igdbId == other.igdbId;

  @override
  int get hashCode => igdbId.hashCode;

  @override
  String toString() => 'Game(igdbId: $igdbId, title: $title)';
}
