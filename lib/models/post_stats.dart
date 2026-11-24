import 'package:flutter/foundation.dart';

@immutable
class PostStats {
  final String postId;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;

  const PostStats({
    required this.postId,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
  });

  PostStats copyWith({
    String? postId,
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
  }) => PostStats(
    postId: postId ?? this.postId,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );

  factory PostStats.fromMap(Map<String, dynamic> m) => PostStats(
    postId: m['post_id']?.toString() ?? '',
    likesCount:
        (m['likes_count'] as num?)?.toInt() ??
        int.tryParse(m['likes_count']?.toString() ?? '') ??
        0,
    commentsCount:
        (m['comments_count'] as num?)?.toInt() ??
        int.tryParse(m['comments_count']?.toString() ?? '') ??
        0,
    likedByMe: m['liked_by_me'] == true,
  );

  static PostStats? fromDynamic(dynamic raw, {String? fallbackPostId}) {
    if (raw is PostStats) return raw;
    if (raw is Map<String, dynamic>) return PostStats.fromMap(raw);
    if (raw is Map) {
      return PostStats.fromMap(Map<String, dynamic>.from(raw));
    }
    if (fallbackPostId != null && fallbackPostId.isNotEmpty) {
      return PostStats(postId: fallbackPostId);
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'post_id': postId,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'liked_by_me': likedByMe,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostStats &&
          runtimeType == other.runtimeType &&
          postId == other.postId &&
          likesCount == other.likesCount &&
          commentsCount == other.commentsCount &&
          likedByMe == other.likedByMe;

  @override
  int get hashCode => Object.hash(postId, likesCount, commentsCount, likedByMe);
}
