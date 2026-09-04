import 'package:flutter/material.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/utils/igdb_constants.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onEndReached == null) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max - 80) {
      widget.onEndReached!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) {
      return SizedBox(height: widget.height);
    }

    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: widget.games.length,
        itemBuilder: (context, index) {
          final game = Game.fromMap(widget.games[index]);
          final isInLibrary = widget.userGamesCache.containsKey(game.igdbId);
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
    );
  }
}
