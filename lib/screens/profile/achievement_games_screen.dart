import 'dart:async';
import 'package:flutter/material.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import '../../models/models.dart';
import '../../widgets/milestone_progress_bar.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/widgets/corpus_section_title.dart';

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
  List<dynamic> _results = [];
  bool _isLoading = false;
  int _searchOffset = 0;
  bool _hasMoreSearchResults = true;
  int _searchVersion = 0;
  Map<int, String> _userGamesStatus = {};
  int _completedGamesCount = 0;
  List<Map<String, dynamic>> _injectedBeatenGames = [];
  bool _showTitle = false;

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

      final shouldShow = _scrollController.offset > 60;
      if (shouldShow != _showTitle) {
        setState(() {
          _showTitle = shouldShow;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserGamesCache() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final reviewsResp = await Supabase.instance.client
          .from('reviews')
          .select('*, games(*)')
          .eq('user_id', userId);

      final userGamesResp = await Supabase.instance.client
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', userId);

      final Map<int, dynamic> uniqueGames = {};
      for (var item in [...reviewsResp, ...userGamesResp]) {
        final game = item['games'];
        if (game == null) continue;
        final int? gameId = game['igdb_id'] as int?;
        if (gameId != null) {
          uniqueGames[gameId] = item;
        }
      }
      final List<dynamic> data = uniqueGames.values.toList();
      int completedCount = 0;
      final List<Map<String, dynamic>> beatenMatchingGames = [];

      if (mounted) {
        _userGamesStatus = {
          for (var item in data)
            if (item['games'] != null && item['games']['igdb_id'] != null)
              item['games']['igdb_id'] as int: item['status'] as String,
        };

        final aId = widget.achievementId;
        for (var item in data) {
          if (item['status'] != 'beaten') continue;
          final game = item['games'];
          if (game == null) continue;
          final category = game['category'] as int?;
          if (category != null && category == 1) continue;
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

          final title = (game['title'] as String?)?.toLowerCase() ?? '';
          final bool isCrossover =
              title.contains('smash bros') ||
              title.contains('project x zone') ||
              title.contains('vs. capcom') ||
              title.contains('vs capcom') ||
              title.contains('all-stars') ||
              title.contains('fortnite') ||
              title.contains('dead by daylight') ||
              title.contains('teppen') ||
              title.contains('poker night') ||
              title.contains('nintendo land') ||
              title.contains('cross tag');
          bool matches = false;

          if (aId.startsWith('kojima') &&
              (dev.contains('kojima') ||
                  saga.contains('metal gear') ||
                  saga.contains('zone of the enders') ||
                  saga.contains('boktai') ||
                  title.contains('metal gear') ||
                  title.contains('death stranding') ||
                  title.contains('snatcher') ||
                  title.contains('policenauts') ||
                  title.contains('zone of the enders') ||
                  title.contains('boktai'))) {
            matches = true;
          } else if (aId.startsWith('fromsoftware') &&
              (dev.contains('fromsoftware') ||
                  title.contains("demon's souls") ||
                  title.contains("demon souls") ||
                  title.contains('dark souls') ||
                  title.contains('elden ring') ||
                  title.contains('bloodborne') ||
                  title.contains('sekiro') ||
                  title.contains('armored core') ||
                  saga.contains('dark souls') ||
                  saga.contains('elden ring') ||
                  saga.contains('bloodborne') ||
                  saga.contains('sekiro'))) {
            matches = true;
          } else if (aId.startsWith('nintendo') &&
              (dev.contains('nintendo') ||
                  dev.contains('hal laboratory') ||
                  dev.contains('intelligent systems') ||
                  dev.contains('game freak') ||
                  dev.contains('monolith soft') ||
                  dev.contains('retro studios') ||
                  dev.contains('next level games') ||
                  dev.contains('grezzo') ||
                  dev.contains('good-feel') ||
                  dev.contains('nd cube') ||
                  dev.contains('sora ltd') ||
                  dev.contains('camelot') ||
                  dev.contains('creatures inc') ||
                  saga.contains('mario') ||
                  saga.contains('zelda') ||
                  saga.contains('pokemon') ||
                  saga.contains('pokémon') ||
                  saga.contains('metroid') ||
                  saga.contains('kirby') ||
                  saga.contains('donkey kong') ||
                  saga.contains('fire emblem') ||
                  saga.contains('splatoon') ||
                  saga.contains('pikmin') ||
                  saga.contains('animal crossing') ||
                  saga.contains('star fox') ||
                  saga.contains('xenoblade') ||
                  saga.contains('smash bros') ||
                  title.contains('mario') ||
                  title.contains('zelda') ||
                  title.contains('pokemon') ||
                  title.contains('pokémon') ||
                  title.contains('metroid') ||
                  title.contains('kirby') ||
                  title.contains('donkey kong') ||
                  title.contains('fire emblem') ||
                  title.contains('splatoon') ||
                  title.contains('pikmin') ||
                  title.contains('animal crossing') ||
                  title.contains('star fox') ||
                  title.contains('xenoblade'))) {
            matches = true;
          } else if (aId.startsWith('capcom') &&
              (dev.contains('capcom') ||
                  dev.contains('blue castle') ||
                  dev.contains('ninja theory') ||
                  dev.contains('neobards') ||
                  dev.contains('m-two') ||
                  dev.contains('hexadrive') ||
                  dev.contains('qloc') ||
                  dev.contains('tose') ||
                  (!isCrossover &&
                      (saga.contains('resident evil') ||
                          saga.contains('monster hunter') ||
                          saga.contains('devil may cry') ||
                          saga.contains('street fighter') ||
                          saga.contains('mega man') ||
                          saga.contains('ace attorney') ||
                          saga.contains('dead rising') ||
                          saga.contains(
                            'dragon'
                            's dogma',
                          ) ||
                          saga.contains('onimusha') ||
                          saga.contains('dino crisis') ||
                          saga.contains('okami') ||
                          saga.contains('darkstalkers') ||
                          title.contains('resident evil') ||
                          title.contains('monster hunter') ||
                          title.contains('devil may cry') ||
                          title.contains('street fighter') ||
                          title.contains('mega man') ||
                          title.contains('ace attorney') ||
                          title.contains('dead rising') ||
                          title.contains(
                            'dragon'
                            's dogma',
                          ) ||
                          title.contains('onimusha') ||
                          title.contains('dino crisis') ||
                          title.contains('okami') ||
                          title.contains('darkstalkers'))))) {
            matches = true;
          } else if (aId.startsWith('naughty_dog') &&
              (dev.contains('naughty dog') ||
                  saga.contains('uncharted') ||
                  saga.contains('the last of us') ||
                  saga.contains('jak and daxter') ||
                  saga.contains('crash bandicoot'))) {
            matches = true;
          } else if (aId.startsWith('rockstar') &&
              (dev.contains('rockstar') ||
                  saga.contains('grand theft auto') ||
                  saga.contains('red dead') ||
                  saga.contains('max payne') ||
                  saga.contains('bully') ||
                  saga.contains('l.a. noire'))) {
            matches = true;
          } else if (aId.startsWith('cd_projekt') &&
              (dev.contains('cd projekt') ||
                  saga.contains('witcher') ||
                  saga.contains('cyberpunk'))) {
            matches = true;
          } else if (aId.startsWith('valve') &&
              (dev.contains('valve') ||
                  dev.contains('crowbar collective') ||
                  title.contains('black mesa') ||
                  saga.contains('half-life') ||
                  saga.contains('portal') ||
                  saga.contains('left 4 dead') ||
                  saga.contains('counter-strike') ||
                  saga.contains('team fortress'))) {
            matches = true;
          } else if (aId.startsWith('remedy') &&
              (dev.contains('remedy') ||
                  saga.contains('alan wake') ||
                  saga.contains('control') ||
                  saga.contains('max payne'))) {
            matches = true;
          } else if (aId.startsWith('team_ninja') &&
              (dev.contains('team ninja') ||
                  dev.contains('koei tecmo') ||
                  saga.contains('ninja gaiden') ||
                  saga.contains('nioh') ||
                  saga.contains('dead or alive'))) {
            matches = true;
          } else if (aId.startsWith('square_enix') &&
              (dev.contains('square enix') ||
                  dev.contains('squaresoft') ||
                  dev.contains('enix') ||
                  saga.contains('final fantasy') ||
                  saga.contains('kingdom hearts'))) {
            matches = true;
          } else if (aId.startsWith('bethesda') &&
              (dev.contains('bethesda') ||
                  dev.contains('zenimax') ||
                  dev.contains('arkane') ||
                  dev.contains('id software') ||
                  dev.contains('machinegames') ||
                  saga.contains('elder scrolls') ||
                  saga.contains('fallout') ||
                  saga.contains('doom'))) {
            matches = true;
          } else if (aId.startsWith('konami') &&
              (dev.contains('konami') ||
                  dev.contains('bloober team') ||
                  dev.contains('mercurysteam') ||
                  dev.contains('platinumgames') ||
                  dev.contains('hexadrive') ||
                  dev.contains('double helix') ||
                  dev.contains('climax') ||
                  dev.contains('wayforward') ||
                  saga.contains('metal gear') ||
                  saga.contains('silent hill') ||
                  saga.contains('castlevania') ||
                  saga.contains('contra') ||
                  saga.contains('pro evolution') ||
                  saga.contains('efootball') ||
                  saga.contains('suikoden') ||
                  saga.contains('bomberman') ||
                  saga.contains('frogger') ||
                  saga.contains('zone of the enders') ||
                  title.contains('metal gear') ||
                  title.contains('silent hill') ||
                  title.contains('castlevania') ||
                  title.contains('contra') ||
                  title.contains('pro evolution') ||
                  title.contains('efootball') ||
                  title.contains('suikoden') ||
                  title.contains('bomberman') ||
                  title.contains('frogger') ||
                  title.contains('zone of the enders'))) {
            matches = true;
          } else if (aId.startsWith('pokemon') &&
              !isCrossover &&
              (saga.contains('pokemon') ||
                  saga.contains('pokémon') ||
                  title.contains('pokemon') ||
                  title.contains('pokémon'))) {
            matches = true;
          } else if (!isCrossover) {
            if (aId.startsWith('zelda') &&
                (saga.contains('zelda') || title.contains('zelda'))) {
              matches = true;
            } else if (aId.startsWith('mario') &&
                (saga.contains('mario') || title.contains('super mario'))) {
              matches = true;
            } else if (aId.startsWith('resident_evil') &&
                (saga.contains('resident evil') ||
                    title.contains('resident evil'))) {
              matches = true;
            } else if (aId.startsWith('dark_souls') &&
                (saga.contains('dark souls') || title.contains('dark souls'))) {
              matches = true;
            } else if (aId.startsWith('assassins_creed') &&
                (saga.contains("assassin's creed") ||
                    title.contains("assassin's creed"))) {
              matches = true;
            } else if (aId.startsWith('final_fantasy') &&
                (saga.contains('final fantasy') ||
                    title.contains('final fantasy'))) {
              matches = true;
            } else if (aId.startsWith('call_of_duty') &&
                (saga.contains('call of duty') ||
                    title.contains('call of duty'))) {
              matches = true;
            } else if (aId.startsWith('elder_scrolls') &&
                (saga.contains('elder scrolls') ||
                    title.contains('elder scrolls'))) {
              matches = true;
            } else if (aId.startsWith('god_of_war') &&
                (saga.contains('god of war') || title.contains('god of war'))) {
              matches = true;
            } else if (aId.startsWith('sonic') &&
                (saga.contains('sonic') || title.contains('sonic'))) {
              matches = true;
            } else if (aId.startsWith('tomb_raider') &&
                (saga.contains('tomb raider') ||
                    title.contains('tomb raider'))) {
              matches = true;
            } else if (aId.startsWith('monster_hunter') &&
                (saga.contains('monster hunter') ||
                    title.contains('monster hunter'))) {
              matches = true;
            } else if (aId.startsWith('kingdom_hearts') &&
                (saga.contains('kingdom hearts') ||
                    title.contains('kingdom hearts'))) {
              matches = true;
            } else if (aId.startsWith('silent_hill') &&
                (saga.contains('silent hill') ||
                    title.contains('silent hill'))) {
              matches = true;
            } else if (aId.startsWith('metroid') &&
                (saga.contains('metroid') || title.contains('metroid'))) {
              matches = true;
            } else if (aId.startsWith('kirby') &&
                (saga.contains('kirby') || title.contains('kirby'))) {
              matches = true;
            } else if (aId.startsWith('devil_may_cry') &&
                (saga.contains('devil may cry') ||
                    title.contains('devil may cry'))) {
              matches = true;
            } else if (aId.startsWith('castlevania') &&
                (saga.contains('castlevania') ||
                    title.contains('castlevania'))) {
              matches = true;
            } else if (aId.startsWith('mass_effect') &&
                (saga.contains('mass effect') ||
                    title.contains('mass effect'))) {
              matches = true;
            } else if (aId.startsWith('doom') &&
                (saga.contains('doom') || title.contains('doom'))) {
              matches = true;
            } else if (aId.startsWith('bioshock') &&
                (saga.contains('bioshock') || title.contains('bioshock'))) {
              matches = true;
            } else if (aId.startsWith('borderlands') &&
                (saga.contains('borderlands') ||
                    title.contains('borderlands'))) {
              matches = true;
            } else if (aId.startsWith('metro') &&
                (saga.contains('metro') ||
                    title.contains('metro 2033') ||
                    title.contains('metro: last light') ||
                    title.contains('metro exodus')) &&
                !saga.contains('metroid') &&
                !title.contains('metroid')) {
              matches = true;
            } else if (aId.startsWith('dead_space') &&
                (saga.contains('dead space') || title.contains('dead space'))) {
              matches = true;
            } else if (aId.startsWith('yakuza') &&
                (saga.contains('yakuza') ||
                    saga.contains('like a dragon') ||
                    title.contains('yakuza') ||
                    title.contains('like a dragon'))) {
              matches = true;
            } else if (aId.startsWith('xenoblade') &&
                (title.contains('xenoblade') || saga.contains('xenoblade'))) {
              matches = true;
            } else if (aId.startsWith('persona') &&
                (saga.contains('persona') ||
                    saga.contains('shin megami tensei') ||
                    title.contains('persona') ||
                    title.contains('shin megami tensei'))) {
              matches = true;
            } else if (aId.startsWith('halo') &&
                (saga.contains('halo') || title.contains('halo'))) {
              matches = true;
            }
          }
          if (matches) {
            completedCount++;
            final gMap = Map<String, dynamic>.from(game as Map);
            gMap['id'] = gMap['igdb_id'] ?? gMap['id'];
            gMap['name'] = gMap['title'] ?? gMap['name'];
            beatenMatchingGames.add(gMap);
          }
        }
        _completedGamesCount = completedCount;
        _injectedBeatenGames = beatenMatchingGames;
        _results = List.from(_injectedBeatenGames);
      }
    } catch (e) {
      debugPrint('[CORPUS] Error cargando caché de usuario: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sortResults() {
    _results.sort((a, b) {
      final aId = a['id'] ?? a['igdb_id'] ?? 0;
      final bId = b['id'] ?? b['igdb_id'] ?? 0;
      final aBeaten = _userGamesStatus[aId] == 'beaten';
      final bBeaten = _userGamesStatus[bId] == 'beaten';
      if (aBeaten && !bBeaten) return -1;
      if (!aBeaten && bBeaten) return 1;
      final aRatings = (a['total_rating_count'] ?? 0) as int;
      final bRatings = (b['total_rating_count'] ?? 0) as int;
      return bRatings.compareTo(aRatings);
    });
  }

  Future<void> _performSearch({required bool isInitial}) async {
    if (!isInitial && (_isLoading || !_hasMoreSearchResults)) return;
    if (isInitial) {
      _searchOffset = 0;
      _results = List.from(_injectedBeatenGames);
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
            _hasMoreSearchResults = false;
          }
          if (games.isNotEmpty) {
            final cleanGames = games.where((g) {
              final gTitle = (g['name'] ?? g['title'] ?? '')
                  .toString()
                  .toLowerCase();
              final isCollab =
                  gTitle.contains('smash bros') ||
                  gTitle.contains('project x zone') ||
                  gTitle.contains('vs. capcom') ||
                  gTitle.contains('vs capcom') ||
                  gTitle.contains('all-stars') ||
                  gTitle.contains('fortnite') ||
                  gTitle.contains('dead by daylight') ||
                  gTitle.contains('teppen') ||
                  gTitle.contains('poker night') ||
                  gTitle.contains('nintendo land') ||
                  gTitle.contains('cross tag');
              if (widget.franchiseId != null || widget.collectionId != null) {
                if (isCollab) return false;
              }
              if (widget.companyId == 37) {
                if (gTitle.contains('god of war') ||
                    gTitle.contains('grand theft auto') ||
                    gTitle.contains('gta ') ||
                    gTitle.contains('warcraft') ||
                    gTitle.contains('baldurs gate') ||
                    gTitle.contains('half-life')) {
                  return false;
                }
              }
              return true;
            }).toList();

            for (final g in cleanGames) {
              final int gId = g['id'] ?? g['igdb_id'] ?? 0;
              if (!_results.any((r) => (r['id'] ?? r['igdb_id']) == gId)) {
                _results.add(g);
              }
            }
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
    final canPopSystem = !Navigator.of(context).canPop();
    return PopScope(
      canPop: canPopSystem,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          AppNavigationController.instance.requestBack(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedOpacity(
            opacity: _showTitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: CorpusScreenTitle(widget.achievementName),
          ),
        ),
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
                              childAspectRatio: IgdbConstants.coverAspectRatio,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _results.length) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final game = _results[index];
                            final int gameId =
                                game['id'] ?? game['igdb_id'] ?? 0;
                            final status = _userGamesStatus[gameId];
                            final isBeaten = status == 'beaten';
                            final isGrayscale = !isBeaten;
                            return GameCard(
                              game: Game.fromMap(game),
                              isInLibrary: status != null,
                              userRating: 0.0,
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
                        child: Text(
                          'No se encontraron juegos para este logro.',
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildAchievementProgress() {
    List<Map<String, dynamic>> milestones = widget.milestones;
    if (milestones.isEmpty) {
      milestones = [
        {'target': 1, 'xp': 10},
      ];
    }
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
                    color:
                        widget.achievementColor ??
                        Theme.of(context).colorScheme.primary,
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
          const SizedBox(height: 8),
          Text(
            widget.achievementName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
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
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}
