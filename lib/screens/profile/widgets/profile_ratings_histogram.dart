import 'package:flutter/material.dart';
import '../../../utils/format_utils.dart';

/// Histograma de calificaciones del perfil (barras de 1★ a 10★).
class ProfileRatingsHistogram extends StatelessWidget {
  final List<double> ratings;

  const ProfileRatingsHistogram({
    super.key,
    required this.ratings,
  });

  @override
  Widget build(BuildContext context) {
    final validRatings = ratings.where((r) => r > 0).toList();

    if (validRatings.isEmpty) return const SizedBox.shrink();

    final List<int> buckets = List.filled(10, 0);
    double sum = 0;
    for (var r in validRatings) {
      sum += r;
      int bucketIndex = (r.floor() - 1).clamp(0, 9);
      buckets[bucketIndex]++;
    }

    final maxCount = buckets.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    final avgRating = sum / validRatings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Calificaciones',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${validRatings.length} | ${formatRating(avgRating)} ★ Media',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(10, (index) {
              final count = buckets[index];
              final heightRatio = maxCount > 0 ? count / maxCount : 0.0;
              final barHeight = 80 * heightRatio;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Tooltip(
                    message: 'Nota ${index + 1}: $count juegos',
                    child: Container(
                      height: barHeight > 0
                          ? (barHeight < 4 ? 4 : barHeight)
                          : 0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1★',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Text(
              '10★',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
