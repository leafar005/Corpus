import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'corpus_tabler_icon.dart';

/// Tabler filled SVG icons for the main bottom/top navigation bar.
class CorpusNavIcon extends StatelessWidget {
  const CorpusNavIcon({
    super.key,
    required this.tabIndex,
    this.exploreAsSearch = false,
    this.size,
    this.color,
  });

  final int tabIndex;
  final bool exploreAsSearch;
  final double? size;
  final Color? color;

  CorpusTablerIcon get _icon => switch (tabIndex) {
    0 => CorpusTablerIcon.home(size: size, color: color),
    1 when exploreAsSearch => CorpusTablerIcon.search(size: size, color: color),
    1 => CorpusTablerIcon.compass(size: size, color: color),
    2 => CorpusTablerIcon.users(size: size, color: color),
    3 => CorpusTablerIcon.gamepad(size: size, color: color),
    4 => CorpusTablerIcon.userFilled(size: size, color: color),
    _ => CorpusTablerIcon.info(size: size, color: color),
  };

  @override
  Widget build(BuildContext context) => _icon;
}

LiquidGlassGlyphBuilder corpusNavGlyphBuilder(
  int tabIndex, {
  bool exploreAsSearch = false,
}) {
  return (context, glyph) => CorpusNavIcon(
    tabIndex: tabIndex,
    exploreAsSearch: exploreAsSearch,
    color: glyph.color,
    size: glyph.size,
  );
}

LiquidGlassTabBarItem corpusNavTabItem(
  int tabIndex,
  String label, {
  bool exploreAsSearch = false,
}) {
  return LiquidGlassTabBarItem.custom(
    label: label,
    iconBuilder: corpusNavGlyphBuilder(
      tabIndex,
      exploreAsSearch: exploreAsSearch,
    ),
  );
}
