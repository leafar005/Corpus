import 'package:flutter/material.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/utils/igdb_constants.dart';

class GameCard extends StatefulWidget {
  final Map<String, dynamic> game;
  final bool isInLibrary;
  final double userRating;
  final VoidCallback onReturn;
  final bool isGrayscale;
  final bool showMetacriticBadge;
  final void Function(Map<String, dynamic>)? onTap;

  const GameCard({
    super.key,
    required this.game,
    this.isInLibrary = false,
    this.userRating = 0.0,
    required this.onReturn,
    this.isGrayscale = false,
    this.showMetacriticBadge = false,
    this.onTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovered = false;

  static const List<double> _grayscaleMatrix = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  Widget _buildPlaceholder(BuildContext context, String title) => Container(
    color: Theme.of(context).primaryColorDark,
    padding: const EdgeInsets.all(8.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.videogame_asset,
          size: 40,
          color: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.54),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: 0.54),
          ),
        ),
      ],
    ),
  );

  Widget _buildCoverImage(
    BuildContext context,
    String coverUrl,
    int? cacheWidth,
    String title,
  ) {
    final image = Image.network(
      coverUrl,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) =>
          _buildPlaceholder(context, title),
    );
    return widget.isGrayscale
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
            child: image,
          )
        : image;
  }

  @override
  Widget build(BuildContext context) {
    String coverUrl = '';
    if (widget.game['cover_url'] != null) {
      coverUrl = widget.game['cover_url'];
    } else {
      final coverImageId = widget.game['cover'] != null
          ? widget.game['cover']['image_id']
          : null;
      coverUrl = IGDBService.getCoverUrl(coverImageId);
    }

    final String title =
        widget.game['name'] ?? widget.game['title'] ?? 'Desconocido';
    final igdbId = widget.game['igdb_id'] ?? widget.game['id'];

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () {
            final cleanData = Map<String, dynamic>.from(widget.game);
            cleanData['igdb_id'] = igdbId;
            cleanData['title'] = title;
            cleanData['cover_url'] = coverUrl;
            cleanData['release_date'] =
                widget.game['first_release_date'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    widget.game['first_release_date'] * 1000,
                  ).toIso8601String()
                : widget.game['release_date'];

            if (widget.game['genres'] != null &&
                widget.game['genres'] is List) {
              cleanData['genres'] = (widget.game['genres'] as List)
                  .map((g) => g is Map ? g['name'] : g)
                  .toList();
            } else if (widget.game['genres'] == null) {
              cleanData['genres'] = [];
            }

            if (widget.game['screenshots'] != null &&
                widget.game['screenshots'] is List) {
              cleanData['screenshots'] = (widget.game['screenshots'] as List)
                  .map((s) => s is Map ? s['image_id'] : s)
                  .toList();
            } else if (widget.game['screenshots'] == null) {
              cleanData['screenshots'] = [];
            }

            if (widget.game['artworks'] != null &&
                widget.game['artworks'] is List) {
              cleanData['artworks'] = (widget.game['artworks'] as List)
                  .map((a) => a is Map ? a['image_id'] : a)
                  .toList();
            } else if (widget.game['artworks'] == null) {
              cleanData['artworks'] = [];
            }

            if (widget.game['videos'] != null &&
                widget.game['videos'] is List) {
              cleanData['videos'] = (widget.game['videos'] as List)
                  .map((v) => v is Map ? v['video_id'] : v)
                  .toList();
            } else if (widget.game['videos'] == null) {
              cleanData['videos'] = [];
            }

            if (widget.game['platforms'] != null &&
                widget.game['platforms'] is List) {
              cleanData['platforms'] = (widget.game['platforms'] as List)
                  .map((p) => p is Map ? p['name'] : p)
                  .toList();
            } else if (widget.game['platforms'] == null) {
              cleanData['platforms'] = [];
            }

            if (widget.game['collection'] != null) {
              cleanData['collection'] = widget.game['collection'] is Map
                  ? widget.game['collection']['name']
                  : widget.game['collection'];
            }

            if (widget.game['franchises'] != null &&
                widget.game['franchises'] is List) {
              cleanData['franchises'] = (widget.game['franchises'] as List)
                  .map((f) => f is Map ? f['name'] : f)
                  .toList();
            } else if (widget.game['franchises'] == null) {
              cleanData['franchises'] = [];
            }

            if (widget.game['game_engines'] != null &&
                widget.game['game_engines'] is List) {
              cleanData['game_engines'] = (widget.game['game_engines'] as List)
                  .map((e) => e is Map ? e['name'] : e)
                  .toList();
            } else if (widget.game['game_engines'] == null) {
              cleanData['game_engines'] = [];
            }

            if (widget.game['involved_companies'] != null &&
                (widget.game['involved_companies'] as List).isNotEmpty) {
              final companies = widget.game['involved_companies'] as List;
              try {
                final dev = companies.firstWhere((c) => c['developer'] == true);
                cleanData['developer'] = dev['company']['name'];
              } catch (_) {
                try {
                  cleanData['developer'] = companies[0]['company']['name'];
                } catch (_) {}
              }
            } else {
              cleanData['developer'] =
                  widget.game['developer'] ?? 'Desconocido';
            }

            if (widget.onTap != null) {
              widget.onTap!(cleanData);
              return;
            }

            final isDesktop = MediaQuery.of(context).size.width > 800;
            if (isDesktop) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameDetailsScreen(gameData: cleanData),
                ),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final int? cacheWidth = constraints.maxWidth.isFinite
                          ? (constraints.maxWidth * dpr).round()
                          : null;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          coverUrl.isNotEmpty
                              ? _buildCoverImage(
                                  context,
                                  coverUrl,
                                  cacheWidth,
                                  title,
                                )
                              : _buildPlaceholder(context, title),

                          if (_isHovered)
                            Positioned.fill(
                              child: Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.7),
                                padding: const EdgeInsets.all(8.0),
                                alignment: Alignment.center,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Builder(
                              builder: (context) {
                                final dynamic rawCat =
                                    widget.game['category'] ??
                                    widget.game['game_type'];
                                final int? categoryId = (rawCat is num)
                                    ? rawCat.toInt()
                                    : int.tryParse(rawCat?.toString() ?? '');
                                final int? resolved =
                                    IgdbConstants.resolveCategory(
                                      categoryId,
                                      title,
                                      hasParentGame:
                                          widget.game['parent_game'] != null,
                                      summary: widget.game['summary']
                                          ?.toString(),
                                    );

                                if (IgdbConstants.isMainGame(resolved)) {
                                  return const SizedBox.shrink();
                                }

                                final String text =
                                    IgdbConstants.getCategoryName(resolved!);
                                final Color color =
                                    IgdbConstants.getCategoryColor(
                                      resolved,
                                      themeSecondary: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    );

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).shadowColor.withValues(alpha: 0.54),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          if (widget.isInLibrary && widget.userRating > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withValues(alpha: 0.54),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.userRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),

                          if (widget.game['is_steam_only'] == true)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF171a21,
                                  ).withValues(alpha: 0.9), // Steam dark color
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/steam.png',
                                  width: 14,
                                  height: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Badge de Metacritic asomando por abajo, más pequeño y rectangular
              if (widget.showMetacriticBadge &&
                  widget.game['metacritic_score'] != null)
                Positioned(
                  bottom: -8, // Se sale 8px del GameCard por abajo
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Builder(
                      builder: (context) {
                        final score = widget.game['metacritic_score'] as int;
                        final color = score >= 75
                            ? const Color(0xFF4CAF50)
                            : score >= 50
                            ? const Color(0xFFFFC107)
                            : const Color(0xFFF44336);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            score.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
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
