import 'package:flutter/material.dart';

/// Widget que renderiza texto de comentarios detectando menciones `@usuario`.
///
/// Las menciones se muestran en negrita con el color primario del tema actual.
/// Si el texto no contiene ninguna mención, se renderiza como un [Text] simple.
///
/// Uso:
/// ```dart
/// MentionText(text: comment['content'])
/// ```
class MentionText extends StatelessWidget {
  const MentionText({super.key, required this.text, this.style});

  final String text;

  /// Estilo base aplicado al texto no-mención. Si es null, hereda
  /// el DefaultTextStyle del contexto con fontSize: 14, height: 1.4.
  final TextStyle? style;

  static final RegExp _mentionRegex = RegExp(r'(@\w+)');

  @override
  Widget build(BuildContext context) {
    final matches = _mentionRegex.allMatches(text);

    final baseStyle = (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontSize: style?.fontSize ?? 14,
      height: style?.height ?? 1.4,
    );

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    int currentIndex = 0;
    final spans = <TextSpan>[];

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
