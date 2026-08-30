import 'package:flutter/material.dart';

import '../../../widgets/design/corpus_section.dart';
import '../../../widgets/design/corpus_tabs.dart';

class DesignNavigationSection extends StatefulWidget {
  const DesignNavigationSection({super.key});

  @override
  State<DesignNavigationSection> createState() =>
      _DesignNavigationSectionState();
}

class _DesignNavigationSectionState extends State<DesignNavigationSection> {
  int _tab = 0;

  static const _labels = ['Info', 'Comunidad', 'Media', 'Relacionados'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CorpusSection(
      title: 'Tabs',
      subtitle:
          'Pestañas conectadas al panel de contenido. En móvil el header hace scroll horizontal.',
      child: CorpusTabs(
        labels: _labels,
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contenu ${_tab + 1}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              _demoBody(_tab),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _demoBody(int index) => switch (index) {
    0 =>
      'Ficha del juego: metadatos, plataformas, duración estimada y enlaces externos.',
    1 => 'Reseñas de la comunidad, valoraciones y actividad de amigos.',
    2 => 'Capturas, vídeos y arte promocional del título.',
    3 => 'Secuelas, expansiones y juegos del mismo desarrollador o saga.',
    _ => '',
  };
}
