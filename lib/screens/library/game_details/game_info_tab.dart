import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../utils/url_utils.dart';
import '../../../utils/igdb_constants.dart';
import '../../../utils/format_utils.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../../theme/corpus_theme_extension.dart';

class GameInfoTab extends StatelessWidget {
  const GameInfoTab({
    super.key,
    required this.gameData,
    required this.enrichedData,
    this.summary,
    this.collectionName,
    this.collectionId,
    required this.franchisesData,
    required this.genresList,
    required this.themesList,
    required this.platformsList,
    required this.gameEnginesList,
    this.developer,
    required this.infoTabOrder,
    required this.infoTabHidden,
    required this.isLoadingMetacritic,
    this.metacriticScore,
    this.metacriticUserScore,
    this.metacriticCriticCount,
    this.metacriticUserRatingCount,
    this.metacriticUrl,
    required this.isLoadingStashStats,
    this.stashStats,
    this.timeToBeat,
  });

  final Game gameData;
  final Map<String, dynamic> enrichedData;
  final String? summary;
  final String? collectionName;
  final int? collectionId;
  final List<Map<String, dynamic>> franchisesData;
  final List genresList;
  final List themesList;
  final List platformsList;
  final List gameEnginesList;
  final String? developer;
  final List<String> infoTabOrder;
  final Set<String> infoTabHidden;
  final bool isLoadingMetacritic;
  final int? metacriticScore;
  final double? metacriticUserScore;
  final int? metacriticCriticCount;
  final int? metacriticUserRatingCount;
  final String? metacriticUrl;
  final bool isLoadingStashStats;
  final Map<String, dynamic>? stashStats;
  final Map<String, dynamic>? timeToBeat;

