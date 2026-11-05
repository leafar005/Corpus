import 'package:flutter/foundation.dart';
import 'game.dart';
import 'game_group_item.dart';

@immutable
class GameGroup {
  const GameGroup({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.coverGameId,
    this.sortOrder = 0,
    this.isRanked = false,
    this.createdAt,
    this.items = const [],
    this.gameCount = 0,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final int? coverGameId;
  final int sortOrder;
  final bool isRanked;
  final DateTime? createdAt;
  final List<GameGroupItem> items;
  final int gameCount;

  List<Game> get previewGames =>
      items.map((i) => i.game).whereType<Game>().take(4).toList();

  Game? get coverGame {
    if (coverGameId != null) {
      for (final item in items) {
        if (item.gameId == coverGameId) return item.game;
      }
    }
    return previewGames.isNotEmpty ? previewGames.first : null;
  }

  GameGroup copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? coverGameId,
    int? sortOrder,
    bool? isRanked,
    DateTime? createdAt,
    List<GameGroupItem>? items,
    int? gameCount,
  }) {
    return GameGroup(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      coverGameId: coverGameId ?? this.coverGameId,
      sortOrder: sortOrder ?? this.sortOrder,
      isRanked: isRanked ?? this.isRanked,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      gameCount: gameCount ?? this.gameCount,
    );
  }

  static const String rankedMarker = '[#ranked#]';
  static const String _legacyRankedMarker = '\u200B[ranked]';

  static String? encodeRankedDescription(String? description, bool isRanked) {
    final clean = decodeRankedDescription(description).description;
    if (!isRanked) {
      return (clean == null || clean.isEmpty) ? null : clean;
    }
    if (clean == null || clean.isEmpty) {
      return rankedMarker;
    }
    return '$rankedMarker\n$clean';
  }

  static ({String? description, bool isRanked}) decodeRankedDescription(
    String? rawDescription,
  ) {
    if (rawDescription == null) {
      return (description: null, isRanked: false);
    }
    for (final marker in [rankedMarker, _legacyRankedMarker]) {
      if (rawDescription.startsWith('$marker\n')) {
        final rest = rawDescription.substring('$marker\n'.length).trim();
        return (description: rest.isEmpty ? null : rest, isRanked: true);
      }
      if (rawDescription == marker || rawDescription.startsWith(marker)) {
        final rest = rawDescription.substring(marker.length).trim();
        return (description: rest.isEmpty ? null : rest, isRanked: true);
      }
    }
    return (
      description: rawDescription.trim().isEmpty ? null : rawDescription,
      isRanked: false,
    );
  }

  factory GameGroup.fromMap(Map<String, dynamic> map) {
    final rawItems = map['game_group_items'];
    final items = rawItems is List
        ? rawItems
            .map(
              (e) => GameGroupItem.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <GameGroupItem>[];

    final countRaw = map['game_count'];
    final gameCount = countRaw is num
        ? countRaw.toInt()
        : (items.isNotEmpty ? items.length : 0);

    final decoded = decodeRankedDescription(map['description'] as String?);
    final isRankedCol = map['is_ranked'] as bool?;
    final resolvedIsRanked = (isRankedCol == true) || decoded.isRanked;

    return GameGroup(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] as String,
      description: decoded.description,
      coverGameId: (map['cover_game_id'] as num?)?.toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isRanked: resolvedIsRanked,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      items: items,
      gameCount: gameCount,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (coverGameId != null) 'cover_game_id': coverGameId,
      'sort_order': sortOrder,
      'is_ranked': isRanked,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'description': description,
      if (coverGameId != null) 'cover_game_id': coverGameId,
      'sort_order': sortOrder,
      'is_ranked': isRanked,
    };
  }
}
