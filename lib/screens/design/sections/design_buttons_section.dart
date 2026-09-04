import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../../widgets/design/corpus_button.dart';
import '../../../widgets/design/corpus_icon_button.dart';
import '../../../widgets/design/corpus_section.dart';

class DesignButtonsSection extends StatelessWidget {
  const DesignButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Variantes',
          subtitle: 'Primario, acento, secundario, outline y ghost.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              CorpusButton(
                label: 'Primario',
                icon: CorpusIconKind.PlayArrowRounded,
                onPressed: () {},
              ),
              CorpusButton(
                label: 'Acento',
                variant: CorpusButtonVariant.accent,
                icon: CorpusIconKind.StarRounded,
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
              const CorpusButton(label: 'Deshabilitado', onPressed: null),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Tamaños',
          subtitle: 'Small, medium y large.',
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
                icon: CorpusIconKind.ArrowForwardRounded,
                iconTrailing: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Ancho completo',
          subtitle: 'CTAs en formularios y modales.',
          child: CorpusButton(
            label: 'Continuar',
            icon: CorpusIconKind.CheckRounded,
            expand: true,
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Icon buttons',
          subtitle: 'Con cursor pointer en desktop.',
          child: Row(
            children: [
              CorpusIconButton(
                icon: CorpusIconKind.FavoriteBorder,
                tooltip: 'Favorito',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              CorpusIconButton(
                icon: CorpusIconKind.Share,
                tooltip: 'Compartir',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              const CorpusIconButton(icon: CorpusIconKind.Block, onPressed: null),
            ],
          ),
        ),
      ],
    );
  }
}
