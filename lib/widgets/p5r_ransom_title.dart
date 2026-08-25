import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// P5R menu-style title: mixed fonts per letter, black cut-out halo, slight jitter.
class P5rRansomTitle extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final Color color;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  const P5rRansomTitle({
    super.key,
    required this.text,
    this.baseFontSize = 24,
    this.color = Colors.white,
    this.compact = false,
    this.padding,
  });

  static const int maxWordsPerLine = 2;

  static final RegExp _accentPattern = RegExp(
    r'[àáâãäåæçèéêëìíîïñòóôõöùúûüýÿ]',
    caseSensitive: false,
  );

  static const int _maxWordsPerLine = maxWordsPerLine;

  @override
  Widget build(BuildContext context) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return const SizedBox.shrink();

    final startIndices = <int>[];
    var offset = 0;
    for (final word in words) {
      startIndices.add(offset);
      offset += word.length;
    }

    final lineGroups = <List<int>>[];
    for (int i = 0; i < words.length; i += _maxWordsPerLine) {
      final end = i + _maxWordsPerLine > words.length
          ? words.length
          : i + _maxWordsPerLine;
      lineGroups.add([for (int j = i; j < end; j++) j]);
    }

    return Padding(
      padding:
          padding ??
          (compact
              ? const EdgeInsets.fromLTRB(0, 2, 4, 2)
              : const EdgeInsets.fromLTRB(6, 4, 10, 8)),
      child: Transform.rotate(
        angle: compact ? -0.02 : -0.025,
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int line = 0; line < lineGroups.length; line++)
              Padding(
                padding: EdgeInsets.only(
                  left: compact ? 0 : (line % 2) * 8.0,
                  bottom: line < lineGroups.length - 1 ? 4 : 0,
                ),
                child: _RansomLine(
                  words: lineGroups[line]
                      .map((i) => words[i].toUpperCase())
                      .toList(),
                  startIndices: lineGroups[line]
                      .map((i) => startIndices[i])
                      .toList(),
                  baseFontSize: baseFontSize,
                  color: color,
                  compact: compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static TextStyle _letterStyle(
    int index,
    String char,
    double baseSize,
    Color color,
  ) {
    if (_accentPattern.hasMatch(char)) {
      return GoogleFonts.notoSans(
        fontSize: baseSize,
        color: color,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );
    }

    switch (index % 5) {
      case 0:
        return GoogleFonts.notoSerif(
          fontSize: baseSize * 0.95,
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.0,
        );
      case 1:
        return GoogleFonts.oswald(
          fontSize: baseSize * 1.08,
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.0,
        );
      case 2:
        return GoogleFonts.archivoBlack(
          fontSize: baseSize * 1.12,
          color: color,
          height: 1.0,
        );
      case 3:
        return GoogleFonts.robotoSlab(
          fontSize: baseSize * 0.92,
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.0,
        );
      case 4:
        return GoogleFonts.jost(
          fontSize: baseSize,
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.0,
        );
      default:
        return TextStyle(fontSize: baseSize, color: color, height: 1.0);
    }
  }

  static double _letterRotation(int index) {
    const rotations = [0.0, 0.05, -0.04, 0.035, -0.05, 0.025];
    return rotations[index % rotations.length];
  }

  static double _letterYOffset(int index) {
    const offsets = [0.0, -1.5, 1.0, -0.8, 1.5, -1.0];
    return offsets[index % offsets.length];
  }

  static double _letterBoxWidth(double baseFontSize, {bool compact = false}) =>
      baseFontSize * (compact ? 0.92 : 0.72);

  static double _letterBoxHeight(double baseFontSize) => baseFontSize * 1.32;
}

class _RansomLine extends StatelessWidget {
  final List<String> words;
  final List<int> startIndices;
  final double baseFontSize;
  final Color color;
  final bool compact;

  const _RansomLine({
    required this.words,
    required this.startIndices,
    required this.baseFontSize,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final wordGap = baseFontSize * (compact ? 0.75 : 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < words.length; i++) ...[
          if (i > 0) SizedBox(width: wordGap),
          _RansomWord(
            word: words[i],
            startIndex: startIndices[i],
            baseFontSize: baseFontSize,
            color: color,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class _RansomWord extends StatelessWidget {
  final String word;
  final int startIndex;
  final double baseFontSize;
  final Color color;
  final bool compact;

  const _RansomWord({
    required this.word,
    required this.startIndex,
    required this.baseFontSize,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(1, 1, 1, 2)
          : const EdgeInsets.fromLTRB(4, 1, 2, 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: const Offset(2, 2),
            child: _LetterRow(
              word: word,
              startIndex: startIndex,
              baseFontSize: baseFontSize,
              color: Colors.black,
              compact: compact,
            ),
          ),
          Transform.translate(
            offset: const Offset(-1, 1),
            child: _LetterRow(
              word: word,
              startIndex: startIndex,
              baseFontSize: baseFontSize,
              color: Colors.black,
              compact: compact,
            ),
          ),
          _LetterRow(
            word: word,
            startIndex: startIndex,
            baseFontSize: baseFontSize,
            color: color,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  final String word;
  final int startIndex;
  final double baseFontSize;
  final Color color;
  final bool compact;

  const _LetterRow({
    required this.word,
    required this.startIndex,
    required this.baseFontSize,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final boxW = P5rRansomTitle._letterBoxWidth(baseFontSize, compact: compact);
    final boxH = P5rRansomTitle._letterBoxHeight(baseFontSize);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < word.length; i++)
          SizedBox(
            width: boxW,
            height: boxH,
            child: Center(
              child: Transform.rotate(
                angle: P5rRansomTitle._letterRotation(startIndex + i),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    P5rRansomTitle._letterYOffset(startIndex + i),
                  ),
                  child: Text(
                    word[i],
                    textAlign: TextAlign.center,
                    style: P5rRansomTitle._letterStyle(
                      startIndex + i,
                      word[i],
                      baseFontSize,
                      color,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
