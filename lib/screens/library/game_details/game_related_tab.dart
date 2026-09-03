import 'package:flutter/material.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../../services/igdb_service.dart';
import '../game_details_screen.dart';
import 'game_details_controller.dart';
import '../../../models/models.dart';
import '../../../widgets/corpus_network_image.dart';

class GameRelatedTab extends StatelessWidget {
  const GameRelatedTab({
    super.key,
    required this.controller,
    required this.onNavigateToGame,
  });

  final GameDetailsController controller;
  final void Function(int id, String? name) onNavigateToGame;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingRelated) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.relatedGames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No hay contenido relacionado.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    String gameTypeLabel(int? t) {
      switch (t) {
        case 1:
          return 'DLCs';
        case 2:
          return 'Expansiones';
        case 3:
          return 'Bundles';
        case 4:
          return 'Expansiones Standalone';
        case 5:
          return 'Mods';
        case 6:
          return 'Episodios';
        case 7:
          return 'Temporadas';
        case 8:
          return 'Remakes';
        case 9:
          return 'Remasters';
        case 10:
          return 'Ediciones Expandidas';
        case 11:
          return 'Ports';
        case 12:
          return 'Forks';
        case 13:
          return 'Packs';
        case 14:
          return 'Actualizaciones';
        default:
          return 'Relacionados';
      }
    }

    const typeOrder = [8, 9, 4, 2, 1, 10, 11, 14, 3, 13, 6, 7, 12, 5, 0];
    final Map<int?, List<dynamic>> grouped = {};
    for (final g in controller.relatedGames) {
      final key = (g['game_type'] is num)
          ? (g['game_type'] as num).toInt()
          : g['game_type'] as int?;
      grouped.putIfAbsent(key, () => []).add(g);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = typeOrder.indexOf(a ?? -1);
        final bi = typeOrder.indexOf(b ?? -1);
        return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in sortedKeys) ...[
          Text(
            '${gameTypeLabel(type)} (${grouped[type]!.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: grouped[type]!.length,
            itemBuilder: (context, i) {
              final g = grouped[type]![i];
              final coverMap = g['cover'] as Map?;
              final coverId = coverMap?['image_id'] as String?;
              final coverUrl = IGDBService.getCoverUrl(coverId);
              int? releaseYear;
              if (g['first_release_date'] != null) {
                releaseYear = DateTime.fromMillisecondsSinceEpoch(
                  (g['first_release_date'] as int) * 1000,
                ).year;
              }
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final cleanData = Map<String, dynamic>.from(g as Map);
                  cleanData['igdb_id'] = g['id'];
                  cleanData['title'] = g['name'];
                  cleanData['cover_url'] = coverUrl;
                  if (g['genres'] != null && g['genres'] is List) {
                    cleanData['genres'] = (g['genres'] as List)
                        .map((gen) => gen is Map ? gen['name'] : gen)
                        .toList();
                  }
                  if (MediaQuery.of(context).size.width >= 800) {
                    context.pushGameDetails(Game.fromMap(cleanData));
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: false,
                      enableDrag: true,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 1.0,
                        minChildSize: 0.5,
                        maxChildSize: 1.0,
                        expand: false,
                        snap: true,
                        builder: (context, scrollController) {
                          return GameDetailsScreen(
                            gameData: Game.fromMap(cleanData),
                            scrollController: scrollController,
                          );
                        },
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: coverUrl.isNotEmpty
                            ? CorpusNetworkImage(
                                url: coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Icons.videogame_asset,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    size: 36,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: Text(
                        releaseYear != null
                            ? '${g['name']} ($releaseYear)'
                            : g['name'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}
