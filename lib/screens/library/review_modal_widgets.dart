import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import '../../theme/corpus_theme_extension.dart';

/// Slider de sub-rating reutilizable para la modal de reseñas.
///
/// Muestra un label con icono + slider de 0-10 con resolución 0.1 + valor numérico.
///
/// Extraído de `review_modal.dart` (Auditoría Fase 3, ADR-002).
class ReviewSubRatingSlider extends StatelessWidget {
  const ReviewSubRatingSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.formatRating,
  });

  final String label;
  final CorpusIconKind icon;
  final double value;
  final ValueChanged<double> onChanged;
  final String Function(double) formatRating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CorpusTablerIcon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0,
                max: 10,
                divisions: 100,
                activeColor: Theme.of(context).colorScheme.primary,
                label: value > 0 ? formatRating(value) : '-',
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                value > 0 ? formatRating(value) : '-',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip de selección estilizado para la modal de reseñas (estado, tipo de
/// completado, etc.).
///
/// Extraído de `review_modal.dart` (Auditoría Fase 3, ADR-002).
class ReviewChoiceChip extends StatelessWidget {
  const ReviewChoiceChip({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.currentValue,
    required this.color,
    required this.onSelected,
  });

  final String value;
  final String label;
  final CorpusIconKind icon;
  final String currentValue;
  final Color color;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentValue == value;
    final textColor = isSelected
        ? (color == Theme.of(context).colorScheme.secondary
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.white)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpusTablerIcon(
            icon,
            size: 18,
            color: isSelected
                ? textColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: color,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            Theme.of(context).extension<CorpusThemeExtension>()?.radiusLarge ??
            BorderRadius.circular(20),
      ),
      side: BorderSide(
        color: isSelected
            ? color
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      showCheckmark: false,
    );
  }
}

/// Imagen removible con botón X en la esquina.
///
/// Usado en la sección de capturas de la modal de reseñas.
///
/// Extraído de `review_modal.dart` (Auditoría Fase 3, ADR-002).
class RemovableImageCard extends StatelessWidget {
  const RemovableImageCard({
    super.key,
    required this.imageWidget,
    required this.onRemove,
  });

  final Widget imageWidget;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8),
          decoration: BoxDecoration(
            borderRadius:
                Theme.of(context)
                    .extension<CorpusThemeExtension>()
                    ?.radiusSmall ??
                BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: imageWidget,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const CorpusTablerIcon(CorpusIconKind.Close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
