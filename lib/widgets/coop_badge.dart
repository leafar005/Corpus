import 'package:flutter/material.dart';
import '../theme/corpus_theme_extension.dart';

class CoopBadge extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double size;
  final String? status;

  const CoopBadge({
    super.key,
    required this.username,
    this.avatarUrl,
    this.size = 24.0,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final text = status == 'playing'
        ? 'Jugando con @$username'
        : 'Jugado con @$username';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: avatarUrl == null
                ? Icon(
                    Icons.person,
                    size: size * 0.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
