// lib/widgets/genre_radar_section.dart

import 'package:flutter/material.dart';
import '../models/genre_radar_entry.dart';
import '../repositories/profile_repository.dart';
import '../utils/genre_radar_calculator.dart';
import '../utils/igdb_constants.dart';
import 'corpus_section_title.dart';
import 'genre_radar_chart.dart';
import 'corpus_network_image.dart';
import '../screens/library/game_details_screen.dart';

class GenreRadarSection extends StatefulWidget {
  final String userId;

  const GenreRadarSection({super.key, required this.userId});

  @override
  State<GenreRadarSection> createState() => _GenreRadarSectionState();
}

class _GenreRadarSectionState extends State<GenreRadarSection> {
  final ProfileRepository _repo = ProfileRepository();

  bool _isLoading = true;
  String? _error;
  List<GenreRadarEntry> _entries = [];
  List<int> _availableYears = [];
  int? _selectedYear; // null = "Todo el tiempo"

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant GenreRadarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _selectedYear = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _repo.fetchGenreRadarEntries(widget.userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _availableYears = GenreRadarCalculator.availableYears(entries);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[GenreRadarSection] Error loading data: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los datos de género.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = GenreRadarCalculator.aggregate(_entries, year: _selectedYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mapa de géneros',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_availableYears.isNotEmpty) _buildYearDropdown(),
          ],
        ),
        const SizedBox(height: 20),
        if (stats.length < GenreRadarCalculator.minAxesToRender)
          _buildEmptyState()
        else
          AspectRatio(
            aspectRatio: 1.35,
            child: GenreRadarChart(
              stats: stats,
              onGenreTapped: (stat) => _showGamesDialog(context, stat),
            ),
          ),
      ],
    );
  }

  void _showGamesDialog(BuildContext context, dynamic stat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(IgdbConstants.formatGenreWithEmoji(stat.genre)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75, // Proporción típica de portadas de juegos
              ),
              itemCount: stat.games.length,
              itemBuilder: (context, index) {
                final game = stat.games[index];
                
                final tileContent = (game.coverUrl != null && game.coverUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CorpusNetworkImage(
                          url: game.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              game.gameTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );

                return GestureDetector(
                  onTap: () {
                    // Cierra el modal primero
                    Navigator.pop(context);
                    // Navega a GameDetailsScreen pasándole los datos básicos que tenemos
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailsScreen(
                          gameData: {
                            'igdb_id': game.gameId,
                            'title': game.gameTitle,
                            if (game.coverUrl != null) 'cover_url': game.coverUrl,
                          },
                        ),
                      ),
                    );
                  },
                  child: tileContent,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButton<int?>(
      value: _selectedYear,
      underline: const SizedBox.shrink(),
      onChanged: (value) => setState(() => _selectedYear = value),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todo el tiempo'),
        ),
        for (final year in _availableYears)
          DropdownMenuItem<int?>(value: year, child: Text('$year')),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Aún no hay suficientes juegos completados\n'
          'para mostrar este gráfico.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
