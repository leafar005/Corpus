import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
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
      final results = await Future.wait([
        client
            .from('user_games')
            .select('*, games!inner(*)')
            .eq('user_id', widget.userId)
            .eq('status', 'playing')
            .order('updated_at', ascending: false)
            .limit(100),
        client
            .from('user_games')
            .select('*, games!inner(*)')
            .eq('user_id', widget.userId)
            .eq('status', 'to_play')
            .order('updated_at', ascending: false)
            .limit(100),
        client
            .from('reviews')
            .select('game_id, completion_type')
            .eq('user_id', widget.userId),
      ]);

      if (!mounted) return;

      final completionMap = <int, String>{};
      for (final row in (results[2] as List)) {
        final m = row as Map;
        final gameId = m['game_id'];
        final ct = m['completion_type'];
        if (gameId != null && ct != null && ct.toString().isNotEmpty) {
          completionMap[(gameId as num).toInt()] = ct.toString();
        }
      }

      setState(() {
        _playing = List<Map<String, dynamic>>.from(results[0] as List);
        _toPlay = List<Map<String, dynamic>>.from(results[1] as List);
        _completionTypeMap = completionMap;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar tus juegos.';
        });
      }
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
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
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
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

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
