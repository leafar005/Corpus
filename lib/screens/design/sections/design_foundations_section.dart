import 'package:flutter/material.dart';

import '../../../theme/corpus_theme_extension.dart';
import '../../../theme/corpus_typography.dart';
import '../../../widgets/corpus_section_title.dart';
import '../../../widgets/design/corpus_section.dart';

class DesignFoundationsSection extends StatelessWidget {
  const DesignFoundationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Paleta',
          subtitle: 'ColorScheme del pack activo.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch('Primary', cs.primary, cs.onPrimary),
              _ColorSwatch('Secondary', cs.secondary, cs.onSecondary),
              _ColorSwatch('Surface', cs.surface, cs.onSurface),
              _ColorSwatch('Error', cs.error, cs.onError),
              _ColorSwatch('Accent (pack)', cs.secondary, cs.onSecondary),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Tipografía',
          subtitle: 'Escala y variantes pack-aware.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CorpusSectionTitle('Section Title'),
              const SizedBox(height: 12),
              const CorpusHeroTitle(
                prefix: 'Bienvenido, ',
                highlight: 'jugador',
              ),
              const SizedBox(height: 16),
              Text('Body large', style: textTheme.bodyLarge),
              Text('Body medium', style: textTheme.bodyMedium),
              Text('Label small', style: textTheme.labelSmall),
              const SizedBox(height: 12),
              Text(
                'Display (pack)',
                style: CorpusTypography.display(
                  context,
                  ext,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Radios y formas',
          subtitle: 'Tokens de [CorpusThemeExtension].',
          child: Row(
            children: [
              _RadiusDemo('Small', ext.radiusSmall),
              const SizedBox(width: 12),
              _RadiusDemo('Medium', ext.radiusMedium),
              const SizedBox(width: 12),
              _RadiusDemo('Large', ext.radiusLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _ColorSwatch(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          alignment: Alignment.center,
          child: Text(label[0], style: TextStyle(color: fg, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _RadiusDemo extends StatelessWidget {
  final String label;
  final BorderRadius radius;

  const _RadiusDemo(this.label, this.radius);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: radius,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
