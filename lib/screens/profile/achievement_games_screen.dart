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
  final IconData? achievementIcon;
  final Color? achievementColor;

  const AchievementGamesScreen({
    super.key,
    required this.achievementId,
    required this.achievementName,
    this.companyId,
    this.collectionId,
    this.franchiseId,
    this.collectionId2,
    this.franchiseId2,
    required this.milestones,
    this.achievementIcon,
    this.achievementColor,
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
        .select('game_id, status, games(developer, collection, category, franchises, release_date)')
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

          final releaseDateStr = game['release_date'] as String?;
          if (releaseDateStr != null) {
            final releaseDate = DateTime.tryParse(releaseDateStr);
            if (releaseDate != null && releaseDate.isAfter(DateTime.now())) {
              continue;
            }
          }

          final dev = (game['developer'] as String?)?.toLowerCase() ?? '';
          final colJson = game['collection'];
          String col = '';
          if (colJson is String) {
            col = colJson.toLowerCase();
          } else if (colJson is Map && colJson['name'] != null) {
            col = colJson['name']?.toString().toLowerCase() ?? '';
          }
          final franchises = game['franchises'] as List<dynamic>?;
          String fra = franchises?.join(' ').toLowerCase() ?? '';
          String saga = '$col $fra';

          // 1. FILTRO ANTICONTAMINACIÓN: Blacklist de crossovers y collabs
          final title = (game['title'] as String?)?.toLowerCase() ?? '';
          final bool isCrossover = title.contains('smash bros') ||
                                   title.contains('project x zone') ||
                                   title.contains('vs. capcom') ||
                                   title.contains('vs capcom') ||
                                   title.contains('all-stars') ||
                                   title.contains('fortnite') ||
                                   title.contains('dead by daylight') ||
                                   title.contains('teppen') ||
                                   title.contains('poker night') ||
                                   title.contains('cross tag');

          bool matches = false;

          // 2. COMPAÑÍAS: Añadimos las sagas estrella al chequeo del desarrollador.
          // Así, si juegas un remake/remaster hecho por externos (QLOC, Bluepoint, Bloober), contará igual para la compañía original.
          if (aId.startsWith('kojima') && (dev.contains('kojima') || saga.contains('metal gear') || saga.contains('death stranding') || saga.contains('zone of the enders'))) { matches = true; }
          else if (aId.startsWith('fromsoftware') && (dev.contains('fromsoftware') || saga.contains('dark souls') || saga.contains('elden ring') || saga.contains('bloodborne') || saga.contains('sekiro') || saga.contains("demon's souls") || saga.contains('armored core'))) { matches = true; }
          else if (aId.startsWith('nintendo') && dev.contains('nintendo')) { matches = true; }
          else if (aId.startsWith('capcom') && (dev.contains('capcom') || (!isCrossover && (saga.contains('resident evil') || saga.contains('monster hunter') || saga.contains('devil may cry') || saga.contains('street fighter') || saga.contains('mega man') || saga.contains('ace attorney') || saga.contains('dead rising'))))) { matches = true; }
          else if (aId.startsWith('naughty_dog') && (dev.contains('naughty dog') || saga.contains('uncharted') || saga.contains('the last of us') || saga.contains('jak and daxter') || saga.contains('crash bandicoot'))) { matches = true; }
          else if (aId.startsWith('rockstar') && (dev.contains('rockstar') || saga.contains('grand theft auto') || saga.contains('red dead') || saga.contains('max payne') || saga.contains('bully') || saga.contains('l.a. noire'))) { matches = true; }
          else if (aId.startsWith('cd_projekt') && (dev.contains('cd projekt') || saga.contains('witcher') || saga.contains('cyberpunk'))) { matches = true; }
          else if (aId.startsWith('valve') && (dev.contains('valve') || saga.contains('half-life') || saga.contains('portal') || saga.contains('left 4 dead') || saga.contains('counter-strike') || saga.contains('team fortress'))) { matches = true; }
          else if (aId.startsWith('remedy') && (dev.contains('remedy') || saga.contains('alan wake') || saga.contains('control') || saga.contains('max payne'))) { matches = true; }
          else if (aId.startsWith('team_ninja') && (dev.contains('team ninja') || dev.contains('koei tecmo') || saga.contains('ninja gaiden') || saga.contains('nioh') || saga.contains('dead or alive'))) { matches = true; }
          else if (aId.startsWith('konami') && (dev.contains('konami') || saga.contains('metal gear') || saga.contains('silent hill') || saga.contains('castlevania') || saga.contains('contra') || saga.contains('pro evolution') || saga.contains('efootball') || saga.contains('suikoden'))) { matches = true; }
          else if (aId.startsWith('pokemon') && (dev.contains('game freak') || (!isCrossover && saga.contains('pokemon')))) { matches = true; }

          // 3. SAGAS Y FRANQUICIAS: Exigimos estrictamente !isCrossover
          else if (!isCrossover) {
            if (aId.startsWith('zelda') && saga.contains('zelda')) { matches = true; }
            else if (aId.startsWith('mario') && saga.contains('mario')) { matches = true; }
            else if (aId.startsWith('resident_evil') && saga.contains('resident evil')) { matches = true; }
            else if (aId.startsWith('dark_souls') && (saga.contains('dark souls') || saga.contains('elden ring'))) { matches = true; }
            else if (aId.startsWith('assassins_creed') && saga.contains("assassin's creed")) { matches = true; }
            else if (aId.startsWith('final_fantasy') && saga.contains('final fantasy')) { matches = true; }
            else if (aId.startsWith('call_of_duty') && saga.contains('call of duty')) { matches = true; }
            else if (aId.startsWith('elder_scrolls') && saga.contains('elder scrolls')) { matches = true; }
            else if (aId.startsWith('god_of_war') && saga.contains('god of war')) { matches = true; }
            else if (aId.startsWith('sonic') && saga.contains('sonic')) { matches = true; }
            else if (aId.startsWith('tomb_raider') && saga.contains('tomb raider')) { matches = true; }
            else if (aId.startsWith('monster_hunter') && saga.contains('monster hunter')) { matches = true; }
            else if (aId.startsWith('kingdom_hearts') && saga.contains('kingdom hearts')) { matches = true; }
            else if (aId.startsWith('silent_hill') && saga.contains('silent hill')) { matches = true; }
            else if (aId.startsWith('metroid') && saga.contains('metroid')) { matches = true; }
            else if (aId.startsWith('kirby') && saga.contains('kirby')) { matches = true; }
            else if (aId.startsWith('devil_may_cry') && saga.contains('devil may cry')) { matches = true; }
            else if (aId.startsWith('castlevania') && saga.contains('castlevania')) { matches = true; }
            else if (aId.startsWith('mass_effect') && saga.contains('mass effect')) { matches = true; }
            else if (aId.startsWith('doom') && saga.contains('doom')) { matches = true; }
            else if (aId.startsWith('bioshock') && saga.contains('bioshock')) { matches = true; }
            else if (aId.startsWith('borderlands') && saga.contains('borderlands')) { matches = true; }
            else if (aId.startsWith('metro') && saga.contains('metro')) { matches = true; }
            else if (aId.startsWith('dead_space') && saga.contains('dead space')) { matches = true; }
            else if (aId.startsWith('yakuza') && (saga.contains('yakuza') || saga.contains('like a dragon'))) { matches = true; }
            else if (aId.startsWith('xenoblade') && saga.contains('xenoblade')) { matches = true; }
            else if (aId.startsWith('persona') && (saga.contains('persona') || saga.contains('shin megami tensei'))) { matches = true; }
            else if (aId.startsWith('halo') && saga.contains('halo')) { matches = true; }
          }


          if (matches) completedCount++;
        }
        _completedGamesCount = completedCount;
        if (_results.isNotEmpty) {
          _sortResults();
        }
        _isLoading = false; // Add this line to fix the progress bar disappearing!
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
            // FILTRO DE LIMPIEZA UI: Eliminamos cameos y anomalías de publicación japonesa
            final cleanGames = games.where((g) {
              final gTitle = (g['name'] ?? g['title'] ?? '').toString().toLowerCase();
              final isCollab = gTitle.contains('smash bros') ||
                               gTitle.contains('project x zone') ||
                               gTitle.contains('vs. capcom') ||
                               gTitle.contains('vs capcom') ||
                               gTitle.contains('all-stars') ||
                               gTitle.contains('fortnite') ||
                               gTitle.contains('dead by daylight') ||
                               gTitle.contains('teppen') ||
                               gTitle.contains('poker night');

              // Si es un logro de franquicia o saga, no queremos ver crossovers
              if (widget.franchiseId != null || widget.collectionId != null) {
                if (isCollab) return false;
              }
              // Si estamos viendo el catálogo de Capcom (ID 37), ocultamos los juegos que solo publicaron en Japón
              if (widget.companyId == 37) {
                if (gTitle.contains('god of war') || gTitle.contains('grand theft auto') || gTitle.contains('gta ') || gTitle.contains('warcraft') || gTitle.contains('baldurs gate') || gTitle.contains('half-life')) {
                  return false;
                }
              }
              return true;
            }).toList();

            _results.addAll(cleanGames);
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
              Row(
                children: [
                  Icon(
                    widget.achievementIcon ?? Icons.emoji_events,
                    color: widget.achievementColor ?? Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Progreso de la Saga',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
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
          Text(
            '$_completedGamesCount juegos completados',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          MilestoneProgressBar(
            current: _completedGamesCount,
            milestones: milestones,
            color: isMaxed
                ? Colors.amber
                : Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
