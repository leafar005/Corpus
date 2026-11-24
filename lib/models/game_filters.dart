import 'package:flutter/foundation.dart';

/// Estado de los filtros de búsqueda/biblioteca.
///
/// Modelo de datos puro (sin dependencias de UI). Lo usan:
/// - `SearchScreen` (búsqueda global vía IGDB)
/// - `ProfileGamesGridTab` (biblioteca del usuario)
/// - `FilterScreen` / `FilterOptionScreen` (UI de selección)
///
/// Inmutable: cualquier cambio se hace con [copyWith] y se reemplaza el
/// campo de estado (`_filters = _filters.copyWith(...)`) en quien lo use.
@immutable
class GameFilters {
  final String sortBy;
  final bool sortAscending;
  final List<int> genres;
  final List<int> themes;
  final List<int> gameModes;
  final List<int> playerPerspectives;
  final List<int> platforms;
  final List<int> categories;

  const GameFilters({
    this.sortBy = 'total_rating_count',
    this.sortAscending = false,
    this.genres = const [],
    this.themes = const [],
    this.gameModes = const [],
    this.playerPerspectives = const [],
    this.platforms = const [],
    this.categories = const [],
  });

  GameFilters copyWith({
    String? sortBy,
    bool? sortAscending,
    List<int>? genres,
    List<int>? themes,
    List<int>? gameModes,
    List<int>? playerPerspectives,
    List<int>? platforms,
    List<int>? categories,
  }) {
    return GameFilters(
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      genres: genres != null ? List<int>.unmodifiable(genres) : this.genres,
      themes: themes != null ? List<int>.unmodifiable(themes) : this.themes,
      gameModes: gameModes != null
          ? List<int>.unmodifiable(gameModes)
          : this.gameModes,
      playerPerspectives: playerPerspectives != null
          ? List<int>.unmodifiable(playerPerspectives)
          : this.playerPerspectives,
      platforms: platforms != null
          ? List<int>.unmodifiable(platforms)
          : this.platforms,
      categories: categories != null
          ? List<int>.unmodifiable(categories)
          : this.categories,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameFilters &&
          runtimeType == other.runtimeType &&
          sortBy == other.sortBy &&
          sortAscending == other.sortAscending &&
          listEquals(genres, other.genres) &&
          listEquals(themes, other.themes) &&
          listEquals(gameModes, other.gameModes) &&
          listEquals(playerPerspectives, other.playerPerspectives) &&
          listEquals(platforms, other.platforms) &&
          listEquals(categories, other.categories);

  @override
  int get hashCode => Object.hash(
    sortBy,
    sortAscending,
    Object.hashAll(genres),
    Object.hashAll(themes),
    Object.hashAll(gameModes),
    Object.hashAll(playerPerspectives),
    Object.hashAll(platforms),
    Object.hashAll(categories),
  );

  bool get hasFilters =>
      genres.isNotEmpty ||
      themes.isNotEmpty ||
      gameModes.isNotEmpty ||
      playerPerspectives.isNotEmpty ||
      platforms.isNotEmpty ||
      categories.isNotEmpty;

  int get filterCount =>
      genres.length +
      themes.length +
      gameModes.length +
      playerPerspectives.length +
      platforms.length +
      categories.length;

  /// Limpia todas las selecciones de categorías pero mantiene el orden
  /// (`sortBy`/`sortAscending`) tal cual estaba. Es lo que dispara el botón
  /// "Borrar" de `FilterScreen`.
  GameFilters clearSelections() {
    return GameFilters(sortBy: sortBy, sortAscending: sortAscending);
  }
}
