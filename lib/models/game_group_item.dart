import 'package:flutter/foundation.dart';
import 'game.dart';
import 'game_status.dart';

@immutable
class GameGroupItem {
  const GameGroupItem({
    required this.id,
    required this.groupId,
    required this.gameId,
    this.sortOrder = 0,
    this.note,
    this.createdAt,
    this.game,
    this.libraryStatus,
  });

  final String id;
  final String groupId;
  final int gameId;
  final int sortOrder;
  final String? note;
  final DateTime? createdAt;
  final Game? game;
  final GameStatus? libraryStatus;

  bool get isCompleted =>
      libraryStatus == GameStatus.beaten ||
      libraryStatus == GameStatus.completed;

  bool get isPlaying => libraryStatus == GameStatus.playing;

  GameGroupItem copyWith({
    String? id,
    String? groupId,
    int? gameId,
    int? sortOrder,
    String? note,
    DateTime? createdAt,
    Game? game,
    GameStatus? libraryStatus,
  }) {
    return GameGroupItem(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      gameId: gameId ?? this.gameId,
      sortOrder: sortOrder ?? this.sortOrder,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      game: game ?? this.game,
      libraryStatus: libraryStatus ?? this.libraryStatus,
    );
  }

  factory GameGroupItem.fromMap(
    Map<String, dynamic> map, {
    GameStatus? libraryStatus,
  }) {
    Game? game;
    if (map['games'] != null) {
      game = Game.fromMap(Map<String, dynamic>.from(map['games'] as Map));
    }

    GameStatus? status = libraryStatus;
    if (status == null && map['library_status'] != null) {
      status = GameStatus.fromStringOrDefault(
        map['library_status'] as String?,
      );
    }

    return GameGroupItem(
      id: map['id'].toString(),
      groupId: map['group_id'].toString(),
      gameId: (map['game_id'] as num).toInt(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      game: game,
      libraryStatus: status,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'group_id': groupId,
      'game_id': gameId,
      'sort_order': sortOrder,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}
