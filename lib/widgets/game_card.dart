import 'package:flutter/material.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_network_image.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final bool isInLibrary;
  final double userRating;
  final VoidCallback onReturn;
  final bool isGrayscale;
  final bool showMetacriticBadge;
  final void Function(Game)? onTap;

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
    final image = CorpusNetworkImage(
      url: coverUrl,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      placeholder: _buildPlaceholder(context, title),
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
    final String coverUrl = widget.game.coverUrl ?? '';
    final String title = widget.game.title;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap!(widget.game);
              return;
            }

            context
                .pushGameDetails(widget.game.toMap())
                .then((_) => widget.onReturn());
          },
          borderRadius:
              Theme.of(
                context,
              ).extension<CorpusThemeExtension>()?.radiusSmall ??
              BorderRadius.circular(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        Theme.of(
                          context,
                        ).extension<CorpusThemeExtension>()?.radiusSmall ??
                        BorderRadius.circular(8),
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
                                final int? resolved =
                                    IgdbConstants.resolveCategory(
                                      widget.game.category,
                                      title,
                                      hasParentGame:
                                          widget.game.parentGameId != null,
                                      summary: widget.game.summary,
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
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
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
                                  formatRating(widget.userRating),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.game.isSteamOnly)
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

              if (widget.showMetacriticBadge &&
                  widget.game.metacriticScore != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getMetacriticColor(widget.game.metacriticScore!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.game.metacriticScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMetacriticColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
