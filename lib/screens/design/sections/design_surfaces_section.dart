import 'package:flutter/material.dart';

import '../../../widgets/design/corpus_badge.dart';
import '../../../widgets/design/corpus_card.dart';
import '../../../widgets/design/corpus_list_tile.dart';
import '../../../widgets/design/corpus_section.dart';

class DesignSurfacesSection extends StatelessWidget {
  const DesignSurfacesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Card',
          subtitle: 'Superficie con elevación o panel P5R según el pack.',
          child: CorpusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Witcher 3',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RPG de mundo abierto — 120 h',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'List tile',
          subtitle: 'Filas de ajustes y navegación.',
          child: Column(
            children: [
              CorpusListTile(
                icon: Icons.palette_outlined,
                title: 'Apariencia',
                subtitle: 'Modo, color y style pack',
                onTap: () {},
              ),
              CorpusListTile(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones',
                subtitle: 'Push y avisos en app',
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Badges',
          subtitle: 'Etiquetas de score y estado.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CorpusBadge.metacritic(92),
              CorpusBadge.metacritic(68),
              CorpusBadge.metacritic(42),
              CorpusBadge(
                label: 'Jugando',
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                foregroundColor: cs.primary,
              ),
              const CorpusBadge(label: 'Nuevo'),
            ],
          ),
        ),
      ],
    );
  }
}
