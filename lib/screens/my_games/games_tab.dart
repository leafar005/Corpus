import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/widgets/game_card.dart';

/// Tab "Juegos" en Mis juegos: dos filas (Jugando + Por jugar).
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
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  List<Map<String, dynamic>> _playing = [];
  List<Map<String, dynamic>> _toPlay = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('user_games')
            .select('*, games!inner(*)')
            .eq('user_id', widget.userId)
            .eq('status', 'playing')
            .order('updated_at', ascending: false)
            .limit(60),
        client
            .from('user_games')
            .select('*, games!inner(*)')
            .eq('user_id', widget.userId)
            .eq('status', 'to_play')
            .order('updated_at', ascending: false)
            .limit(60),
      ]);

      if (!mounted) return;
      setState(() {
        _playing = List<Map<String, dynamic>>.from(results[0] as List);
        _toPlay = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

    return SliverMainAxisGroup(
      slivers: [
        ..._buildSection(
          title: 'Jugando',
          games: _playing,
          emptyMessage: 'No tienes juegos en curso.',
        ),
        ..._buildSection(
          title: 'Por jugar',
          games: _toPlay,
          emptyMessage: 'Marca juegos como «Por jugar» desde su reseña.',
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: getBottomSpacer(context)),
        ),
      ],
    );
  }

  List<Widget> _buildSection({
    required String title,
    required List<Map<String, dynamic>> games,
    required String emptyMessage,
  }) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      if (games.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        )
      else
        ValueListenableBuilder<int>(
          valueListenable: mobileGridColumnsNotifier,
          builder: (context, columns, _) {
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

                    return GameCard(
                      game: Game.fromMap(gameData),
                      isInLibrary: true,
                      userRating: rating,
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
