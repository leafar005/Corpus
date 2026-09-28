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
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      gameCount: gameCount ?? this.gameCount,
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

    return GameGroup(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      coverGameId: (map['cover_game_id'] as num?)?.toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
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
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'description': description,
      if (coverGameId != null) 'cover_game_id': coverGameId,
      'sort_order': sortOrder,
    };
  }
}
