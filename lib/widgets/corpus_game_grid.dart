import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/widgets/game_card.dart';

/// Widget de cuadrícula de juegos reutilizable para Corpus.
///
/// Encapsula el patrón repetido en 10+ pantallas de: GridView.builder +
/// SliverGridDelegate responsivo + GameCard + spacing consistente.
///
/// Uso básico:
/// ```dart
/// CorpusGameGrid(
///   games: myGames,
///   onReturn: () => setState(() {}),
/// )
/// ```
///
/// Uso con game maps (cuando vienen de un query con join):
/// ```dart
/// CorpusGameGrid.fromMaps(
///   maps: userGames.map((ug) => ug['games']).toList(),
///   onReturn: () => setState(() {}),
/// )
/// ```
///
/// Creado en la auditoría técnica — Fase 3 para eliminar duplicación.
class CorpusGameGrid extends StatelessWidget {
  const CorpusGameGrid({
    super.key,
    required this.games,
    required this.onReturn,
    this.padding,
    this.spacing = 10.0,
    this.desktopMaxExtent = 140.0,
    this.shrinkWrap = false,
    this.physics,
    this.isInLibrary = false,
    this.showMetacriticBadge = false,
    this.userRatingExtractor,
    this.completionTypeExtractor,
    this.onTap,
  });

  /// Crea un CorpusGameGrid a partir de una lista de Maps (raw de Supabase).
  factory CorpusGameGrid.fromMaps({
    Key? key,
    required List<Map<String, dynamic>> maps,
    required VoidCallback onReturn,
    EdgeInsetsGeometry? padding,
    double spacing = 10.0,
    double desktopMaxExtent = 140.0,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    bool isInLibrary = false,
    bool showMetacriticBadge = false,
    void Function(Game)? onTap,
  }) {
    return CorpusGameGrid(
      key: key,
      games: maps.map((m) => Game.fromMap(m)).toList(),
      onReturn: onReturn,
      padding: padding,
      spacing: spacing,
      desktopMaxExtent: desktopMaxExtent,
      shrinkWrap: shrinkWrap,
      physics: physics,
      isInLibrary: isInLibrary,
      showMetacriticBadge: showMetacriticBadge,
      onTap: onTap,
    );
  }

  /// Lista de juegos a mostrar.
  final List<Game> games;

  /// Callback cuando el usuario vuelve de la pantalla de detalle.
  final VoidCallback onReturn;

  /// Padding alrededor de la cuadrícula. Si es null, usa [EdgeInsets.all(8)].
  final EdgeInsetsGeometry? padding;

  /// Espaciado entre las celdas de la cuadrícula.
  final double spacing;

  /// Anchura máxima por celda en escritorio.
  final double desktopMaxExtent;

  /// Si true, el GridView se ajusta a su contenido (para uso dentro de Column/ListView).
  final bool shrinkWrap;

  /// Física de scroll personalizada. Si es null, usa la por defecto.
  final ScrollPhysics? physics;

  /// Si true, muestra el indicador de "en biblioteca" en las GameCard.
  final bool isInLibrary;

  /// Si true, muestra el badge de Metacritic.
  final bool showMetacriticBadge;

  /// Extractor de rating personalizado (por índice). Si es null, rating = 0.
  final double Function(int index)? userRatingExtractor;

  /// Extractor de tipo de completado (por índice). Si es null, no se muestra.
  final String? Function(int index)? completionTypeExtractor;

  /// Callback personalizado al pulsar un juego (en vez de navegar a detalle).
  final void Function(Game)? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mobileGridColumnsNotifier,
      builder: (context, columns, _) {
        return GridView.builder(
          padding: padding ?? const EdgeInsets.all(8),
          shrinkWrap: shrinkWrap,
          physics: physics,
          gridDelegate: getCorpusGridDelegate(
            context,
            columns,
            spacing: spacing,
            desktopMaxExtent: desktopMaxExtent,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return GameCard(
              game: game,
              isInLibrary: isInLibrary,
              showMetacriticBadge: showMetacriticBadge,
              userRating: userRatingExtractor?.call(index) ?? 0.0,
              completionType: completionTypeExtractor?.call(index),
              onReturn: onReturn,
              onTap: onTap,
            );
          },
        );
      },
    );
  }
}

/// Variante Sliver de [CorpusGameGrid] para uso en CustomScrollView.
class CorpusGameGridSliver extends StatelessWidget {
  const CorpusGameGridSliver({
    super.key,
    required this.games,
    required this.onReturn,
    this.spacing = 10.0,
    this.desktopMaxExtent = 140.0,
    this.isInLibrary = false,
    this.showMetacriticBadge = false,
    this.userRatingExtractor,
    this.completionTypeExtractor,
    this.onTap,
  });

  final List<Game> games;
  final VoidCallback onReturn;
  final double spacing;
  final double desktopMaxExtent;
  final bool isInLibrary;
  final bool showMetacriticBadge;
  final double Function(int index)? userRatingExtractor;
  final String? Function(int index)? completionTypeExtractor;
  final void Function(Game)? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mobileGridColumnsNotifier,
      builder: (context, columns, _) {
        return SliverGrid(
          gridDelegate: getCorpusGridDelegate(
            context,
            columns,
            spacing: spacing,
            desktopMaxExtent: desktopMaxExtent,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final game = games[index];
              return GameCard(
                game: game,
                isInLibrary: isInLibrary,
                showMetacriticBadge: showMetacriticBadge,
                userRating: userRatingExtractor?.call(index) ?? 0.0,
                completionType: completionTypeExtractor?.call(index),
                onReturn: onReturn,
                onTap: onTap,
              );
            },
            childCount: games.length,
          ),
        );
      },
    );
  }
}
