import 'package:flutter/foundation.dart';
import 'game.dart';
import 'game_status.dart';

const Object _sentinel = Object();

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
    Object? note = _sentinel,
    Object? createdAt = _sentinel,
    Object? game = _sentinel,
    Object? libraryStatus = _sentinel,
  }) {
    return GameGroupItem(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      gameId: gameId ?? this.gameId,
      sortOrder: sortOrder ?? this.sortOrder,
      note: identical(note, _sentinel) ? this.note : note as String?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      game: identical(game, _sentinel) ? this.game : game as Game?,
      libraryStatus: identical(libraryStatus, _sentinel)
          ? this.libraryStatus
          : libraryStatus as GameStatus?,
    );
  }

  factory GameGroupItem.fromMap(
    Map<String, dynamic> map, {
    GameStatus? libraryStatus,
  }) {
    Game? game;
    final rawGame = map['games'];
    if (rawGame is Map) {
      game = Game.fromMap(Map<String, dynamic>.from(rawGame));
    }

    GameStatus? status = libraryStatus;
    if (status == null && map['library_status'] != null) {
      status = GameStatus.fromStringOrDefault(
        map['library_status']?.toString(),
      );
    }

    final rawCreatedAt = map['created_at'];

    return GameGroupItem(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      gameId:
          (map['game_id'] as num?)?.toInt() ??
          int.tryParse(map['game_id']?.toString() ?? '') ??
          0,
      sortOrder:
          (map['sort_order'] as num?)?.toInt() ??
          int.tryParse(map['sort_order']?.toString() ?? '') ??
          0,
      note: map['note']?.toString(),
      createdAt: rawCreatedAt is DateTime
          ? rawCreatedAt
          : (rawCreatedAt != null
                ? DateTime.tryParse(rawCreatedAt.toString())
                : null),
      game: game,
      libraryStatus: status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameGroupItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          gameId == other.gameId &&
          sortOrder == other.sortOrder &&
          note == other.note &&
          createdAt == other.createdAt &&
          game == other.game &&
          libraryStatus == other.libraryStatus;

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    gameId,
    sortOrder,
    note,
    createdAt,
    game,
    libraryStatus,
  );
}
