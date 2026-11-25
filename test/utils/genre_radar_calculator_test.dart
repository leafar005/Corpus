import 'package:corpus/models/genre_radar_entry.dart';
import 'package:corpus/utils/genre_radar_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenreRadarCalculator.aggregate (BUG-100, OPT-54)', () {
    test('ordena géneros de mayor a menor totalHours aunque tenga menos juegos', () {
      final entries = [
        GenreRadarEntry(
          gameId: 1,
          gameTitle: 'Game 1',
          genres: const ['Indie'],
          hours: 2.0,
          effectiveDate: DateTime.utc(2026, 1, 10),
        ),
        GenreRadarEntry(
          gameId: 2,
          gameTitle: 'Game 2',
          genres: const ['Indie'],
          hours: 3.0,
          effectiveDate: DateTime.utc(2026, 1, 12),
        ),
        GenreRadarEntry(
          gameId: 3,
          gameTitle: 'Game 3',
          genres: const ['Indie'],
          hours: 4.0,
          effectiveDate: DateTime.utc(2026, 1, 14),
        ),
        // RPG solo tiene 1 juego pero muchas más horas (120h vs 9h).
        GenreRadarEntry(
          gameId: 4,
          gameTitle: 'Game 4',
          genres: const ['RPG'],
          hours: 120.0,
          effectiveDate: DateTime.utc(2026, 2, 1),
        ),
        // Duplicado por gameId dentro del mismo género: no debe sumarse dos veces.
        GenreRadarEntry(
          gameId: 4,
          gameTitle: 'Game 4',
          genres: const ['RPG'],
          hours: 50.0,
          effectiveDate: DateTime.utc(2026, 2, 2),
        ),
      ];

      final stats = GenreRadarCalculator.aggregate(entries);
      expect(stats.map((s) => s.genre).toList(), ['RPG', 'Indie']);
      expect(stats[0].totalHours, 120.0);
      expect(stats[0].gameCount, 1);
      expect(stats[1].totalHours, 9.0);
      expect(stats[1].gameCount, 3);
    });
  });
}
