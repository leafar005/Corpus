/// Utilities for ordering and displaying threaded review comments.
library;

/// Orders comments depth-first so replies appear directly under their parent.
///
/// Infers parent links for legacy rows that only use an `@username` prefix when
/// [parent_comment_id] is null.
List<Map<String, dynamic>> orderCommentsThreaded(
  List<Map<String, dynamic>> comments,
) {
  if (comments.isEmpty) return const [];

  final byId = <String, Map<String, dynamic>>{
    for (final comment in comments)
      if (comment['id'] != null) comment['id'] as String: comment,
  };

  final sorted = List<Map<String, dynamic>>.from(comments)
    ..sort(
      (a, b) => DateTime.parse(
        a['created_at'] as String,
      ).compareTo(DateTime.parse(b['created_at'] as String)),
    );

  final inferredParent = <String, String?>{};
  for (final comment in sorted) {
    final id = comment['id'] as String?;
    if (id == null) continue;

    final storedParent = comment['parent_comment_id'] as String?;
    if (storedParent != null && byId.containsKey(storedParent)) {
      inferredParent[id] = storedParent;
      continue;
    }

    inferredParent[id] = _inferParentId(comment, sorted, byId);
  }

  final byParent = <String?, List<Map<String, dynamic>>>{};
  for (final comment in sorted) {
    final id = comment['id'] as String?;
    if (id == null) continue;
    final parentId = inferredParent[id];
    byParent.putIfAbsent(parentId, () => []).add(comment);
  }

  final result = <Map<String, dynamic>>[];
  final visited = <String>{};

  void visit(String? parentId, int depth) {
    final children = byParent[parentId];
    if (children == null) return;

    for (final comment in children) {
      final id = comment['id'] as String?;
      if (id == null || visited.contains(id)) continue;
      visited.add(id);
      result.add({...comment, '_thread_depth': depth});
      visit(id, depth + 1);
    }
  }

  visit(null, 0);

  for (final comment in sorted) {
    final id = comment['id'] as String?;
    if (id == null || visited.contains(id)) continue;
    result.add({...comment, '_thread_depth': 0});
  }

  return result;
}

String? _inferParentId(
  Map<String, dynamic> comment,
  List<Map<String, dynamic>> sortedComments,
  Map<String, Map<String, dynamic>> byId,
) {
  final content = comment['content']?.toString().trim() ?? '';
  final mentionMatch = RegExp(r'^@(\w+)').firstMatch(content);
  if (mentionMatch == null) return null;

  final mentionedUsername = mentionMatch.group(1)!.toLowerCase();
  final createdAt = DateTime.parse(comment['created_at'] as String);

  Map<String, dynamic>? bestMatch;
  DateTime? bestMatchTime;

  for (final candidate in sortedComments) {
    if (identical(candidate, comment)) continue;

    final candidateId = candidate['id'] as String?;
    if (candidateId == null) continue;

    final candidateTime = DateTime.parse(candidate['created_at'] as String);
    if (!candidateTime.isBefore(createdAt)) continue;

    final username = (candidate['users'] as Map<String, dynamic>?)?['username']
        ?.toString()
        .toLowerCase();
    if (username != mentionedUsername) continue;

    if (bestMatch == null || candidateTime.isAfter(bestMatchTime!)) {
      bestMatch = candidate;
      bestMatchTime = candidateTime;
    }
  }

  if (bestMatch != null) {
    return bestMatch['id'] as String;
  }

  final firstRoot = sortedComments.firstWhere((candidate) {
    if (identical(candidate, comment)) return false;
    final parentId = candidate['parent_comment_id'] as String?;
    return parentId == null || !byId.containsKey(parentId);
  }, orElse: () => <String, dynamic>{});

  return firstRoot['id'] as String?;
}
