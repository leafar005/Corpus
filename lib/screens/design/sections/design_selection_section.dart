import 'package:flutter/material.dart';

import '../../../widgets/design/corpus_chip.dart';
import '../../../widgets/design/corpus_section.dart';
import '../../../widgets/design/corpus_slider.dart';
import '../../../widgets/design/corpus_switch.dart';

class DesignSelectionSection extends StatefulWidget {
  const DesignSelectionSection({super.key});

  @override
  State<DesignSelectionSection> createState() => _DesignSelectionSectionState();
}

class _DesignSelectionSectionState extends State<DesignSelectionSection> {
  int _statusIndex = 0;
  final _statuses = ['Jugando', 'Completado', 'Wishlist', 'Abandonado'];
  bool _filterMetacritic = true;
  bool _notifications = true;
  double _rating = 7.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Chips',
          subtitle: 'Choice, filter y action.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_statuses.length, (i) {
                  return CorpusChip(
                    label: _statuses[i],
                    selected: _statusIndex == i,
                    variant: CorpusChipVariant.choice,
                    onTap: () => setState(() => _statusIndex = i),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CorpusChip(
                    label: 'Metacritic',
                    selected: _filterMetacritic,
                    variant: CorpusChipVariant.filter,
                    onTap: () =>
                        setState(() => _filterMetacritic = !_filterMetacritic),
                  ),
                  CorpusChip(
                    label: 'Co-op',
                    variant: CorpusChipVariant.filter,
                    onTap: () {},
                  ),
                  CorpusChip(
                    label: 'Aplicar filtros',
                    variant: CorpusChipVariant.action,
                    icon: Icons.tune,
                    showCheckmark: false,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Switch',
          subtitle: 'Preferencias y toggles.',
          child: CorpusSwitch(
            label: 'Notificaciones push',
            subtitle: 'Avisos de actividad y logros',
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Slider',
          subtitle: 'Ratings y valores numéricos.',
          child: CorpusSlider(
            value: _rating,
            min: 0,
            max: 10,
            divisions: 20,
            label: 'Puntuación global',
            labelBuilder: (v) => 'Puntuación: ${v.toStringAsFixed(1)}',
            onChanged: (v) => setState(() => _rating = v),
          ),
        ),
      ],
    );
  }
}
