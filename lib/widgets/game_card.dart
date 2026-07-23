import 'package:flutter/material.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/utils/igdb_constants.dart';

class GameCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final bool isInLibrary;
  final double userRating;
  final VoidCallback onReturn;

  const GameCard({
    super.key,
    required this.game,
    this.isInLibrary = false,
    this.userRating = 0.0,
    required this.onReturn,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Para juegos de IGDB (búsqueda/tendencias) puede venir 'cover'
    // Para juegos de Supabase (biblioteca) puede venir 'cover_url' directamente
    String coverUrl = '';
    if (widget.game['cover_url'] != null) {
      coverUrl = widget.game['cover_url'];
    } else {
      final coverImageId = widget.game['cover'] != null ? widget.game['cover']['image_id'] : null;
      coverUrl = IGDBService.getCoverUrl(coverImageId);
    }
    
    final String title = widget.game['name'] ?? widget.game['title'] ?? 'Desconocido';
    // Id de IGDB unificado
    final igdbId = widget.game['igdb_id'] ?? widget.game['id'];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          final cleanData = Map<String, dynamic>.from(widget.game);
          cleanData['igdb_id'] = igdbId;
          cleanData['title'] = title;
          cleanData['cover_url'] = coverUrl;
          cleanData['release_date'] = widget.game['first_release_date'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(widget.game['first_release_date'] * 1000).toIso8601String() 
              : widget.game['release_date'];
          
          if (widget.game['genres'] != null && widget.game['genres'] is List) {
            cleanData['genres'] = (widget.game['genres'] as List).map((g) => g is Map ? g['name'] : g).toList();
          } else if (widget.game['genres'] == null) {
            cleanData['genres'] = [];
          }

          if (widget.game['screenshots'] != null && widget.game['screenshots'] is List) {
            cleanData['screenshots'] = (widget.game['screenshots'] as List).map((s) => s is Map ? s['image_id'] : s).toList();
          } else if (widget.game['screenshots'] == null) {
            cleanData['screenshots'] = [];
          }

          if (widget.game['artworks'] != null && widget.game['artworks'] is List) {
            cleanData['artworks'] = (widget.game['artworks'] as List).map((a) => a is Map ? a['image_id'] : a).toList();
          } else if (widget.game['artworks'] == null) {
            cleanData['artworks'] = [];
          }

          if (widget.game['videos'] != null && widget.game['videos'] is List) {
            cleanData['videos'] = (widget.game['videos'] as List).map((v) => v is Map ? v['video_id'] : v).toList();
          } else if (widget.game['videos'] == null) {
            cleanData['videos'] = [];
          }

          if (widget.game['platforms'] != null && widget.game['platforms'] is List) {
            cleanData['platforms'] = (widget.game['platforms'] as List).map((p) => p is Map ? p['name'] : p).toList();
          } else if (widget.game['platforms'] == null) {
            cleanData['platforms'] = [];
          }

          if (widget.game['collection'] != null) {
            cleanData['collection'] = widget.game['collection'] is Map ? widget.game['collection']['name'] : widget.game['collection'];
          }
          
          if (widget.game['franchises'] != null && widget.game['franchises'] is List) {
            cleanData['franchises'] = (widget.game['franchises'] as List).map((f) => f is Map ? f['name'] : f).toList();
          } else if (widget.game['franchises'] == null) {
            cleanData['franchises'] = [];
          }

          if (widget.game['game_engines'] != null && widget.game['game_engines'] is List) {
            cleanData['game_engines'] = (widget.game['game_engines'] as List).map((e) => e is Map ? e['name'] : e).toList();
          } else if (widget.game['game_engines'] == null) {
            cleanData['game_engines'] = [];
          }

          cleanData['developer'] = 'Desconocido';
          
          if (widget.game['involved_companies'] != null && (widget.game['involved_companies'] as List).isNotEmpty) {
            final companies = widget.game['involved_companies'] as List;
            try {
              final dev = companies.firstWhere((c) => c['developer'] == true);
              cleanData['developer'] = dev['company']['name'];
            } catch (_) {
              try { cleanData['developer'] = companies[0]['company']['name']; } catch (_) {}
            }
          }

          final isDesktop = MediaQuery.of(context).size.width > 800;
          if (isDesktop) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GameDetailsScreen(gameData: cleanData)),
            ).then((_) => widget.onReturn());
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: false,
              enableDrag: true,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 1.0,
                minChildSize: 0.5,
                maxChildSize: 1.0,
                expand: false,
                snap: true,
                builder: (context, scrollController) {
                  return GameDetailsScreen(
                    gameData: cleanData,
                    scrollController: scrollController,
                  );
                },
              ),
            ).then((_) {
              widget.onReturn();
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              coverUrl.isNotEmpty
                  ? Image.network(coverUrl, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context).primaryColorDark,
                      child: Center(child: Icon(Icons.videogame_asset, size: 40, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54))),
                    ),
                    
              if (_isHovered)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              Positioned(
                bottom: 6, left: 6,
                child: Builder(
                  builder: (context) {
                    // Fix #3: Cast seguro — JSON/Supabase puede devolver num, double o int
                    final dynamic rawCat = widget.game['category'] ?? widget.game['game_type'];
                    final int? categoryId = (rawCat is num) ? rawCat.toInt() : int.tryParse(rawCat?.toString() ?? '');
                    final int? resolved = IgdbConstants.resolveCategory(
                      categoryId,
                      title,
                      hasParentGame: widget.game['parent_game'] != null,
                      summary: widget.game['summary']?.toString(),
                    );

                    // No badge for main games
                    if (IgdbConstants.isMainGame(resolved)) return const SizedBox.shrink();

                    final String text = IgdbConstants.getCategoryName(resolved!);
                    final Color color = IgdbConstants.getCategoryColor(resolved, themeSecondary: Theme.of(context).colorScheme.secondary);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                        boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.54), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              
              if (widget.isInLibrary && widget.userRating > 0)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.54), blurRadius: 4, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      widget.userRating.toStringAsFixed(1),
                      style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
