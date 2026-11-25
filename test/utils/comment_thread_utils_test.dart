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
      expect(ordered[2]['_reply_to_username'], 'alice');
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
      expect(ordered[1]['_reply_to_username'], 'alice');
    });

    test('tolera created_at nulo/inválido y mantiene mención desconocida en raíz (BUG-22, OPT-32)', () {
      final comments = [
        {
          'id': 'c1',
          'created_at': null,
          'content': 'comentario sin fecha',
          'users': {'username': 'alice'},
        },
        {
          'id': 'c2',
          'created_at': 'fecha-corrupta',
          'content': '@nadie_conocido saludo al vacío',
          'users': {'username': 'bob'},
        },
        {
          'id': 'c3',
          'created_at': '2026-08-14T12:00:00Z',
          'content': '@alice respuesta válida',
          'users': {'username': 'carol'},
        },
      ];

      final ordered = orderCommentsThreaded(comments);
      expect(ordered, hasLength(3));

      final byId = {for (final c in ordered) c['id']: c};
      // Mención desconocida queda como comentario raíz (_thread_depth == 0), nunca bajo c1.
      expect(byId['c2']?['_thread_depth'], 0);
      expect(byId['c3']?['_thread_depth'], 1);
      expect(byId['c3']?['_reply_to_username'], 'alice');
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
