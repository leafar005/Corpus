import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/utils/postgrest_utils.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/design/corpus_empty_state.dart';
import 'package:corpus/widgets/game_card.dart';

/// Tab "Juegos" en Mis juegos: dos secciones (Jugando + Por jugar).
class GamesTab extends StatefulWidget {
  const GamesTab({
    super.key,
    required this.userId,
    required this.onReturn,
    required this.scrollController,
  });

  final String userId;
  final VoidCallback onReturn;
  final ScrollController scrollController;

  @override
  State<GamesTab> createState() => GamesTabState();
}

class GamesTabState extends State<GamesTab> {
  List<Map<String, dynamic>> _playing = [];
  List<Map<String, dynamic>> _toPlay = [];
  Map<int, String> _completionTypeMap = {};
  final Set<int> _healedGameIds = <int>{};
  bool _loading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() => _load();

  List<Map<String, dynamic>> _filterGames(List<Map<String, dynamic>> source) {
    if (_searchQuery.isEmpty) return source;
    return source.where((item) {
      final gameMap = item['games'] as Map?;
      final title = (gameMap?['title'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final listResults = await Future.wait([
        client
            .from('user_games')
            .select('$kUserGameColumns, games!inner($kGameDetailColumns)')
            .eq('user_id', widget.userId)
            .eq('status', 'playing')
            .order('updated_at', ascending: false)
            .limit(100),
        client
            .from('user_games')
            .select('$kUserGameColumns, games!inner($kGameDetailColumns)')
            .eq('user_id', widget.userId)
            .eq('status', 'to_play')
            .order('updated_at', ascending: false)
            .limit(100),
      ]);

      if (!mounted) return;

      final playingList = (listResults[0] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final toPlayList = (listResults[1] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final gameIds = <int>{
        for (final item in [...playingList, ...toPlayList])
          if (item['game_id'] is num) (item['game_id'] as num).toInt(),
      }.toList();

      final completionMap = <int, String>{};
      if (gameIds.isNotEmpty) {
        final reviewsRes = await client
            .from('reviews')
            .select('game_id, completion_type')
            .eq('user_id', widget.userId)
            .inFilter('game_id', gameIds)
            .order('created_at', ascending: true)
            .limit(500);
        if (!mounted) return;
        for (final row in (reviewsRes as List).whereType<Map>()) {
          final gameId = (row['game_id'] as num?)?.toInt();
          final ct = row['completion_type']?.toString();
          if (gameId != null && ct != null && ct.isNotEmpty) {
            completionMap[gameId] = ct;
          }
        }
      }

      setState(() {
        _playing = playingList;
        _toPlay = toPlayList;
        _completionTypeMap = completionMap;
        _loading = false;
      });

      unawaited(_healIncompleteGames([...playingList, ...toPlayList]));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar tus juegos.';
        });
      }
    }
  }

  Future<void> _healIncompleteGames(List<Map<String, dynamic>> entries) async {
    final incompleteItems = <int, List<Map<String, dynamic>>>{};
    for (final item in entries) {
      final gameMap = item['games'];
      if (gameMap is! Map) continue;
      final cover = gameMap['cover_url'] as String?;
      if (cover != null && cover.isNotEmpty) continue;
      final rawId = gameMap['igdb_id'] ?? gameMap['id'];
      final igdbId = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      if (igdbId == null || _healedGameIds.contains(igdbId)) continue;
      incompleteItems.putIfAbsent(igdbId, () => []).add(item);
    }

    if (incompleteItems.isEmpty) return;

    final missingIds = incompleteItems.keys.toList();
    _healedGameIds.addAll(missingIds);

    try {
      final igdbGames = await IGDBService.getGamesByIdsFull(missingIds);
      if (!mounted || igdbGames.isEmpty) return;

      var updatedAny = false;
      for (final raw in igdbGames.whereType<Map>()) {
        final igdbGame = Map<String, dynamic>.from(raw);
        final igdbId = (igdbGame['id'] as num?)?.toInt();
        if (igdbId == null) continue;
        final targets = incompleteItems[igdbId];
        if (targets == null) continue;

        final healedMap = Game.fromMap(igdbGame).toMap();
        if (healedMap['release_date'] is String) {
          healedMap['release_date'] =
              (healedMap['release_date'] as String).split('T').first;
        }

        for (final item in targets) {
          final merged = Map<String, dynamic>.from(item['games'] as Map);
          healedMap.forEach((key, value) {
            if (value != null &&
                (value is! String || value.isNotEmpty) &&
                (value is! List || value.isNotEmpty)) {
              merged[key] = value;
            }
          });
          item['games'] = merged;
          updatedAny = true;
        }
      }

      if (updatedAny && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[GamesTab] Error reparando juegos en batch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CorpusEmptyState(
            icon: CorpusIconKind.ErrorOutline,
            title: _error!,
            actionLabel: 'Reintentar',
            actionIcon: CorpusIconKind.Refresh,
            onAction: _load,
          ),
        ),
      );
    }

    if (_playing.isEmpty && _toPlay.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CorpusEmptyState(
            icon: CorpusIconKind.Gamepad,
            title: 'No tienes juegos en curso ni pendientes',
            subtitle:
                'Marca juegos como «Jugando» o «Por jugar» desde su ficha para verlos aquí.',
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isDesktop ? 40.0 : 16.0;
    final ext = CorpusThemeExtension.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final filteredPlaying = _filterGames(_playing);
    final filteredToPlay = _filterGames(_toPlay);

    return SliverMainAxisGroup(
      slivers: [
        // ── Buscador rápido ───────────────────────────────────────
        if (_playing.length + _toPlay.length > 4)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                4,
              ),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Filtrar juegos en curso o por jugar…',
                    prefixIcon: const CorpusTablerIcon(
                      CorpusIconKind.Search,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const CorpusTablerIcon(
                              CorpusIconKind.Clear,
                              size: 18,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: ext.radiusMedium,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: ext.radiusMedium,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: ext.radiusMedium,
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
        ..._buildSection(
          title: 'Jugando',
          icon: CorpusIconKind.SportsEsports,
          games: filteredPlaying,
          totalCount: _playing.length,
          horizontalPadding: horizontalPadding,
          emptyMessage: _searchQuery.isNotEmpty
              ? 'Ningún juego en curso coincide con la búsqueda.'
              : 'No tienes juegos en curso actualmente.',
        ),
        ..._buildSection(
          title: 'Por jugar',
          icon: CorpusIconKind.Bookmark,
          games: filteredToPlay,
          totalCount: _toPlay.length,
          horizontalPadding: horizontalPadding,
          emptyMessage: _searchQuery.isNotEmpty
              ? 'Ningún juego pendiente coincide con la búsqueda.'
              : 'Marca juegos como «Por jugar» desde su ficha.',
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: getBottomSpacer(context)),
        ),
      ],
    );
  }

  List<Widget> _buildSection({
    required String title,
    required CorpusIconKind icon,
    required List<Map<String, dynamic>> games,
    required int totalCount,
    required double horizontalPadding,
    required String emptyMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = CorpusThemeExtension.of(context);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            10,
          ),
          child: Row(
            children: [
              CorpusTablerIcon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${games.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (games.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: ext.radiusMedium,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        )
      else
        ValueListenableBuilder<int>(
          valueListenable: mobileGridColumnsNotifier,
          builder: (context, columns, _) {
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                8,
              ),
              sliver: SliverGrid(
                gridDelegate: getCorpusGridDelegate(
                  context,
                  columns,
                  desktopMaxExtent: 120.0,
                  spacing: 12.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = games[index];
                    final gameData = Map<String, dynamic>.from(
                      item['games'] as Map,
                    );
                    final rating = (item['rating'] ?? 0).toDouble();
                    gameData['user_rating'] = rating;
                    gameData['is_steam_only'] = item['is_steam_only'];
                    final game = Game.fromMap(gameData);

                    return GameCard(
                      game: game,
                      isInLibrary: true,
                      userRating: rating,
                      completionType: _completionTypeMap[game.igdbId],
                      onReturn: () {
                        widget.onReturn();
                        _load();
                      },
                    );
                  },
                  childCount: games.length,
                ),
              ),
            );
          },
        ),
    ];
  }
}
