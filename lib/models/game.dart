// lib/models/game.dart
//
// Modelo tipado para un juego del catálogo de Corpus.
// Consolida los campos de IGDB + los campos propios de la tabla `games`.
// No reemplaza GameDetailsScreen de golpe — este modelo se adopta
// progresivamente: primero en repositorios, luego en pantallas.

import 'dart:convert';

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
    this.franchiseIds = const {},
    this.collection,
    this.collectionId,
    this.category,
    this.gameType,
    this.parentGameId,
    this.versionParentId,
    this.remakeOfId,
    this.remasterOfId,
    this.isSteamOnly = false,
    this.metacriticScore,
    this.metacriticUrl,
    this.metacriticUserScore,
    this.metacriticSlug,
    this.metacriticUpdatedAt,
    this.screenshots = const [],
    this.artworks = const [],
    this.videos = const [],
    this.websites = const [],
    this.publisher,
    this.publisherId,
    this.developerId,
    this.playerPerspectives = const [],
    this.aggregatedRating,
    this.url,
    this.metacriticCriticCount,
    this.metacriticUserRatingCount,
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
  final Map<String, int> franchiseIds;
  final String? collection;
  final int? collectionId;
  final int? category;
  final int? gameType;
  final int? parentGameId;
  final int? versionParentId;
  final int? remakeOfId;
  final int? remasterOfId;
  final bool isSteamOnly;

  // Metacritic (persistido desde la Edge Function get-metacritic-score)
  final int? metacriticScore;
  final String? metacriticUrl;
  final double? metacriticUserScore;
  final String? metacriticSlug;
  final DateTime? metacriticUpdatedAt;
  final int? metacriticCriticCount;
  final int? metacriticUserRatingCount;

  // Nuevos campos fase 4
  final List<String> screenshots;
  final List<String> artworks;
  final List<String> videos;
  final List<dynamic> websites;
  final String? publisher;
  final int? publisherId;
  final int? developerId;
  final List<String> playerPerspectives;
  final double? aggregatedRating;
  final String? url;

  /// Devuelve true si el dato de Metacritic existe y tiene menos de 30 días.
  bool get hasRecentMetacriticData {
    if (metacriticScore == null) return false;
    if (metacriticUpdatedAt == null) return false;
    return DateTime.now().difference(metacriticUpdatedAt!).inDays < 30;
  }

  /// Resuelve la categoría final, priorizando gameType sobre el category obsoleto.
  int? get resolvedCategory => gameType ?? category;

  /// Construye un [Game] desde una fila de Supabase o un objeto de IGDB.
  factory Game.fromMap(Map<String, dynamic> map) {
    final parsedIgdbId = _parseInt(map['igdb_id'] ?? map['id']);
    if (parsedIgdbId == null) {
      throw ArgumentError(
        'Game.fromMap requiere un igdb_id o id entero válido',
      );
    }

    final rawDev = map['developer']?.toString();
    final hasExplicitDev =
        rawDev != null &&
        rawDev.isNotEmpty &&
        rawDev != 'Desconocido' &&
        rawDev != 'Desarrollador desconocido';
    final rawPub = map['publisher']?.toString();
    final parsedCompanies =
        (!hasExplicitDev || rawPub == null || rawPub.isEmpty)
        ? _parseInvolvedCompanies(map['involved_companies'])
        : (
            developer: null,
            developerId: null,
            publisher: null,
            publisherId: null,
          );

    final rawCover = map['cover'];
    final coverImageId = rawCover is Map ? rawCover['image_id'] : null;
    final firstReleaseTs = _parseInt(map['first_release_date']);
    final String? releaseDate = firstReleaseTs != null
        ? DateTime.fromMillisecondsSinceEpoch(
            firstReleaseTs * 1000,
            isUtc: true,
          ).toIso8601String()
        : (map['release_date'] is DateTime
              ? (map['release_date'] as DateTime).toUtc().toIso8601String()
              : map['release_date']?.toString());

    final rawMcUser = _parseDouble(map['metacritic_user_score']);
    final parsedMcUser = rawMcUser != null
        ? (rawMcUser > 10 ? rawMcUser / 10 : rawMcUser)
        : null;

    final parsedCollection = _parseCollection(
      map['collection'] ?? _firstListElement(map['collections']),
      fallbackId: _parseInt(map['collection_id']),
    );
    final parsedFranchises = _parseFranchises(map['franchises']);

    return Game(
      igdbId: parsedIgdbId,
      title: map['title']?.toString() ?? map['name']?.toString() ?? '',
      coverUrl:
          map['cover_url']?.toString() ??
          (coverImageId != null
              ? 'https://images.igdb.com/igdb/image/upload/t_cover_big/$coverImageId.jpg'
              : null),
      releaseDate: releaseDate,
      summary: map['summary']?.toString(),
      genres: _parseStringList(map['genres']),
      themes: _parseStringList(map['themes']),
      gameModes: _parseStringList(map['game_modes']),
      platforms: _parseStringList(map['platforms']),
      developer: hasExplicitDev
          ? rawDev
          : (parsedCompanies.developer ?? rawDev),
      gameEngines: _parseStringList(map['game_engines']),
      franchises: parsedFranchises.names,
      franchiseIds: parsedFranchises.ids,
      collection: parsedCollection.name,
      collectionId: parsedCollection.id,
      category: _parseInt(map['category']),
      gameType: _parseInt(map['game_type']),
      parentGameId: _parseInt(map['parent_game']),
      versionParentId: _parseInt(map['version_parent']),
      remakeOfId: _parseInt(map['remake_of']),
      remasterOfId: _parseInt(map['remaster_of']),
      isSteamOnly: map['is_steam_only'] == true,
      metacriticScore: _parseInt(map['metacritic_score']),
      metacriticUrl: map['metacritic_url']?.toString(),
      metacriticUserScore: parsedMcUser,
      metacriticSlug: map['metacritic_slug']?.toString(),
      metacriticUpdatedAt: _parseDateTime(map['metacritic_updated_at']),
      metacriticCriticCount: _parseInt(map['metacritic_critic_count']),
      metacriticUserRatingCount: _parseInt(map['metacritic_user_rating_count']),
      screenshots: _parseStringList(map['screenshots'], isImage: true),
      artworks: _parseStringList(map['artworks'], isImage: true),
      videos: _parseStringList(map['videos'], isVideo: true),
      websites: map['websites'] is List
          ? List<dynamic>.unmodifiable(map['websites'] as List)
          : const [],
      publisher: (rawPub != null && rawPub.isNotEmpty)
          ? rawPub
          : parsedCompanies.publisher,
      publisherId:
          _parseInt(map['publisher_id']) ?? parsedCompanies.publisherId,
      developerId:
          _parseInt(map['developer_id']) ?? parsedCompanies.developerId,
      playerPerspectives: _parseStringList(map['player_perspectives']),
      aggregatedRating: _parseDouble(map['aggregated_rating']),
      url: map['url']?.toString(),
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
    if (franchises.isNotEmpty)
      'franchises': franchiseIds.isNotEmpty
          ? [
              for (final name in franchises)
                if (franchiseIds.containsKey(name))
                  {'id': franchiseIds[name], 'name': name}
                else
                  {'name': name},
            ]
          : franchises,
    if (collection != null)
      'collection': collectionId != null
          ? {'id': collectionId, 'name': collection}
          : collection,
    if (category != null) 'category': category,
    if (gameType != null) 'game_type': gameType,
    if (parentGameId != null) 'parent_game': parentGameId,
    if (versionParentId != null) 'version_parent': versionParentId,
    if (remakeOfId != null) 'remake_of': remakeOfId,
    if (remasterOfId != null) 'remaster_of': remasterOfId,
    'is_steam_only': isSteamOnly,
    if (metacriticScore != null) 'metacritic_score': metacriticScore,
    if (metacriticUrl != null) 'metacritic_url': metacriticUrl,
    if (metacriticUserScore != null)
      'metacritic_user_score': metacriticUserScore,
    if (metacriticSlug != null) 'metacritic_slug': metacriticSlug,
    if (metacriticUpdatedAt != null)
      'metacritic_updated_at': metacriticUpdatedAt!.toIso8601String(),
    if (metacriticCriticCount != null)
      'metacritic_critic_count': metacriticCriticCount,
    if (metacriticUserRatingCount != null)
      'metacritic_user_rating_count': metacriticUserRatingCount,
    if (screenshots.isNotEmpty) 'screenshots': screenshots,
    if (artworks.isNotEmpty) 'artworks': artworks,
    if (videos.isNotEmpty) 'videos': videos,
    if (websites.isNotEmpty) 'websites': websites,
    if (publisher != null) 'publisher': publisher,
    if (publisherId != null) 'publisher_id': publisherId,
    if (developerId != null) 'developer_id': developerId,
    if (playerPerspectives.isNotEmpty)
      'player_perspectives': playerPerspectives,
    if (aggregatedRating != null) 'aggregated_rating': aggregatedRating,
    if (url != null) 'url': url,
  };

  // ── Helpers de parsing ──────────────────────────────────────────────────────

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static dynamic _firstListElement(dynamic raw) {
    if (raw is List && raw.isNotEmpty) return raw.first;
    return null;
  }

  /// Extrae una lista de nombres de géneros a partir de JSON crudo sin construir
  /// una instancia completa de [Game].
  static List<String> parseGenres(dynamic raw) => _parseStringList(raw);

  static List<String> _parseStringList(
    dynamic raw, {
    bool isImage = false,
    bool isVideo = false,
  }) {
    if (raw == null) return const [];
    if (raw is List) {
      final out = <String>[];
      for (final e in raw) {
        if (e == null) continue;
        String value;
        if (e is Map) {
          if (isImage && e['image_id'] != null) {
            value = e['image_id'].toString().trim();
          } else if (isVideo && e['video_id'] != null) {
            value = e['video_id'].toString().trim();
          } else {
            value = e['name']?.toString().trim() ?? '';
          }
        } else {
          value = e.toString().trim();
        }
        if (value.isNotEmpty) out.add(value);
      }
      return out.isEmpty ? const [] : List<String>.unmodifiable(out);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return _parseStringList(
              decoded,
              isImage: isImage,
              isVideo: isVideo,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Game] Error decodificando lista JSON: $e');
          }
        }
      }
      return List<String>.unmodifiable([trimmed]);
    }
    return const [];
  }

  static ({String? name, int? id}) _parseCollection(
    dynamic raw, {
    int? fallbackId,
  }) {
    if (raw == null) return (name: null, id: fallbackId);
    if (raw is Map) {
      final name = raw['name']?.toString().trim();
      final id = _parseInt(raw['id']) ?? fallbackId;
      return (name: (name != null && name.isNotEmpty) ? name : null, id: id);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return (name: null, id: fallbackId);
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            return _parseCollection(decoded, fallbackId: fallbackId);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Game] Error decodificando collection JSON: $e');
          }
        }
      }
      return (name: trimmed, id: fallbackId);
    }
    final str = raw.toString().trim();
    return (name: str.isNotEmpty ? str : null, id: fallbackId);
  }

  static ({List<String> names, Map<String, int> ids}) _parseFranchises(
    dynamic raw,
  ) {
    final names = _parseStringList(raw);
    if (names.isEmpty) return (names: const [], ids: const {});

    dynamic listRaw = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('[')) {
        try {
          listRaw = jsonDecode(trimmed);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Game] Error decodificando franchises JSON: $e');
          }
        }
      }
    }

    final ids = <String, int>{};
    if (listRaw is List) {
      for (final item in listRaw) {
        if (item is Map) {
          final name = item['name']?.toString().trim();
          final id = _parseInt(item['id']);
          if (name != null && name.isNotEmpty && id != null) {
            ids[name] = id;
          }
        }
      }
    }

    return (
      names: names,
      ids: ids.isEmpty ? const {} : Map<String, int>.unmodifiable(ids),
    );
  }

  static ({
    String? developer,
    int? developerId,
    String? publisher,
    int? publisherId,
  }) _parseInvolvedCompanies(dynamic raw) {
    dynamic listRaw = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('[')) {
        try {
          listRaw = jsonDecode(trimmed);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Game] Error decodificando involved_companies JSON: $e');
          }
        }
      }
    }
    if (listRaw is! List || listRaw.isEmpty) {
      return (
        developer: null,
        developerId: null,
        publisher: null,
        publisherId: null,
      );
    }

    String? developer;
    int? developerId;
    String? publisher;
    int? publisherId;
    String? firstCompanyName;
    int? firstCompanyId;

    for (final item in listRaw) {
      if (item is! Map) continue;
      final company = item['company'];
      if (company is! Map) continue;
      final name = company['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final id = _parseInt(company['id']);

      firstCompanyName ??= name;
      firstCompanyId ??= id;

      if (developer == null && item['developer'] == true) {
        developer = name;
        developerId = id;
      }
      if (publisher == null && item['publisher'] == true) {
        publisher = name;
        publisherId = id;
      }
    }

    if (developer == null && firstCompanyName != null) {
      developer = firstCompanyName;
      developerId = firstCompanyId;
    }

    if (publisher != null &&
        developer != null &&
        publisher.trim().toLowerCase() == developer.trim().toLowerCase()) {
      publisher = null;
      publisherId = null;
    }

    return (
      developer: developer,
      developerId: developerId,
      publisher: publisher,
      publisherId: publisherId,
    );
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
