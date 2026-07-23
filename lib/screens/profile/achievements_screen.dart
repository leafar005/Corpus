import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/level_calculator.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';

class AchievementsScreen extends StatefulWidget {
  final String userId;
  final int initialXp;

  const AchievementsScreen({
    super.key,
    required this.userId,
    required this.initialXp,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _isLoading = true;
  int _currentXp = 0;
  List<Map<String, dynamic>> _allAchievements = [];
  Map<String, DateTime> _unlockedAchievements = {};
  Map<String, int> _sagaProgress = {};
  Map<String, List<Map<String, dynamic>>> _sagaMilestones = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // IDs verificados directamente contra la API de IGDB.
  // Formato: {'prefijo_logro': {'companyId': X} | {'collectionId': X} | {'franchiseId': X}}
  // Para logros que necesitan COLECCIÓN + FRANQUICIA simultánea, ambos campos están presentes.
  static const Map<String, Map<String, int?>> _achievementIgdbIds = {
    // --- COMPAÑÍAS ---
    'kojima':       {'companyId': 170},
    'fromsoftware': {'companyId': 1012},
    'nintendo':     {'companyId': 70},
    'capcom':       {'companyId': 37},
    'naughty_dog':  {'companyId': 401},
    'rockstar':     {'companyId': 29},
    'cd_projekt':   {'companyId': 908},
    'valve':        {'companyId': 56},
    'square_enix':  {'companyId': 26},
    'bethesda':     {'companyId': 16565},
    'konami':       {'companyId': 129},
    'remedy':       {'companyId': 305},
    'team_ninja':   {'companyId': 769},       // Team NINJA / Koei Tecmo
    // --- Pokémon: no tiene franchise en IGDB, se busca por Game Freak ---
    'pokemon':      {'companyId': 1617},
    // --- COLECCIONES ---
    'zelda':        {'collectionId': 106},
    'mario':        {'collectionId': 240},
    'halo':         {'franchiseId': 137},     // Halo tiene franchise (137), no collection relevante
    'sonic':        {'collectionId': 2156},   // Sonic the Hedgehog collection
    'persona':      {'franchiseId': 552, 'franchiseId2': 538}, // Persona + Shin Megami Tensei
    // --- Dark Souls: tanto colección (543) como franquicia (1124) ---
    'dark_souls':   {'collectionId': 543, 'franchiseId': 1124},
    // --- FRANQUICIAS ---
    'assassins_creed':  {'franchiseId': 571},
    'yakuza':           {'franchiseId': 1467},   // Like a Dragon
    'resident_evil':    {'franchiseId': 29},
    'final_fantasy':    {'franchiseId': 4},
    'call_of_duty':     {'franchiseId': 726},
    'elder_scrolls':    {'franchiseId': 456},
    'god_of_war':       {'franchiseId': 2098},
    'tomb_raider':      {'franchiseId': 279},
    'monster_hunter':   {'franchiseId': 824},
    'kingdom_hearts':   {'franchiseId': 720},
    'silent_hill':      {'franchiseId': 554},
    'metroid':          {'franchiseId': 756},
    'kirby':            {'franchiseId': 789},
    'devil_may_cry':    {'franchiseId': 834},
    'castlevania':      {'franchiseId': 895},
    'mass_effect':      {'franchiseId': 1048},
    'doom':             {'franchiseId': 798},
    'bioshock':         {'collectionId': 1},     // BioShock collection ID=1
    'borderlands':      {'franchiseId': 808},
    'metro':            {'franchiseId': 1344},
    'dead_space':       {'franchiseId': 1386},
    'xenoblade':        {'franchiseId': 1932},
  };

  @override
  void initState() {
    super.initState();
    _currentXp = widget.initialXp;
    _fetchAchievementsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAchievementsData() async {
    try {
      // 1. Refresh XP to make sure it's up to date
      final userResp = await Supabase.instance.client
          .from('users')
          .select('xp')
          .eq('id', widget.userId)
          .maybeSingle();

      if (userResp != null && userResp['xp'] != null) {
        _currentXp = userResp['xp'] as int;
      }

      // 2. Fetch all achievements catalog
      final achievementsResp = await Supabase.instance.client
          .from('achievements')
          .select()
          .order('xp_reward', ascending: true);

      // 3. Fetch user unlocked achievements
      final unlockedResp = await Supabase.instance.client
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', widget.userId);

      final Map<String, DateTime> unlockedMap = {};
      for (var row in unlockedResp) {
        unlockedMap[row['achievement_id'] as String] = DateTime.parse(
          row['unlocked_at'],
        );
      }

      // 4. Fetch user's beaten games for scalable progress
      final reviewsResp = await Supabase.instance.client
          .from('reviews')
          .select('game_id, status, games(developer, collection, category, game_modes, franchises)')
          .eq('user_id', widget.userId)
          .eq('status', 'beaten');

      Map<String, Map<String, dynamic>> grouped = {};
      Map<String, List<Map<String, dynamic>>> sagaMilestones = {};

      for (var ach in achievementsResp) {
        String name = ach['name'] as String;
        String baseName = name.replaceAll(RegExp(r'\s*\(.*\)'), '');
        String aId = ach['id'] as String;
        String groupId = aId;
        final matchSuffix = RegExp(r'_(\d+|all)$').firstMatch(aId);
        if (matchSuffix != null) {
          groupId = aId.substring(0, aId.length - matchSuffix.group(0)!.length);
        }

        int target = 1;
        final match = RegExp(r'_(\d+)$').firstMatch(aId);
        if (match != null) {
          target = int.parse(match.group(1)!);
        } else if (aId == 'lone_wolf') {
          target = 50;
        } else if (aId.endsWith('_all')) {
          if (aId.startsWith('fromsoftware') || aId.startsWith('zelda')) target = 7;
          else if (aId.startsWith('mario')) target = 15;
          else if (aId.startsWith('dark_souls')) target = 3;
        }

        if (!grouped.containsKey(groupId)) {
          grouped[groupId] = Map<String, dynamic>.from(ach);
          grouped[groupId]!['name'] = baseName;
          grouped[groupId]!['original_name'] = name;
          sagaMilestones[groupId] = [{'target': target, 'xp': ach['xp_reward']}];
        } else {
          sagaMilestones[groupId]!.add({'target': target, 'xp': ach['xp_reward']});
          int currentXp = grouped[groupId]!['xp_reward'] as int;
          int newXp = ach['xp_reward'] as int;
          if (newXp > currentXp) {
            grouped[groupId]!['id'] = aId;
            grouped[groupId]!['name'] = baseName; // Update display name to highest tier
            grouped[groupId]!['description'] = ach['description'];
            grouped[groupId]!['xp_reward'] = ach['xp_reward'];
            grouped[groupId]!['rarity'] = ach['rarity'];
            grouped[groupId]!['original_name'] = name;
          }
        }
      }
      
      for (var list in sagaMilestones.values) {
        list.sort((a, b) => (a['target'] as int).compareTo(b['target'] as int));
      }

      final Map<String, int> sagaProgress = _calculateSagaProgress(reviewsResp, grouped.values.toList());

      if (mounted) {
        setState(() {
          _allAchievements = grouped.values.toList();
          _unlockedAchievements = unlockedMap;
          _sagaProgress = sagaProgress;
          _sagaMilestones = sagaMilestones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CORPUS] Error fetching achievements: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, int> _calculateSagaProgress(List<dynamic> data, List<Map<String, dynamic>> achievementsList) {
    Map<String, int> counts = {};
    for (var item in data) {
      if (item['status'] != 'beaten') continue;
      final game = item['games'];
      if (game == null) continue;
      final category = game['category'] as int?;
      if (category != null && ![0, 8, 9, 10, 11].contains(category)) continue;

      final releaseDateStr = game['release_date'] as String?;
      if (releaseDateStr != null) {
        final releaseDate = DateTime.tryParse(releaseDateStr);
        if (releaseDate != null && releaseDate.isAfter(DateTime.now())) {
          continue;
        }
      }

      final dev = (game['developer'] as String?)?.toLowerCase() ?? '';
      final gameModes = game['game_modes'] as List<dynamic>?;
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

      void inc(String prefix) {
        counts[prefix] = (counts[prefix] ?? 0) + 1;
      }

      if (dev.contains('kojima')) inc('kojima');
      if (dev.contains('fromsoftware')) inc('fromsoftware');
      if (dev.contains('nintendo')) inc('nintendo');
      if (dev.contains('capcom')) inc('capcom');
      if (dev.contains('naughty dog')) inc('naughty_dog');
      if (dev.contains('rockstar')) inc('rockstar');
      if (dev.contains('cd projekt')) inc('cd_projekt');
      if (dev.contains('konami')) inc('konami');
      if (dev.contains('valve')) inc('valve');
      if (dev.contains('remedy')) inc('remedy');
      if (dev.contains('team ninja') || dev.contains('koei tecmo')) inc('team_ninja');
      if (dev.contains('game freak')) inc('pokemon');

      if (saga.contains('zelda')) inc('zelda');
      if (saga.contains('mario')) inc('mario');
      if (saga.contains('resident evil')) inc('resident_evil');
      if (saga.contains('dark souls') || saga.contains('elden ring')) inc('dark_souls');
      if (saga.contains("assassin's creed")) inc('assassins_creed');
      if (saga.contains('final fantasy')) inc('final_fantasy');
      if (saga.contains('call of duty')) inc('call_of_duty');
      if (saga.contains('elder scrolls')) inc('elder_scrolls');
      if (saga.contains('god of war')) inc('god_of_war');
      if (saga.contains('sonic')) inc('sonic');
      if (saga.contains('tomb raider')) inc('tomb_raider');
      if (saga.contains('monster hunter')) inc('monster_hunter');
      if (saga.contains('kingdom hearts')) inc('kingdom_hearts');
      if (saga.contains('silent hill')) inc('silent_hill');
      if (saga.contains('metroid')) inc('metroid');
      if (saga.contains('kirby')) inc('kirby');
      if (saga.contains('devil may cry')) inc('devil_may_cry');
      if (saga.contains('castlevania')) inc('castlevania');
      if (saga.contains('mass effect')) inc('mass_effect');
      if (saga.contains('doom')) inc('doom');
      if (saga.contains('bioshock')) inc('bioshock');
      if (saga.contains('borderlands')) inc('borderlands');
      if (saga.contains('metro')) inc('metro');
      if (saga.contains('dead space')) inc('dead_space');
      if (saga.contains('yakuza') || saga.contains('like a dragon')) inc('yakuza');
      if (saga.contains('xenoblade')) inc('xenoblade');
      if (saga.contains('persona') || saga.contains('shin megami tensei')) inc('persona');
      if (saga.contains('halo')) inc('halo');

      if (gameModes != null) {
        if (gameModes.any((mode) => mode.toString().toLowerCase().contains('single player'))) {
          inc('lone_wolf');
        }
      }
    }

    return counts;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      case 'menu_book':
        return Icons.menu_book;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'gamepad':
        return Icons.gamepad;
      case 'computer':
        return Icons.computer;
      case 'devices':
        return Icons.devices;
      case 'swords':
        return Icons.colorize;
      case 'category':
        return Icons.category;
      case 'person':
        return Icons.person;
      case 'visibility':
        return Icons.visibility;
      case 'psychology':
        return Icons.psychology;
      case 'fireplace':
        return Icons.fireplace;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'pets':
        return Icons.pets;
      case 'explore':
        return Icons.explore;
      case 'local_police':
        return Icons.local_police;
      case 'science':
        return Icons.science;
      case 'shield':
        return Icons.shield;
      case 'plumbing':
        return Icons.plumbing;
      case 'catching_pokemon':
        return Icons.catching_pokemon;
      case 'biotech':
        return Icons.biotech;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'visibility_off':
        return Icons.visibility_off;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'colorize':
        return Icons.colorize;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Épico':
        return Colors.deepPurpleAccent;
      case 'Difícil':
        return Colors.orange;
      case 'Medio':
        return Colors.blue;
      case 'Fácil':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLevelHeader() {
    final level = LevelCalculator.getLevel(_currentXp);
    final progress = LevelCalculator.getProgressFraction(_currentXp);
    final progressStr = LevelCalculator.getProgressString(_currentXp);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nivel',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                level.toString(),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$_currentXp XP Total',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            progressStr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAchievements = _allAchievements.where((ach) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (ach['name'] as String).toLowerCase();
      final originalName = (ach['original_name'] as String?)?.toLowerCase() ?? '';
      final description = (ach['description'] as String).toLowerCase();
      return name.contains(q) || originalName.contains(q) || description.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progresión y Logros'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildLevelHeader()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar logros...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final achievement = filteredAchievements[index];
                      final isUnlocked = _unlockedAchievements.containsKey(
                        achievement['id'],
                      );
                      final unlockedDate = isUnlocked
                          ? _unlockedAchievements[achievement['id']]
                          : null;
                      
                      final String aId = achievement['id'] as String;
                      String groupId = aId;
                      final matchSuffix = RegExp(r'_(\d+|all)$').firstMatch(aId);
                      if (matchSuffix != null) {
                        groupId = aId.substring(0, aId.length - matchSuffix.group(0)!.length);
                      }

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: isUnlocked ? 2 : 0,
                        color: isUnlocked
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isUnlocked
                                ? _getRarityColor(
                                    achievement['rarity'] as String,
                                  ).withOpacity(0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            int? companyId;
                            int? collectionId;
                            int? franchiseId;
                            int? collectionId2;
                            int? franchiseId2;
                            final String aId = achievement['id'] as String;

                            // Buscar el prefijo del logro en el mapa centralizado de IDs
                            for (final entry in _achievementIgdbIds.entries) {
                              if (aId.startsWith(entry.key)) {
                                companyId = entry.value['companyId'];
                                collectionId = entry.value['collectionId'];
                                franchiseId = entry.value['franchiseId'];
                                collectionId2 = entry.value['collectionId2'];
                                franchiseId2 = entry.value['franchiseId2'];
                                break;
                              }
                            }

                            if (companyId != null || collectionId != null || franchiseId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AchievementGamesScreen(
                                    achievementId: aId,
                                    achievementName:
                                        achievement['name'] as String,
                                    companyId: companyId,
                                    collectionId: collectionId,
                                    franchiseId: franchiseId,
                                    collectionId2: collectionId2,
                                    franchiseId2: franchiseId2,
                                    milestones: _sagaMilestones[groupId] ?? <Map<String, dynamic>>[{'target': 1, 'xp': 10}],
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (!isUnlocked && _sagaProgress.containsKey(groupId))
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Builder(
                                          builder: (context) {
                                            final current = _sagaProgress[groupId]!;
                                            final milestones = _sagaMilestones[groupId] ?? <Map<String, dynamic>>[{'target': 1}];
                                            final maxTarget = milestones.last['target'] as int;
                                            double progress = current / maxTarget;
                                            if (progress > 1.0) progress = 1.0;
                                            
                                            return CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 3,
                                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              color: Theme.of(context).colorScheme.primary,
                                            );
                                          },
                                        ),
                                      ),
                                    CircleAvatar(
                                      backgroundColor: isUnlocked
                                          ? _getRarityColor(
                                              achievement['rarity'] as String,
                                            ).withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                      radius: 28,
                                      child: Icon(
                                        _getIconData(
                                          achievement['icon_name'] as String,
                                        ),
                                        color: isUnlocked
                                            ? _getRarityColor(
                                                achievement['rarity'] as String,
                                              )
                                            : Colors.grey,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  achievement['name'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    color: isUnlocked
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Expanded(
                                  child: Text(
                                    achievement['description'] as String,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isUnlocked
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? _getRarityColor(
                                            achievement['rarity'] as String,
                                          ).withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isUnlocked
                                          ? _getRarityColor(
                                              achievement['rarity'] as String,
                                            )
                                          : Colors.grey,
                                    ),
                                  ),
                                  child: Text(
                                    '+${achievement['xp_reward'] ?? 0} XP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlocked
                                          ? _getRarityColor(
                                              achievement['rarity'] as String,
                                            )
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                if (isUnlocked && unlockedDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${unlockedDate.day.toString().padLeft(2, '0')}/${unlockedDate.month.toString().padLeft(2, '0')}/${unlockedDate.year}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: filteredAchievements.length),
                  ),
                ),
              ],
            ),
    );
  }
}

