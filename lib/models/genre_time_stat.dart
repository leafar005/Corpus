// lib/models/genre_time_stat.dart

import 'package:flutter/foundation.dart';

import 'genre_radar_entry.dart';

/// Resultado agregado: horas totales dedicadas a un género (un eje del radar).
@immutable
class GenreTimeStat {
  const GenreTimeStat({
    required this.genre,
    required this.totalHours,
    required this.gameCount,
    required this.games,
  });

  final String genre; // nombre IGDB en inglés, p. ej. "Adventure"
  final double totalHours;
  final int gameCount; // nº de juegos distintos que aportan a este género
  final List<GenreRadarEntry> games; 
}
