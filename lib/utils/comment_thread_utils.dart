/// Utilities for ordering and displaying threaded review comments.
library;

final RegExp _mentionPrefixRegex = RegExp(r'^@(\w+)');
final DateTime _epochUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DateTime _parseCreatedAtSafe(dynamic raw) {
  if (raw == null) return _epochUtc;
  final parsed = DateTime.tryParse(raw.toString());
  return parsed?.toUtc() ?? _epochUtc;
}

String? _readAuthorUsername(Map<String, dynamic>? comment) {
  if (comment == null) return null;
  final users = comment['users'];
  if (users is! Map) return null;
  final name = users['username']?.toString().trim();
  return (name == null || name.isEmpty) ? null : name;
}

/// Orders comments depth-first in `O(N log N)` so replies appear directly
/// under their parent.
///
/// Infers parent links for legacy rows that only use an `@username` prefix when
/// `parent_comment_id` is null. Unknown mentions remain top-level roots.
List<Map<String, dynamic>> orderCommentsThreaded(
  List<Map<String, dynamic>> comments,
) {
  if (comments.isEmpty) return const [];

  final byId = <String, Map<String, dynamic>>{};
  final indexed = <({Map<String, dynamic> comment, DateTime createdAt, int index})>[];

  for (var i = 0; i < comments.length; i++) {
    final comment = comments[i];
    final id = comment['id']?.toString();
    if (id != null && id.isNotEmpty) {
      byId[id] = comment;
    }
    indexed.add((
      comment: comment,
      createdAt: _parseCreatedAtSafe(comment['created_at']),
      index: i,
    ));
  }

  indexed.sort((a, b) {
    final cmp = a.createdAt.compareTo(b.createdAt);
    return cmp != 0 ? cmp : a.index.compareTo(b.index);
  });

  final sorted = <Map<String, dynamic>>[];
  final inferredParent = <String, String?>{};
  final priorByUsername =
      <String, List<({String id, DateTime createdAt})>>{};

  for (final entry in indexed) {
    final comment = entry.comment;
    sorted.add(comment);

    final id = comment['id']?.toString();
    if (id != null && id.isNotEmpty) {
      final storedParent = comment['parent_comment_id']?.toString();
      if (storedParent != null &&
          storedParent != id &&
          byId.containsKey(storedParent)) {
        inferredParent[id] = storedParent;
      } else {
        final mentioned = _inferMentionedUsername(comment)?.toLowerCase();
        String? matchedParent;
        if (mentioned != null) {
          final candidates = priorByUsername[mentioned];
          if (candidates != null) {
            for (var j = candidates.length - 1; j >= 0; j--) {
              if (candidates[j].createdAt.isBefore(entry.createdAt)) {
                matchedParent = candidates[j].id;
                break;
              }
            }
          }
        }
        inferredParent[id] = matchedParent;
      }

      final authorUsername = _readAuthorUsername(comment)?.toLowerCase();
      if (authorUsername != null) {
        priorByUsername
            .putIfAbsent(authorUsername, () => [])
            .add((id: id, createdAt: entry.createdAt));
      }
    }
  }

  final byParent = <String?, List<Map<String, dynamic>>>{};
  for (final comment in sorted) {
    final id = comment['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final parentId = inferredParent[id];
    byParent.putIfAbsent(parentId, () => []).add(comment);
  }

  final result = <Map<String, dynamic>>[];
  final visited = <String>{};

  void visit(String? parentId, int depth) {
    final children = byParent[parentId];
    if (children == null) return;

    for (final comment in children) {
      final id = comment['id']?.toString();
      if (id == null || id.isEmpty || visited.contains(id)) continue;
      visited.add(id);

      String? replyToUsername;
      if (parentId != null) {
        replyToUsername = _readAuthorUsername(byId[parentId]);
      }
      replyToUsername ??= _inferMentionedUsername(comment);

      result.add({
        ...comment,
        '_thread_depth': depth,
        if (depth > 0 && replyToUsername != null)
          '_reply_to_username': replyToUsername,
      });
      visit(id, depth + 1);
    }
  }

  visit(null, 0);

  for (final comment in sorted) {
    final id = comment['id']?.toString();
    if (id == null || id.isEmpty || visited.contains(id)) continue;
    final parentId = inferredParent[id];
    String? replyToUsername;
    if (parentId != null) {
      replyToUsername = _readAuthorUsername(byId[parentId]);
    }
    replyToUsername ??= _inferMentionedUsername(comment);

    result.add({
      ...comment,
      '_thread_depth': 0,
      if (replyToUsername != null) '_reply_to_username': replyToUsername,
    });
  }

  return result;
}

String? _inferMentionedUsername(Map<String, dynamic> comment) {
  final content = comment['content']?.toString().trim() ?? '';
  final mentionMatch = _mentionPrefixRegex.firstMatch(content);
  return mentionMatch?.group(1);
}
