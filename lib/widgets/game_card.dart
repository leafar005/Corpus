import 'package:flutter/material.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/screens/library/game_details_screen.dart';

class GameCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final bool isInLibrary;
  final double userRating;
  final VoidCallback onReturn;

  const GameCard({
    Key? key,
    required this.game,
    this.isInLibrary = false,
    this.userRating = 0.0,
    required this.onReturn,
  }) : super(key: key);

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
    
    // Título unificado
    final String title = widget.game['name'] ?? widget.game['title'] ?? 'Desconocido';
    final String lowerTitle = title.toLowerCase();

    // Id de IGDB unificado
    final igdbId = widget.game['igdb_id'] ?? widget.game['id'];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          final cleanData = {
            'igdb_id': igdbId,
            'title': title,
            'cover_url': coverUrl,
            'release_date': widget.game['first_release_date'] != null 
                ? DateTime.fromMillisecondsSinceEpoch(widget.game['first_release_date'] * 1000).toIso8601String() 
                : widget.game['release_date'],
            'summary': widget.game['summary'],
            'category': widget.game['category'],
            'parent_game': widget.game['parent_game'],
            'genres': widget.game['genres'] != null && widget.game['genres'] is List 
                ? (widget.game['genres'] as List).map((g) => g is Map ? g['name'] : g).toList() 
                : [],
            'screenshots': widget.game['screenshots'] != null ? (widget.game['screenshots'] as List).map((s) => s['image_id']).toList() : [],
            'artworks': widget.game['artworks'] != null ? (widget.game['artworks'] as List).map((a) => a['image_id']).toList() : [],
            'videos': widget.game['videos'] != null ? (widget.game['videos'] as List).map((v) => v['video_id']).toList() : [],
            'platforms': widget.game['platforms'] != null ? (widget.game['platforms'] as List).map((p) => p is Map ? p['name'] : p).toList() : [],
            'developer': 'Desconocido',
          };
          
          if (widget.game['involved_companies'] != null && (widget.game['involved_companies'] as List).isNotEmpty) {
            final companies = widget.game['involved_companies'] as List;
            try {
              final dev = companies.firstWhere((c) => c['developer'] == true);
              cleanData['developer'] = dev['company']['name'];
            } catch (_) {
              try { cleanData['developer'] = companies[0]['company']['name']; } catch (_) {}
            }
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailsScreen(gameData: cleanData),
            ),
          ).then((_) {
            widget.onReturn();
          });
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
                      child: const Center(child: Icon(Icons.videogame_asset, size: 40, color: Colors.white54)),
                    ),
                    
              if (_isHovered)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
                    int? catId = widget.game['category'];
                    final bool hasParent = widget.game['parent_game'] != null;
                    
                    bool isRemakeKeyword() {
                      final kws = ['remake', 'resynced', 'reforged', 'kiwami', 'twin snakes', 'reloaded'];
                      return kws.any((k) => lowerTitle.contains(k));
                    }
                    bool isRemasterKeyword() {
                      final kws = ['remaster', 'definitive edition', "director's cut", 'redux', 'resurrected', 'anniversary edition'];
                      if (kws.any((k) => lowerTitle.contains(k))) return true;
                      if (RegExp(r'\bhd\b').hasMatch(lowerTitle)) return true;
                      return false;
                    }
                    bool isDlcKeyword() {
                      final kws = ['dlc', 'expansion pass', 'phantom liberty', 'shadow of the erdtree', 'blood and wine', 'hearts of stone', 'the old hunters', 'the frozen wilds', 'left behind', 'the following'];
                      return kws.any((k) => lowerTitle.contains(k));
                    }
                    bool isExpandedKeyword() {
                      final kws = ['ultimate edition', 'game of the year', 'goty', 'royal', 'golden', 'complete edition'];
                      return kws.any((k) => lowerTitle.contains(k));
                    }
                    
                    if (isRemakeKeyword()) {
                      catId = 8;
                    } else if (isRemasterKeyword()) {
                      catId = 9;
                    } else if (isExpandedKeyword()) {
                      catId = 10;
                    } else if (isDlcKeyword()) {
                      catId = 1;
                    }

                    if (catId == null && !hasParent) return const SizedBox.shrink(); // Aún no cargó de Supabase o no tiene info

                    String text = 'Juego Principal';
                    Color color = Colors.blue;
                    
                    switch (catId ?? 0) {
                      case 0: text = hasParent ? 'DLC' : 'Juego Principal'; color = hasParent ? Colors.purpleAccent : Colors.blue; break;
                      case 1: text = 'DLC'; color = Colors.purpleAccent; break;
                      case 2: text = 'Expansión'; color = Colors.purpleAccent; break;
                      case 3: text = 'Bundle'; color = Colors.orangeAccent; break;
                      case 4: text = 'Exp Standalone'; color = Colors.purpleAccent; break;
                      case 8: text = 'Remake'; color = Theme.of(context).colorScheme.secondary; break;
                      case 9: text = 'Remaster'; color = Colors.tealAccent; break;
                      case 10: text = 'Ed. Expandida'; color = Colors.pinkAccent; break;
                      case 11: text = 'Port'; color = Colors.lightGreenAccent; break;
                      case 12: text = 'Fork'; color = Colors.grey; break;
                      case 13: text = 'Pack'; color = Colors.orangeAccent; break;
                      case 14: text = 'Actualización'; color = Colors.cyanAccent; break;
                    }
                    
                    if (text == 'Juego Principal') return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.5)),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
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
                        BoxShadow(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.54), blurRadius: 4, offset: const Offset(0, 2))
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
