import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:corpus/utils/url_utils.dart';
import 'game_card.dart';
import 'vertical_tier_label.dart';

/// Una fila horizontal deslizable con los juegos de un bundle activo.
/// Los tiers se marcan con [VerticalTierLabel] al inicio de cada grupo.
class ExploreBundleRow extends StatelessWidget {
  final Map<String, dynamic> bundle;

  const ExploreBundleRow({super.key, required this.bundle});

  bool _shouldFlattenTiers(String storeName, String title) {
    final isFanatical = storeName.toLowerCase().contains('fanatical');
    final isHumbleChoice = title.toLowerCase().contains('humble choice');
    return isFanatical || isHumbleChoice;
  }

  List<Widget> _buildRowItems(BuildContext context) {
    final title = bundle['title'] ?? 'Bundle';
    final storeName = bundle['store_name'] ?? '';
    final tiers = bundle['tiers'] as List<dynamic>? ?? [];
    final flatten = _shouldFlattenTiers(storeName, title);
    final items = <Widget>[];

    if (flatten) {
      final allGames = <dynamic>[];
      for (final tierMap in tiers) {
        final games =
            (tierMap as Map<String, dynamic>)['games'] as List<dynamic>? ?? [];
        allGames.addAll(games);
      }
      for (final gameData in allGames) {
        items.add(_buildGameTile(context, gameData as Map<String, dynamic>));
      }
      return items;
    }

    for (final tierMap in tiers) {
      final tier = tierMap as Map<String, dynamic>;
      final games = tier['games'] as List<dynamic>? ?? [];
      if (games.isEmpty) continue;

      final tierName = tier['name'] as String? ?? '';
      final gameTiles = <Widget>[];

      for (final gameData in games) {
        gameTiles.add(_buildGameTile(context, gameData as Map<String, dynamic>));
      }

      if (tierName.isNotEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    tierName.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: gameTiles,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // If no tier name, just add the games individually
        items.addAll(gameTiles);
      }
    }

    return items;
  }

  Widget _buildGameTile(BuildContext context, Map<String, dynamic> gameData) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: AspectRatio(
        aspectRatio: IgdbConstants.coverAspectRatio,
        child: GameCard(
          key: ValueKey(
            gameData['steamAppId'] ?? gameData['title'] ?? gameData.hashCode,
          ),
          game: Game.fromMap(gameData),
          onReturn: () {},
        ),
      ),
    );
  }

  String _timeRemaining(String? endDateStr) {
    if (endDateStr == null) return '';
    final endDate = DateTime.parse(endDateStr);
    final diff = endDate.difference(DateTime.now().toUtc());
    if (diff.isNegative) return 'Caducado';
    if (diff.inDays == 0) return '¡Termina hoy!';
    return 'Quedan ${diff.inDays} días';
  }

  Color _timeColor(String? endDateStr) {
    if (endDateStr == null) {
      return Colors.grey;
    }
    final endDate = DateTime.parse(endDateStr);
    final diff = endDate.difference(DateTime.now().toUtc());
    if (diff.isNegative) return Colors.red;
    if (diff.inDays <= 10) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final title = bundle['title'] ?? 'Bundle';
    final url = bundle['url'] ?? '';
    final storeName = bundle['store_name'] ?? '';
    final endDateStr = bundle['end_date'] as String?;
    final isHumble = storeName.toLowerCase().contains('humble');
    final isFanatical = storeName.toLowerCase().contains('fanatical');
    final rowItems = _buildRowItems(context);

    if (rowItems.isEmpty) return const SizedBox.shrink();

    final timeRemaining = _timeRemaining(endDateStr);
    final timeColor = _timeColor(endDateStr);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isHumble)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Image.asset(
                      'assets/images/humble_logo.png',
                      height: 28,
                      width: 28,
                      fit: BoxFit.contain,
                    ),
                  )
                else if (isFanatical)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Image.asset(
                      'assets/images/fanatical_logo.png',
                      height: 28,
                      width: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.pushBundleDetails(bundle),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (timeRemaining.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: timeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: timeColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      timeRemaining,
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (url.isNotEmpty)
                  IconButton(
                    icon: const CorpusTablerIcon(CorpusIconKind.OpenInNew, size: 18),
                    tooltip: 'Tienda',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => openUrl(url),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 220, // Increased height to accommodate the Tier header
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: rowItems.length,
              itemBuilder: (context, index) => rowItems[index],
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
