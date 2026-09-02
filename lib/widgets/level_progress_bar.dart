import 'package:flutter/material.dart';
import 'package:corpus/utils/level_calculator.dart';
import '../theme/corpus_theme_extension.dart';

class LevelProgressBar extends StatelessWidget {
  final int xp;
  final bool compact;
  final VoidCallback? onTap;

  const LevelProgressBar({
    super.key,
    required this.xp,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelLabelSize = compact ? 13.0 : 15.0;
    final progressLabelSize = compact ? 12.0 : 13.0;
    final barHeight = compact ? 6.0 : 8.0;
    final spacing = compact ? 4.0 : 6.0;

    return InkWell(
      borderRadius: Theme.of(
        context,
      ).extension<CorpusThemeExtension>()!.radiusSmall,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nivel ${LevelCalculator.getLevel(xp)}',
                style: TextStyle(
                  fontSize: levelLabelSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                LevelCalculator.getProgressString(xp),
                style: TextStyle(
                  fontSize: progressLabelSize,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          ClipRRect(
            borderRadius: Theme.of(
              context,
            ).extension<CorpusThemeExtension>()!.radiusSmall,
            child: LinearProgressIndicator(
              value: LevelCalculator.getProgressFraction(xp),
              minHeight: barHeight,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
