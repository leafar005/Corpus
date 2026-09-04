import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

/// Avatar circular con anillo de gradiente (estilo stories) cuando [hasStory].
///
/// Usa [ColorScheme.primary] y [ColorScheme.secondary] del tema activo para
/// compatibilidad con Style Packs.
class ActivityStoryRing extends StatelessWidget {
  const ActivityStoryRing({
    super.key,
    required this.radius,
    required this.hasStory,
    this.hasUnseenStory = true,
    this.avatarUrl,
    this.backgroundColor,
    this.ringWidth = 2.5,
    this.child,
  });

  final double radius;
  final bool hasStory;
  final bool hasUnseenStory;
  final String? avatarUrl;
  final Color? backgroundColor;
  final double ringWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? cs.surfaceContainerHighest,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child:
          child ??
          (avatarUrl == null ? CorpusTablerIcon(CorpusIconKind.Person, size: radius) : null),
    );

    if (!hasStory) {
      return Padding(
        padding: EdgeInsets.all(ringWidth + (ringWidth * 0.6)),
        child: avatar,
      );
    }

    final ringColor = hasUnseenStory ? cs.primary : cs.outlineVariant;

    return Container(
      padding: EdgeInsets.all(ringWidth * 0.6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ringWidth),
      ),
      child: avatar,
    );
  }
}
