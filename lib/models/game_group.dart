import 'package:flutter/foundation.dart';
import 'game.dart';
import 'game_group_item.dart';

const Object _sentinel = Object();

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

  List<Game> get previewGames {
    if (items.isEmpty) return const [];
    final out = <Game>[];
    for (final item in items) {
      final g = item.game;
      if (g != null) {
        out.add(g);
        if (out.length == 4) break;
      }
    }
    return out;
  }

  Game? get coverGame {
    Game? firstGame;
    for (final item in items) {
      final g = item.game;
      if (g == null) continue;
      if (coverGameId != null && item.gameId == coverGameId) return g;
      firstGame ??= g;
    }
    return firstGame;
  }

  GameGroup copyWith({
    String? id,
    String? userId,
    String? name,
    Object? description = _sentinel,
    Object? coverGameId = _sentinel,
    int? sortOrder,
    bool? isRanked,
    Object? createdAt = _sentinel,
    List<GameGroupItem>? items,
    int? gameCount,
  }) {
    return GameGroup(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      coverGameId: identical(coverGameId, _sentinel)
          ? this.coverGameId
          : coverGameId as int?,
      sortOrder: sortOrder ?? this.sortOrder,
      isRanked: isRanked ?? this.isRanked,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      items: items != null
          ? List<GameGroupItem>.unmodifiable(items)
          : this.items,
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
    final trimmed = rawDescription.trim();
    return (
      description: trimmed.isEmpty ? null : trimmed,
      isRanked: false,
    );
  }

  factory GameGroup.fromMap(Map<String, dynamic> map) {
    final rawItems = map['game_group_items'];
    final parsedItems = <GameGroupItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) {
          parsedItems.add(
            GameGroupItem.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final items = parsedItems.isEmpty
        ? const <GameGroupItem>[]
        : List<GameGroupItem>.unmodifiable(parsedItems);

    final countRaw = map['game_count'];
    final gameCount = countRaw is num
        ? countRaw.toInt()
        : (int.tryParse(countRaw?.toString() ?? '') ?? items.length);

    final decoded = decodeRankedDescription(map['description']?.toString());
    final isRankedCol = map['is_ranked'] == true;
    final resolvedIsRanked = isRankedCol || decoded.isRanked;
    final rawCreatedAt = map['created_at'];

    return GameGroup(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: decoded.description,
      coverGameId:
          (map['cover_game_id'] as num?)?.toInt() ??
          int.tryParse(map['cover_game_id']?.toString() ?? ''),
      sortOrder:
          (map['sort_order'] as num?)?.toInt() ??
          int.tryParse(map['sort_order']?.toString() ?? '') ??
          0,
      isRanked: resolvedIsRanked,
      createdAt: rawCreatedAt is DateTime
          ? rawCreatedAt
          : (rawCreatedAt != null
                ? DateTime.tryParse(rawCreatedAt.toString())
                : null),
      items: items,
      gameCount: gameCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          description == other.description &&
          coverGameId == other.coverGameId &&
          sortOrder == other.sortOrder &&
          isRanked == other.isRanked &&
          createdAt == other.createdAt &&
          gameCount == other.gameCount &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    description,
    coverGameId,
    sortOrder,
    isRanked,
    createdAt,
    gameCount,
    Object.hashAll(items),
  );
}
