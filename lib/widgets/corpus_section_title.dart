import 'package:flutter/material.dart';

import '../theme/corpus_theme_extension.dart';
import '../theme/corpus_typography.dart';
import '../utils/game_title_utils.dart';
import 'p5r_ransom_title.dart';
import 'typewriter_text.dart';

/// App bar / screen heading — pack-aware typography for top-level screen titles.
class CorpusScreenTitle extends StatelessWidget {
  final String text;
  final bool abbreviateIfLong;
  /// Width of trailing AppBar actions to balance visual centering (e.g. 56 per icon).
  final double trailingBalanceWidth;

  const CorpusScreenTitle(
    this.text, {
    super.key,
    this.abbreviateIfLong = false,
    this.trailingBalanceWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final title = CorpusPackAwareTitle(text, abbreviateIfLong: abbreviateIfLong);

    if (!ext.useDynamicFrames) return title;

    return CorpusVisuallyBalancedTitle(
      trailingBalanceWidth: trailingBalanceWidth,
      child: title,
    );
  }
}

/// Shifts a P5R compact title so it sits on the true screen center when an AppBar
/// leading back button (or asymmetric actions) would otherwise push it right.
class CorpusVisuallyBalancedTitle extends StatelessWidget {
  final Widget child;
  final double trailingBalanceWidth;

  /// Matches [AppBar.leadingWidth] default.
  static const double defaultLeadingWidth = 56;

  const CorpusVisuallyBalancedTitle({
    super.key,
    required this.child,
    this.trailingBalanceWidth = 0,
  });

  /// Horizontal offset to visually center [child] on screen inside an AppBar title slot.
  static double computeOffset({
    required bool hasLeading,
    double leadingWidth = defaultLeadingWidth,
    double trailingBalanceWidth = 0,
  }) {
    final resolvedLeading = hasLeading ? leadingWidth : 0;
    return (resolvedLeading - trailingBalanceWidth) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final offset = computeOffset(
      hasLeading: Navigator.canPop(context),
      trailingBalanceWidth: trailingBalanceWidth,
    );

    if (offset == 0) return child;

    return Transform.translate(offset: Offset(-offset, 0), child: child);
  }
}

/// Pack-aware compact title for app bars and collapsed headers.
///
/// With the P5R style pack (`useDynamicFrames`), uses [P5rRansomTitle]. Game titles
/// can pass [abbreviateIfLong] to collapse long names into initials (e.g. P5R) in any pack.
/// Other packs use a single-line [Text] with ellipsis.
class CorpusPackAwareTitle extends StatelessWidget {
  final String text;
  final bool abbreviateIfLong;
  final double baseFontSize;
  final Color? color;

  const CorpusPackAwareTitle(
    this.text, {
    super.key,
    this.abbreviateIfLong = false,
    this.baseFontSize = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle;
    final resolvedColor = color ?? titleStyle?.color ?? Colors.white;
    final displayText =
        abbreviateIfLong ? abbreviateGameTitleIfNeeded(text) : text;

    if (ext.useDynamicFrames) {
      return P5rRansomTitle(
        text: displayText,
        baseFontSize: baseFontSize,
        color: resolvedColor,
        compact: true,
      );
    }

    return Text(
      displayText,
      style: titleStyle ??
          TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.bold,
            color: resolvedColor,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Standard section heading — picks pack-specific title treatment automatically.
///
/// Use this for section headers across the app so new style packs can swap
/// title rendering without touching every screen.
class CorpusSectionTitle extends StatelessWidget {
  final String text;
  final double? fontSize;

  const CorpusSectionTitle(this.text, {super.key, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    if (ext.useDynamicFrames) {
      return P5rRansomTitle(text: text, baseFontSize: fontSize ?? 24);
    }

    return Text(
      text,
      style: CorpusTypography.display(
        context,
        ext,
        fontSize: fontSize ?? 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Hero greeting title (e.g. "Bienvenido," + username) — pack-aware typography.
class CorpusHeroTitle extends StatelessWidget {
  final String prefix;
  final String highlight;
  final bool animated;
  final bool instant;
  final VoidCallback? onAnimationComplete;

  const CorpusHeroTitle({
    super.key,
    required this.prefix,
    required this.highlight,
    this.animated = false,
    this.instant = false,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    final baseSize = isPortrait ? ext.heroFontSize * 0.85 : ext.heroFontSize;
    final primary = Theme.of(context).colorScheme.primary;

    if (ext.useDynamicFrames) {
      if (animated) {
        const separator = '\n';
        return TypewriterText(
          instant: instant,
          onComplete: onAnimationComplete,
          spans: [TextSpan(text: '$prefix$separator$highlight')],
          customBuilder: (context, visible, finished) {
            final parts = _splitHeroVisible(prefix, highlight, visible);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parts.$1.isNotEmpty)
                  P5rRansomTitle(text: parts.$1, baseFontSize: baseSize * 0.82),
                if (parts.$2.isNotEmpty)
                  P5rRansomTitle(
                    text: parts.$2,
                    baseFontSize: baseSize,
                    color: primary,
                  ),
              ],
            );
          },
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          P5rRansomTitle(text: prefix, baseFontSize: baseSize * 0.82),
          P5rRansomTitle(
            text: highlight,
            baseFontSize: baseSize,
            color: primary,
          ),
        ],
      );
    }

    final baseStyle = CorpusTypography.display(
      context,
      ext,
      fontSize: baseSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

    if (animated) {
      return TypewriterText(
        instant: instant,
        onComplete: onAnimationComplete,
        style: baseStyle,
        spans: [
          TextSpan(
            text: '$prefix\n',
            style: baseStyle.copyWith(color: Colors.white),
          ),
          TextSpan(
            text: highlight,
            style: baseStyle.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
            text: '$prefix\n',
            style: baseStyle.copyWith(color: Colors.white),
          ),
          TextSpan(
            text: highlight,
            style: baseStyle.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Divide el texto visible del typewriter en prefijo y nombre destacado.
(String, String) _splitHeroVisible(
  String prefix,
  String highlight,
  String visible,
) {
  if (visible.length <= prefix.length) {
    return (visible, '');
  }
  if (visible.length <= prefix.length + 1) {
    return (prefix, '');
  }
  return (prefix, visible.substring(prefix.length + 1));
}
