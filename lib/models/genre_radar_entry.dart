// lib/models/genre_radar_entry.dart

import 'package:flutter/foundation.dart';

/// Una fila normalizada de user_games lista para agregar por género.
/// Ya viene filtrada: solo entradas con horas > 0, género no vacío y
/// status != wishlist (ver ProfileRepository.fetchGenreRadarEntries).
@immutable
class GenreRadarEntry {
  const GenreRadarEntry({
    required this.gameId,
    required this.gameTitle,
    this.coverUrl,
    required this.genres,
    required this.hours,
    required this.effectiveDate,
  });

  final int gameId;
  final String gameTitle;
  final String? coverUrl;
  final List<String> genres;
  final double hours;
  final DateTime effectiveDate;
}
