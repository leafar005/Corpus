import 'package:corpus/utils/comment_thread_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orderCommentsThreaded', () {
    test('places replies directly under their inferred parent', () {
      final comments = [
        _comment(
          id: '1',
          createdAt: '2026-08-14T10:00:00Z',
          username: 'alice',
          content: 'root',
        ),
        _comment(
          id: '2',
          createdAt: '2026-08-14T10:01:00Z',
          username: 'alice',
          content: 'another root',
        ),
        _comment(
          id: '3',
          createdAt: '2026-08-14T10:02:00Z',
          username: 'bob',
          content: '@alice reply',
        ),
      ];

      final ordered = orderCommentsThreaded(comments);

      expect(ordered.map((c) => c['id']).toList(), ['1', '2', '3']);
      expect(ordered[2]['_thread_depth'], 1);
    });

    test('uses stored parent_comment_id when available', () {
      final comments = [
        _comment(
          id: '1',
          createdAt: '2026-08-14T10:00:00Z',
          username: 'alice',
          content: 'root',
        ),
        _comment(
          id: '2',
          createdAt: '2026-08-14T10:01:00Z',
          username: 'bob',
          content: 'reply',
          parentCommentId: '1',
        ),
      ];

      final ordered = orderCommentsThreaded(comments);

      expect(ordered.map((c) => c['id']).toList(), ['1', '2']);
      expect(ordered[1]['_thread_depth'], 1);
    });
  });
}

Map<String, dynamic> _comment({
  required String id,
  required String createdAt,
  required String username,
  required String content,
  String? parentCommentId,
}) {
  return {
    'id': id,
    'created_at': createdAt,
    'content': content,
    'parent_comment_id': ?parentCommentId,
    'users': {'username': username},
  };
}
