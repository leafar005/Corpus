import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/milestone_progress_bar.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/game_card.dart';

class AchievementGamesScreen extends StatefulWidget {
  final String achievementId;
  final String achievementName;
  final int? companyId;
  final int? collectionId;
  final int? franchiseId;
  final int? collectionId2;
  final int? franchiseId2;
  final List<Map<String, dynamic>> milestones;

  const AchievementGamesScreen({
    super.key,
    required this.achievementId,
    required this.achievementName,
    this.companyId,
    this.collectionId,
    this.franchiseId,
    this.collectionId2,
    this.franchiseId2,
    this.milestones = const [{'target': 1, 'xp': 10}],
  });

  @override
  State<AchievementGamesScreen> createState() => _AchievementGamesScreenState();
}

class _AchievementGamesScreenState extends State<AchievementGamesScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _results = [];
  bool _isLoading = false;
  int _searchOffset = 0;
  bool _hasMoreSearchResults = true;
  int _searchVersion = 0;

  Map<int, String> _userGamesStatus = {};
  int _completedGamesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserGamesCache().then((_) {
      _performSearch(isInitial: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        _performSearch(isInitial: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserGamesCache() async {
    setState(() {
      _isLoading = true;
    }); // Fix loading state flash
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('reviews')
        .select('game_id, status, games(developer, collection, category)')
        .eq('user_id', userId);

    final List<dynamic> data = response;

    int completedCount = 0;

    if (mounted) {
      setState(() {
        _userGamesStatus = {
          for (var item in data)
            item['game_id'] as int: item['status'] as String,
        };

        // Calcular el progreso del logro
        final aId = widget.achievementId;
        for (var item in data) {
          if (item['status'] != 'beaten') continue;

          final game = item['games'];
          if (game == null) continue;

          final category = game['category'] as int?;
          if (category != null && ![0, 8, 9, 10, 11].contains(category)) {
            continue;
          }

          final dev = (game['developer'] as String?)?.toLowerCase() ?? '';
          final colJson = game['collection'];
          String col = '';
          if (colJson is String) {
            col = colJson.toLowerCase();
          } else if (colJson is Map && colJson['name'] != null) {
            col = colJson['name']?.toString().toLowerCase() ?? '';
          }

          bool matches = false;
          if (aId.startsWith('kojima') && dev.contains('kojima')) {
            matches = true;
          } else if (aId.startsWith('fromsoftware') &&
              dev.contains('fromsoftware')) {
            matches = true;
          } else if (aId.startsWith('nintendo') && dev.contains('nintendo')) {
            matches = true;
          } else if (aId.startsWith('capcom') && dev.contains('capcom')) {
            matches = true;
          } else if (aId.startsWith('naughty_dog') && dev.contains('naughty dog')) {
            matches = true;
          } else if (aId.startsWith('rockstar') && dev.contains('rockstar')) {
            matches = true;
          } else if (aId.startsWith('cd_projekt') && dev.contains('cd projekt')) {
            matches = true;
          } else if (aId.startsWith('zelda') && col.contains('zelda')) {
            matches = true;
          } else if (aId.startsWith('mario') && col.contains('mario')) {
            matches = true;
          } else if (aId.startsWith('pokemon') &&
              (col.contains('pokemon') || col.contains('pokémon'))) {
            matches = true;
          } else if (aId.startsWith('resident_evil') &&
              col.contains('resident evil')) {
            matches = true;
          } else if (aId.startsWith('dark_souls') && col.contains('dark souls')) {
            matches = true;
          } else if (aId.startsWith('assassins_creed') &&
              col.contains('assassin\'s creed')) {
            matches = true;
          }

          if (matches) completedCount++;
        }
        _completedGamesCount = completedCount;
        if (_results.isNotEmpty) {
          _sortResults();
        }
      });
    }
  }

  void _sortResults() {
    _results.sort((a, b) {
      final aId = a['id'] ?? a['igdb_id'] ?? 0;
      final bId = b['id'] ?? b['igdb_id'] ?? 0;
      final aBeaten = _userGamesStatus[aId] == 'beaten';
      final bBeaten = _userGamesStatus[bId] == 'beaten';
      
      // 1. Primero los completados (beaten)
      if (aBeaten && !bBeaten) return -1;
      if (!aBeaten && bBeaten) return 1;
      
      // 2. Dentro de cada grupo, ordenar por popularidad desc
      final aRatings = (a['total_rating_count'] ?? 0) as int;
      final bRatings = (b['total_rating_count'] ?? 0) as int;
      return bRatings.compareTo(aRatings);
    });
  }

  Future<void> _performSearch({required bool isInitial}) async {
    if (!isInitial && (_isLoading || !_hasMoreSearchResults)) return;

    if (isInitial) {
      _searchOffset = 0;
      _results.clear();
      _hasMoreSearchResults = true;
    }

    final int version = ++_searchVersion;
    setState(() {
      _isLoading = true;
    });

    try {
      final games = await IGDBService.getAchievementGames(
        companyId: widget.companyId,
        collectionId: widget.collectionId,
        franchiseId: widget.franchiseId,
        collectionId2: widget.collectionId2,
        franchiseId2: widget.franchiseId2,
        offset: _searchOffset,
        limit: 35,
      );

      if (mounted && version == _searchVersion) {
        setState(() {
          if (games.isEmpty || games.length < 35) {
            // Si recibimos menos de 35 juegos (el límite), no hay más páginas
            _hasMoreSearchResults = false;
          }
          if (games.isNotEmpty) {
            _results.addAll(games);
            _searchOffset += 35;
            _sortResults();
          }
        });
      }
    } catch (e) {
      debugPrint('[CORPUS] Error IGDB achievement search: $e');
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.achievementName)),
      body: _results.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (!_isLoading)
                  SliverToBoxAdapter(child: _buildAchievementProgress()),
                if (_results.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _results.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final game = _results[index];
                          final int gameId = game['id'] ?? game['igdb_id'] ?? 0;

                          // Check if beaten
                          final status = _userGamesStatus[gameId];
                          final isBeaten = status == 'beaten';
                          final isGrayscale = !isBeaten;

                          return GameCard(
                            game: game,
                            isInLibrary: status != null,
                            userRating:
                                0.0, // We could fetch rating too, but not needed for B&W filter
                            isGrayscale: isGrayscale,
                            onReturn: () {
                              _fetchUserGamesCache();
                            },
                          );
                        },
                        childCount:
                            _results.length + (_hasMoreSearchResults ? 1 : 0),
                      ),
                    ),
                  ),
                if (_results.isEmpty && !_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No se encontraron juegos para este logro.'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAchievementProgress() {
    List<Map<String, dynamic>> milestones = widget.milestones;
    if (milestones.isEmpty) milestones = [{'target': 1, 'xp': 10}];
    
    int currentTarget = milestones.last['target'] as int;
    for (var m in milestones) {
      int t = m['target'] as int;
      if (_completedGamesCount < t) {
        currentTarget = t;
        break;
      }
    }

    bool isMaxed = _completedGamesCount >= (milestones.last['target'] as int);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso de la Saga',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                isMaxed ? 'Maestro' : 'Siguiente hito: $currentTarget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isMaxed
                      ? Colors.amber
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MilestoneProgressBar(
            current: _completedGamesCount,
            milestones: milestones,
            color: isMaxed
                ? Colors.amber
                : Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 12),
          Text(
            '$_completedGamesCount juegos completados',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
