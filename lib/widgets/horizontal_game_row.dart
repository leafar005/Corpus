import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'game_card.dart';

/// Fila horizontal deslizable de [GameCard]s.
class HorizontalGameRow extends StatefulWidget {
  final List<dynamic> games;
  final Map<int, double> userGamesCache;
  final VoidCallback? onReturn;
  final void Function(Game game)? onTap;
  final VoidCallback? onEndReached;
  final double height;

  const HorizontalGameRow({
    super.key,
    required this.games,
    this.userGamesCache = const {},
    this.onReturn,
    this.onTap,
    this.onEndReached,
    this.height = 190,
  });

  @override
  State<HorizontalGameRow> createState() => _HorizontalGameRowState();
}

class _HorizontalGameRowState extends State<HorizontalGameRow> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _canScrollLeft = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _canScrollRight = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollArrows());
  }

  @override
  void didUpdateWidget(covariant HorizontalGameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games.length != widget.games.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateScrollArrows(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _canScrollLeft.dispose();
    _canScrollRight.dispose();
    super.dispose();
  }

  void _updateScrollArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    _canScrollLeft.value = position.pixels > 1.0;
    _canScrollRight.value = position.pixels < (position.maxScrollExtent - 1.0);
  }

  void _onScroll() {
    _updateScrollArrows();
    if (widget.onEndReached == null) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max - 80) {
      widget.onEndReached!();
    }
  }

  void _scrollBy(int direction) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final step = (position.viewportDimension * 0.75).clamp(240.0, 500.0);
    final target = (position.pixels + direction * step).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) {
      return SizedBox(height: widget.height);
    }

    final isDesktop = MediaQuery.sizeOf(context).width > kDesktopBreakpoint;

    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _updateScrollArrows();
          return false;
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 15.0,
              ),
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: widget.games.length,
              itemBuilder: (context, index) {
                final game = Game.fromMap(widget.games[index]);
                final isInLibrary = widget.userGamesCache.containsKey(
                  game.igdbId,
                );
                final userRating =
                    isInLibrary ? widget.userGamesCache[game.igdbId]! : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: AspectRatio(
                    aspectRatio: IgdbConstants.coverAspectRatio,
                    child: GameCard(
                      game: game,
                      isInLibrary: isInLibrary,
                      userRating: userRating,
                      onReturn: widget.onReturn ?? () {},
                      onTap: widget.onTap,
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _canScrollLeft,
              builder: (context, canLeft, _) {
                if (!isDesktop || !canLeft) return const SizedBox.shrink();
                return Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const CorpusTablerIcon(
                          CorpusIconKind.ChevronLeft,
                          color: Colors.white,
                        ),
                        onPressed: () => _scrollBy(-1),
                      ),
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _canScrollRight,
              builder: (context, canRight, _) {
                if (!isDesktop || !canRight) return const SizedBox.shrink();
                return Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const CorpusTablerIcon(
                          CorpusIconKind.ChevronRight,
                          color: Colors.white,
                        ),
                        onPressed: () => _scrollBy(1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
