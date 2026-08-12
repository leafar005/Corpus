import 'package:flutter/material.dart';

/// Avatar circular con anillo de gradiente (estilo stories) cuando [hasStory].
///
/// Usa [ColorScheme.primary] y [ColorScheme.secondary] del tema activo para
/// compatibilidad con Style Packs.
class ActivityStoryRing extends StatelessWidget {
  const ActivityStoryRing({
    super.key,
    required this.radius,
    required this.hasStory,
    this.avatarUrl,
    this.backgroundColor,
    this.ringWidth = 2.5,
    this.child,
  });

  final double radius;
  final bool hasStory;
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
      child: child ?? (avatarUrl == null ? Icon(Icons.person, size: radius) : null),
    );

    if (!hasStory) return avatar;

    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [cs.primary, cs.secondary, cs.primary],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(ringWidth * 0.6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surface,
        ),
        child: avatar,
      ),
    );
  }
}
