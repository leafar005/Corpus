/// Helpers for shortening long game titles in P5R compact headers ([P5rRansomTitle]).
library;

/// Matches [P5rRansomTitle.maxWordsPerLine] — more words triggers multi-line layout.
const int kGameTitleMaxWordsPerLine = 2;

/// Character count above which a title is abbreviated in compact headers.
const int kGameTitleMaxChars = 18;

final RegExp _gameTitleSegmentSplit = RegExp(r'\s*[:;]\s*|\s+[-–—]\s+');
final RegExp _gameTitleWordSplit = RegExp(r'\s+');
final RegExp _gameTitleDigitsOnly = RegExp(r'^\d+$');
final RegExp _gameTitleStripPunctuation = RegExp(r'^[^\w\d]+|[^\w\d]+$');

/// Returns [title] unchanged when it fits a single compact header line; otherwise initials.
///
/// Examples: `PERSONA 5 ROYAL` → `P5R`, `Far Cry; Primal` → `FC:P`, `Kirby` → `Kirby`.
String abbreviateGameTitleIfNeeded(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!gameTitleNeedsAbbreviation(trimmed)) return trimmed;
  return abbreviateGameTitle(trimmed);
}

/// Whether a title should be abbreviated for compact header display.
bool gameTitleNeedsAbbreviation(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return false;

  final words = _splitWords(trimmed);
  if (words.length > kGameTitleMaxWordsPerLine) return true;
  if (trimmed.length > kGameTitleMaxChars) return true;
  if (words.length == 1 && words.first.length > kGameTitleMaxChars) return true;

  return false;
}

/// Builds initials from a game title (always abbreviated).
String abbreviateGameTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return trimmed;

  final segments = trimmed
      .split(_gameTitleSegmentSplit)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (segments.isEmpty) return trimmed;

  final parts = segments.map(_abbreviateSegment).where((s) => s.isNotEmpty);
  return parts.join(':');
}

List<String> _splitWords(String text) {
  return text
      .split(_gameTitleWordSplit)
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();
}

String _abbreviateSegment(String segment) {
  final parts = <String>[];

  for (final word in _splitWords(segment)) {
    final cleaned = word.replaceAll(_gameTitleStripPunctuation, '');
    if (cleaned.isEmpty) continue;

    if (_gameTitleDigitsOnly.hasMatch(cleaned)) {
      parts.add(cleaned);
    } else {
      parts.add(cleaned[0].toUpperCase());
    }
  }

  return parts.join();
}
