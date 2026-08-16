// lib/utils/genre_radar_calculator.dart

import '../models/genre_radar_entry.dart';
import '../models/genre_time_stat.dart';

class GenreRadarCalculator {
  /// Nº máximo de ejes que se muestran en el radar.
  static const int defaultTopN = 6;

  /// Con menos ejes que esto, el radar no se dibuja (se muestra el estado vacío).
  static const int minAxesToRender = 3;

  /// Años con al menos una entrada, ordenados descendente (más reciente primero).
  static List<int> availableYears(List<GenreRadarEntry> entries) {
    final years = entries.map((e) => e.effectiveDate.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  /// Agrega horas por género. [year] == null => todo el histórico.
  /// Devuelve como máximo [topN] géneros, ordenados de mayor a menor horas.
  static List<GenreTimeStat> aggregate(
    List<GenreRadarEntry> entries, {
    int? year,
    int topN = defaultTopN,
  }) {
    final filtered = year == null
        ? entries
        : entries.where((e) => e.effectiveDate.year == year).toList();

    final Map<String, List<GenreRadarEntry>> gamesByGenre = {};

    for (final entry in filtered) {
      for (final genre in entry.genres) {
        // avoid duplicates just in case, though one entry = one game
        final list = gamesByGenre[genre] ??= [];
        if (!list.any((e) => e.gameId == entry.gameId)) {
          list.add(entry);
        }
      }
    }

    final stats = gamesByGenre.entries
        .map((e) => GenreTimeStat(
              genre: e.key,
              totalHours: 0.0,
              gameCount: e.value.length,
              games: e.value,
            ))
        .toList()
      ..sort((a, b) => b.gameCount.compareTo(a.gameCount));

    return stats.take(topN).toList();
  }
}