  Widget _buildMetacriticSection(BuildContext context) {
    if (isLoadingMetacritic && metacriticScore == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (metacriticScore == null) return const SizedBox.shrink();

    Color scoreColor(int s) => s >= 75
        ? const Color(0xFF4CAF50)
        : s >= 50
        ? const Color(0xFFFFC107)
        : const Color(0xFFF44336);

    Color userColor(double s) => s >= 7.5
        ? const Color(0xFF4CAF50)
        : s >= 5.0
        ? const Color(0xFFFFC107)
        : const Color(0xFFF44336);

    Widget scoreBadge({
      required String value,
      required Color color,
      required BuildContext context,
      bool isCircle = false,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: isCircle
                  ? null
                  : Theme.of(
                      context,
                    ).extension<CorpusThemeExtension>()!.radiusSmall,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metacritic',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: metacriticUrl != null ? () => openUrl(metacriticUrl!) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  scoreBadge(
                    value: metacriticScore.toString(),
                    color: scoreColor(metacriticScore!),
                    context: context,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Metascore',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (metacriticCriticCount != null)
                        Text(
                          '$metacriticCriticCount críticas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (metacriticUserScore != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 36,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 16),
                    scoreBadge(
                      value: metacriticUserScore!.toStringAsFixed(1),
                      color: userColor(metacriticUserScore!),
                      context: context,
                      isCircle: true,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'User Score',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (metacriticUserRatingCount != null)
                          Text(
                            '$metacriticUserRatingCount valoraciones',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (metacriticUrl != null) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStashStatsSection(BuildContext context) {
    if (isLoadingStashStats && stashStats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (stashStats == null) return const SizedBox.shrink();

    final rating = (stashStats!['stash_rating'] as num?)?.toDouble();
    final want = stashStats!['want_count'] as int?;
    final playing = stashStats!['playing_count'] as int?;
    final played = stashStats!['played_count'] as int?;

    if (rating == null && want == null && playing == null && played == null) {
      return const SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget statCard(IconData icon, String value, String label, Color color) {
      return Container(
        constraints: BoxConstraints(minWidth: isDesktop ? 88 : 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: Theme.of(
            context,
          ).extension<CorpusThemeExtension>()!.radiusMedium,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isDesktop ? 18 : 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 15 : 14,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estadísticas de la Comunidad (Stash)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (rating != null)
              statCard(
                Icons.emoji_events,
                formatRating(rating),
                'Críticas',
                Colors.amber,
              ),
            if (want != null)
              statCard(
                Icons.favorite,
                want.toString(),
                'Quiero',
                Theme.of(context).colorScheme.primary,
              ),
            if (playing != null)
              statCard(
                Icons.gamepad,
                playing.toString(),
                'Jugando',
                Colors.green,
              ),
            if (played != null)
              statCard(
                Icons.videogame_asset,
                played.toString(),
                'Jugado',
                Colors.blueAccent,
              ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTimeToBeatCard(
    BuildContext context,
    String title,
    num? rawValue,
    Color color,
    IconData icon,
  ) {
    String timeText = '--';
    if (rawValue != null && rawValue > 0) {
      final isDD = timeToBeat?['_source'] == 'duracionde';
      final double hours = isDD
          ? rawValue.toDouble()
          : rawValue.toDouble() / 3600;
      timeText = '${hours.toStringAsFixed(1).replaceAll('.0', '')} h';
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: Theme.of(
            context,
          ).extension<CorpusThemeExtension>()!.radiusLarge,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeText,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeToBeatRow(BuildContext context) {
    // Soporta dos esquemas de claves:
    // - IGDB: hastily / normally / completely
    // - DuracionDe: main / main_extra / completionist
    final ttb = timeToBeat;
    final isDD = (ttb?['_source'] as String?) == 'duracionde';
    final principalKey = isDD ? 'main' : 'hastily';
    final extrasKey = isDD ? 'main_extra' : 'normally';
    final completionistKey = isDD ? 'completionist' : 'completely';
    final principal = ttb?[principalKey];
    final extras = ttb?[extrasKey];
    final completionist = ttb?[completionistKey];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeToBeatCard(
          context,
          'Principal',
          principal,
          Colors.blueAccent,
          Icons.speed,
        ),
        const SizedBox(width: 8),
        _buildTimeToBeatCard(
          context,
          'Extras',
          extras,
          Colors.purpleAccent,
          Icons.explore,
        ),
        const SizedBox(width: 8),
        _buildTimeToBeatCard(
          context,
          'Completista',
          completionist,
          Colors.amber,
          Icons.emoji_events,
        ),
      ],
    );
  }

  Widget _buildInfoSection(String key, BuildContext context) {
    if (key == 'franchise') {
      if (collectionName == null && franchisesData.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Franquicia / Colección',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (collectionName != null)
                collectionId != null
                    ? ActionChip(
                        label: Text(
                          collectionName!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusLarge,
                        ),
                        onPressed: () {
                          context.pushGroupGames(
                            collectionName!,
                            collectionId!,
                          );
                        },
                      )
                    : Chip(
                        label: Text(
                          collectionName!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusLarge,
                        ),
                      ),
              ...franchisesData
                  .where((f) => f['name'] != collectionName)
                  .map(
                    (f) => f['id'] != null
                        ? ActionChip(
                            label: Text(
                              f['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.2),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: Theme.of(
                                context,
                              ).extension<CorpusThemeExtension>()!.radiusLarge,
                            ),
                            onPressed: () {
                              context.pushGroupGames(
                                f['name'].toString(),
                                f['id'] as int,
                                isFranchise: true,
                              );
                            },
                          )
                        : Chip(
                            label: Text(
                              f['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.2),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: Theme.of(
                                context,
                              ).extension<CorpusThemeExtension>()!.radiusLarge,
                            ),
                          ),
                  ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    if (key == 'genres_themes') {
      if (genresList.isEmpty && themesList.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Géneros y temáticas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...genresList.map((g) {
                final gName = g is Map ? g['name'].toString() : g.toString();
                return Chip(
                  label: Text(
                    IgdbConstants.formatGenreWithEmoji(gName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: Theme.of(
                      context,
                    ).extension<CorpusThemeExtension>()!.radiusLarge,
                  ),
                );
              }),
              ...themesList.map((t) {
                final tName = t is Map ? t['name'].toString() : t.toString();
                return Chip(
                  label: Text(
                    IgdbConstants.formatThemeWithEmoji(tName),
                    style: const TextStyle(fontSize: 13),
                  ),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: Theme.of(
                      context,
                    ).extension<CorpusThemeExtension>()!.radiusLarge,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    if (key == 'platforms') {
      if (platformsList.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plataformas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platformsList.map((p) {
              final style = IgdbConstants.getPlatformStyle(p.toString());
              return Chip(
                avatar: style['icon'] != null
                    ? Image.asset(
                        style['icon'],
                        height: 20,
                        fit: BoxFit.contain,
                      )
                    : (style['materialIcon'] != null
                          ? Icon(
                              style['materialIcon'],
                              size: 20,
                              color: style['textColor'],
                            )
                          : null),
                label: Text(
                  p.toString(),
                  style: TextStyle(
                    color: style['textColor'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: style['color'],
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: Theme.of(
                    context,
                  ).extension<CorpusThemeExtension>()!.radiusLarge,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    if (key == 'metacritic') {
      return _buildMetacriticSection(context);
    }

    if (key == 'stash_stats') {
      return _buildStashStatsSection(context);
    }

    if (key == 'summary') {
      if (summary == null || summary!.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sinopsis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(summary!, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 28),
        ],
      );
    }

    if (key == 'hltb') {
      final source = timeToBeat?['_source'] as String?;
      String titleText = 'Tiempo estimado';
      if (source == 'duracionde') {
        titleText = 'Tiempo estimado (duracionde.com)';
      } else if (source == 'igdb' || source == 'igdb_fallback') {
        titleText = 'Tiempo estimado (IGDB.com)';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTimeToBeatRow(context),
          const SizedBox(height: 28),
        ],
      );
    }

    if (key == 'engine') {
      if (gameEnginesList.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Row(
          children: [
            Icon(
              Icons.memory,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Motor Gráfico: ${gameEnginesList.join(', ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoTabOrder
          .where((key) => !infoTabHidden.contains(key))
          .map((key) => _buildInfoSection(key, context))
          .toList(),
    );
  }
}
