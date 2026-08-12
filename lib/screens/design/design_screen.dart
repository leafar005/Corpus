import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../theme/style_pack_registry.dart';
import '../../widgets/design/corpus_button.dart';

/// Living style guide — components and rules are added here incrementally.
class DesignScreen extends StatelessWidget {
  const DesignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pack = themeNotifier.currentPack;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Design System',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pack activo: ${pack.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _Section(
                    title: 'Variantes',
                    subtitle: 'Morado primario, acento, outline y ghost.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        CorpusButton(
                          label: 'Primario',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Acento',
                          variant: CorpusButtonVariant.accent,
                          icon: Icons.star_rounded,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Secundario',
                          variant: CorpusButtonVariant.secondary,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Outline',
                          variant: CorpusButtonVariant.outline,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Ghost',
                          variant: CorpusButtonVariant.ghost,
                          onPressed: () {},
                        ),
                        const CorpusButton(
                          label: 'Deshabilitado',
                          onPressed: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  _Section(
                    title: 'Tamaños',
                    subtitle: 'Small, medium y large con la misma variante.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CorpusButton(
                          label: 'Small',
                          size: CorpusButtonSize.small,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Medium',
                          size: CorpusButtonSize.medium,
                          onPressed: () {},
                        ),
                        CorpusButton(
                          label: 'Large',
                          size: CorpusButtonSize.large,
                          icon: Icons.arrow_forward_rounded,
                          iconTrailing: true,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  _Section(
                    title: 'Ancho completo',
                    subtitle: 'Para CTAs en formularios y modales.',
                    child: CorpusButton(
                      label: 'Continuar',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(height: 36),
                  _Section(
                    title: 'Style packs',
                    subtitle:
                        'Cambia el pack en Apariencia o con ?style=persona5 en la URL.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in StylePackRegistry.all)
                          ActionChip(
                            label: Text(p.name),
                            onPressed: () => themeNotifier.setStylePack(p.id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black45,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
