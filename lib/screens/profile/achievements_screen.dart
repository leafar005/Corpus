import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/level_calculator.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';

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

  static const Map<String, Map<String, int?>> _achievementIgdbIds = {
    'kojima': {'companyId': 170},
    'fromsoftware': {'companyId': 1012},
    'nintendo': {'companyId': 70},
    'capcom': {'companyId': 37},
    'naughty_dog': {'companyId': 401},
    'rockstar': {'companyId': 29},
    'cd_projekt': {'companyId': 908},
    'valve': {'companyId': 56},
    'square_enix': {'companyId': 26},
    'bethesda': {'companyId': 16565},
    'konami': {'companyId': 129},
    'remedy': {'companyId': 305},
    'team_ninja': {'companyId': 769},
    'pokemon': {'companyId': 1617},
    'zelda': {'collectionId': 106},
    'mario': {'collectionId': 240},
    'halo': {'franchiseId': 137},
    'sonic': {'collectionId': 2156},
    'persona': {'franchiseId': 552, 'franchiseId2': 538},
    'dark_souls': {'collectionId': 543, 'franchiseId': 1124},
    'assassins_creed': {'franchiseId': 571},
    'yakuza': {'franchiseId': 1467},
    'resident_evil': {'franchiseId': 29},
    'final_fantasy': {'franchiseId': 4},
    'call_of_duty': {'franchiseId': 726},
    'elder_scrolls': {'franchiseId': 456},
    'god_of_war': {'franchiseId': 2098},
    'tomb_raider': {'franchiseId': 279},
    'monster_hunter': {'franchiseId': 824},
    'kingdom_hearts': {'franchiseId': 720},
    'silent_hill': {'franchiseId': 554},
    'metroid': {'franchiseId': 756},
    'kirby': {'franchiseId': 789},
    'devil_may_cry': {'franchiseId': 834},
    'castlevania': {'franchiseId': 895},
    'mass_effect': {'franchiseId': 1048},
    'doom': {'franchiseId': 798},
    'bioshock': {'collectionId': 1},
    'borderlands': {'franchiseId': 808},
    'metro': {'franchiseId': 1344},
    'dead_space': {'franchiseId': 1386},
    'xenoblade': {'franchiseId': 4564},
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
      final userResp = await Supabase.instance.client
          .from('users')
          .select('xp')
          .eq('id', widget.userId)
          .maybeSingle();
      if (userResp != null && userResp['xp'] != null) {
        _currentXp = userResp['xp'] as int;
      }

      final achievementsResp = await Supabase.instance.client
          .from('achievements')
          .select()
          .order('xp_reward', ascending: true);

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

      final reviewsResp = await Supabase.instance.client
          .from('reviews')
          .select('*, games(*)')
          .eq('user_id', widget.userId);

      final userGamesResp = await Supabase.instance.client
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', widget.userId);

      final Map<int, dynamic> uniqueBeatenGames = {};
      for (var item in [...reviewsResp, ...userGamesResp]) {
        final st = item['status'];
        if (st != 'beaten' && st != 'completed') continue;
        final game = item['games'];
        if (game == null) continue;
        final int? gameId = game['igdb_id'] as int?;
        if (gameId != null) {
          uniqueBeatenGames[gameId] = item;
        }
      }
      final List<dynamic> combinedBeatenList = uniqueBeatenGames.values
          .toList();
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
          if (aId.startsWith('fromsoftware') || aId.startsWith('zelda')) {
            target = 7;
          } else if (aId.startsWith('mario')) {
            target = 15;
          } else if (aId.startsWith('dark_souls')) {
            target = 3;
          }
        }
        if (!grouped.containsKey(groupId)) {
          grouped[groupId] = Map<String, dynamic>.from(ach);
          grouped[groupId]!['name'] = baseName;
          grouped[groupId]!['original_name'] = name;
          sagaMilestones[groupId] = [
            {
              'target': target,
              'xp': ach['xp_reward'],
              'description': ach['description'],
            },
          ];
        } else {
          sagaMilestones[groupId]!.add({
            'target': target,
            'xp': ach['xp_reward'],
            'description': ach['description'],
          });
          int currentXp = grouped[groupId]!['xp_reward'] as int;
          int newXp = ach['xp_reward'] as int;
          if (newXp > currentXp) {
            grouped[groupId]!['id'] = aId;
            grouped[groupId]!['name'] = baseName;
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
      final Map<String, int> sagaProgress = _calculateSagaProgress(
        combinedBeatenList,
        grouped.values.toList(),
      );
      final List<Map<String, dynamic>> sortedAchievements = grouped.values
          .toList();
      sortedAchievements.sort((a, b) {
        String getGroupId(String id) {
          final matchSuffix = RegExp(r'_(\d+|all)$').firstMatch(id);
          return matchSuffix != null
              ? id.substring(0, id.length - matchSuffix.group(0)!.length)
              : id;
        }

        final String groupIdA = getGroupId(a['id'] as String);
        final String groupIdB = getGroupId(b['id'] as String);

        final int progA = sagaProgress[groupIdA] ?? 0;
        final int progB = sagaProgress[groupIdB] ?? 0;

        final List<Map<String, dynamic>> milestonesA =
            sagaMilestones[groupIdA] ??
            <Map<String, dynamic>>[
              {'target': 1},
            ];
        final List<Map<String, dynamic>> milestonesB =
            sagaMilestones[groupIdB] ??
            <Map<String, dynamic>>[
              {'target': 1},
            ];

        final int maxTargetA = milestonesA.last['target'] as int;
        final int maxTargetB = milestonesB.last['target'] as int;

        final bool isUnlockedA =
            unlockedMap.containsKey(a['id']) ||
            unlockedMap.keys.any(
              (k) => k == groupIdA || k.startsWith('${groupIdA}_'),
            ) ||
            progA >= maxTargetA;
        final bool isUnlockedB =
            unlockedMap.containsKey(b['id']) ||
            unlockedMap.keys.any(
              (k) => k == groupIdB || k.startsWith('${groupIdB}_'),
            ) ||
            progB >= maxTargetB;

        int getCategory(int prog, int maxTarget, bool isUnlocked) {
          // 1: Logros completados al 100% (oro, o logro de 1 hito conseguido) -> DEBAJO
          if (prog >= maxTarget || (isUnlocked && maxTarget <= 1)) {
            return 1;
          }
          // 0: Logros en un punto medio (en progreso: 0 < prog < maxTarget) -> PRIMERO
          if (prog > 0) {
            return 0;
          }
          // 2: Logros sin comenzar (0 progreso) -> AL FINAL
          return 2;
        }

        final int catA = getCategory(progA, maxTargetA, isUnlockedA);
        final int catB = getCategory(progB, maxTargetB, isUnlockedB);

        if (catA != catB) {
          return catA.compareTo(catB);
        }

        // Dentro de la misma categoría, ordenar de mayor a menor XP
        final int xpA = (a['xp_reward'] as num?)?.toInt() ?? 0;
        final int xpB = (b['xp_reward'] as num?)?.toInt() ?? 0;
        if (xpA != xpB) {
          return xpB.compareTo(xpA);
        }

        // Si empatan en XP, ordenar alfabéticamente
        final String nameA = (a['name'] ?? '').toString();
        final String nameB = (b['name'] ?? '').toString();
        return nameA.compareTo(nameB);
      });
      if (mounted) {
        setState(() {
          _allAchievements = sortedAchievements;
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

  Map<String, int> _calculateSagaProgress(
    List<dynamic> data,
    List<Map<String, dynamic>> achievementsList,
  ) {
    Map<String, int> counts = {};
    for (var item in data) {
      final st = item['status']?.toString().toLowerCase().trim();
      if (st != 'beaten' && st != 'completed' && st != 'terminado') continue;
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
          title.contains('cross tag');
      if (dev.contains('kojima') ||
          saga.contains('metal gear') ||
          saga.contains('zone of the enders') ||
          saga.contains('boktai') ||
          title.contains('metal gear') ||
          title.contains('death stranding') ||
          title.contains('snatcher') ||
          title.contains('policenauts') ||
          title.contains('zone of the enders') ||
          title.contains('boktai')) {
        inc('kojima');
      }
      if (dev.contains('fromsoftware') ||
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
          saga.contains('sekiro')) {
        inc('fromsoftware');
      }
      if (dev.contains('nintendo') ||
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
          title.contains('xenoblade')) {
        inc('nintendo');
      }
      if (dev.contains('capcom') ||
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
                  title.contains('darkstalkers')))) {
        inc('capcom');
      }
      if (dev.contains('naughty dog') ||
          saga.contains('uncharted') ||
          saga.contains('the last of us') ||
          saga.contains('jak and daxter') ||
          saga.contains('crash bandicoot')) {
        inc('naughty_dog');
      }
      if (dev.contains('rockstar') ||
          saga.contains('grand theft auto') ||
          saga.contains('red dead') ||
          saga.contains('max payne') ||
          saga.contains('bully') ||
          saga.contains('l.a. noire')) {
        inc('rockstar');
      }
      if (dev.contains('cd projekt') ||
          saga.contains('witcher') ||
          saga.contains('cyberpunk')) {
        inc('cd_projekt');
      }
      if (dev.contains('valve') ||
          dev.contains('crowbar collective') ||
          title.contains('black mesa') ||
          saga.contains('half-life') ||
          saga.contains('portal') ||
          saga.contains('left 4 dead') ||
          saga.contains('counter-strike') ||
          saga.contains('team fortress')) {
        inc('valve');
      }
      if (dev.contains('remedy') ||
          saga.contains('alan wake') ||
          saga.contains('control') ||
          saga.contains('max payne')) {
        inc('remedy');
      }
      if (dev.contains('team ninja') ||
          dev.contains('koei tecmo') ||
          saga.contains('ninja gaiden') ||
          saga.contains('nioh') ||
          saga.contains('dead or alive')) {
        inc('team_ninja');
      }
      if (dev.contains('square enix') ||
          dev.contains('squaresoft') ||
          dev.contains('enix') ||
          saga.contains('final fantasy') ||
          saga.contains('kingdom hearts')) {
        inc('square_enix');
      }
      if (dev.contains('bethesda') ||
          dev.contains('zenimax') ||
          dev.contains('arkane') ||
          dev.contains('id software') ||
          dev.contains('machinegames') ||
          saga.contains('elder scrolls') ||
          saga.contains('fallout') ||
          saga.contains('doom')) {
        inc('bethesda');
      }
      if (dev.contains('konami') ||
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
          title.contains('zone of the enders')) {
        inc('konami');
      }
      if (dev.contains('game freak') ||
          (!isCrossover && saga.contains('pokemon'))) {
        inc('pokemon');
      }
      if (!isCrossover) {
        if (saga.contains('zelda') || title.contains('zelda')) {
          inc('zelda');
        }
        if (saga.contains('mario') || title.contains('super mario')) {
          inc('mario');
        }
        if (saga.contains('resident evil') || title.contains('resident evil')) {
          inc('resident_evil');
        }
        if (saga.contains('dark souls') || title.contains('dark souls')) {
          inc('dark_souls');
        }
        if (saga.contains("assassin's creed") ||
            title.contains("assassin's creed")) {
          inc('assassins_creed');
        }
        if (saga.contains('final fantasy') || title.contains('final fantasy')) {
          inc('final_fantasy');
        }
        if (saga.contains('call of duty') || title.contains('call of duty')) {
          inc('call_of_duty');
        }
        if (saga.contains('elder scrolls') || title.contains('elder scrolls')) {
          inc('elder_scrolls');
        }
        if (saga.contains('god of war') || title.contains('god of war')) {
          inc('god_of_war');
        }
        if (saga.contains('sonic') || title.contains('sonic')) {
          inc('sonic');
        }
        if (saga.contains('tomb raider') || title.contains('tomb raider')) {
          inc('tomb_raider');
        }
        if (saga.contains('monster hunter') ||
            title.contains('monster hunter')) {
          inc('monster_hunter');
        }
        if (saga.contains('kingdom hearts') ||
            title.contains('kingdom hearts')) {
          inc('kingdom_hearts');
        }
        if (saga.contains('silent hill') || title.contains('silent hill')) {
          inc('silent_hill');
        }
        if (saga.contains('metroid') || title.contains('metroid')) {
          inc('metroid');
        }
        if (saga.contains('kirby') || title.contains('kirby')) {
          inc('kirby');
        }
        if (saga.contains('devil may cry') || title.contains('devil may cry')) {
          inc('devil_may_cry');
        }
        if (saga.contains('castlevania') || title.contains('castlevania')) {
          inc('castlevania');
        }
        if (saga.contains('mass effect') || title.contains('mass effect')) {
          inc('mass_effect');
        }
        if (saga.contains('doom') || title.contains('doom')) {
          inc('doom');
        }
        if (saga.contains('bioshock') || title.contains('bioshock')) {
          inc('bioshock');
        }
        if (saga.contains('borderlands') || title.contains('borderlands')) {
          inc('borderlands');
        }
        if ((saga.contains('metro') ||
                title.contains('metro 2033') ||
                title.contains('metro: last light') ||
                title.contains('metro exodus')) &&
            !saga.contains('metroid') &&
            !title.contains('metroid')) {
          inc('metro');
        }
        if (saga.contains('dead space') || title.contains('dead space')) {
          inc('dead_space');
        }
        if (saga.contains('yakuza') ||
            saga.contains('like a dragon') ||
            title.contains('yakuza') ||
            title.contains('like a dragon')) {
          inc('yakuza');
        }
        if (saga.contains('xenoblade') || title.contains('xenoblade')) {
          inc('xenoblade');
        }
        if (saga.contains('persona') ||
            saga.contains('shin megami tensei') ||
            title.contains('persona') ||
            title.contains('shin megami tensei')) {
          inc('persona');
        }
        if (saga.contains('halo') || title.contains('halo')) {
          inc('halo');
        }
      }
      if (gameModes != null) {
        if (gameModes.any(
          (mode) => mode.toString().toLowerCase().contains('single player'),
        )) {
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
    switch (rarity.trim().toLowerCase()) {
      case 'legendario':
        return Colors.cyanAccent;
      case 'épico':
      case 'epico':
        return Colors.deepPurpleAccent;
      case 'difícil':
      case 'dificil':
        return Colors.orange;
      case 'medio':
        return Colors.blue;
      case 'fácil':
      case 'facil':
      case 'común':
      case 'comun':
      case 'raro':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getNextMilestoneDescription(
    String groupId,
    int currentProgress,
    String fallback,
  ) {
    final milestonesData = _sagaMilestones[groupId];
    if (milestonesData == null || milestonesData.isEmpty) return fallback;
    for (final m in milestonesData) {
      final target = m['target'] as int;
      if (currentProgress < target) {
        return (m['description'] as String?) ?? fallback;
      }
    }
    return (milestonesData.last['description'] as String?) ?? fallback;
  }

  int _getNextMilestoneXp(String groupId, int currentProgress, int fallback) {
    final milestonesData = _sagaMilestones[groupId];
    if (milestonesData == null || milestonesData.isEmpty) return fallback;
    for (final m in milestonesData) {
      final target = m['target'] as int;
      if (currentProgress < target) {
        return (m['xp'] as int?) ?? fallback;
      }
    }
    return (milestonesData.last['xp'] as int?) ?? fallback;
  }

  Map<String, dynamic> _getAchievementBadgeStyle(
    Map<String, dynamic> achievement,
    int currentProgress,
    List<int> milestones,
    bool isUnlocked,
  ) {
    final int totalStages = milestones.length;
    if (totalStages <= 1) {
      final Color color = _getRarityColor(achievement['rarity'] as String);
      return {
        'type': 'gem',
        'label': achievement['rarity'] as String,
        'color': isUnlocked ? color : Colors.grey,
        'borderColor': isUnlocked
            ? color.withValues(alpha: 0.5)
            : Colors.transparent,
        'bgColor': isUnlocked
            ? color.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        'icon': _getIconData(achievement['icon_name'] as String),
      };
    }
    int currentStageIndex = 0;
    for (int i = 0; i < totalStages; i++) {
      if (currentProgress >= milestones[i]) {
        currentStageIndex = i + 1;
      }
    }
    if (totalStages == 2 && currentStageIndex == 2) {
      currentStageIndex = 3;
    }
    Color color;
    String label;
    if (currentStageIndex >= 3) {
      label = 'Maestro (Oro)';
      color = const Color(0xFFFFD700);
    } else if (currentStageIndex == 2) {
      label = 'Fanático (Plata)';
      color = const Color(0xFFC0C0C0);
    } else if (currentStageIndex == 1) {
      label = 'Novato (Bronce)';
      color = const Color(0xFFCD7F32);
    } else {
      label = 'Bloqueado';
      color = Colors.grey;
    }
    return {
      'type': 'medal',
      'label': label,
      'color': color,
      'borderColor': isUnlocked
          ? color.withValues(alpha: 0.5)
          : Colors.transparent,
      'bgColor': isUnlocked
          ? color.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.2),
      'icon': _getIconData(achievement['icon_name'] as String),
    };
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
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusSmall,
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

  void _showXpInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.stars, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('¿Cómo ganar XP?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Puedes ganar Experiencia (XP) realizando diferentes acciones en Corpus:',
              ),
              const SizedBox(height: 16),
              _buildXpRow(
                context,
                Icons.person_add,
                'Crear tu cuenta',
                '50 XP',
              ),
              _buildXpRow(
                context,
                Icons.add_circle_outline,
                'Añadir un juego a tu biblioteca',
                '5 XP',
              ),
              _buildXpRow(
                context,
                Icons.emoji_events,
                'Completar (Terminar) un juego',
                '20 XP',
              ),
              _buildXpRow(
                context,
                Icons.rate_review,
                'Escribir una reseña',
                '10 XP',
              ),
              _buildXpRow(
                context,
                Icons.workspace_premium,
                'Desbloquear logros',
                'Variable',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildXpRow(
    BuildContext context,
    IconData icon,
    String action,
    String xp,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(action, style: const TextStyle(fontSize: 14))),
          Text(
            xp,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
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
      final originalName =
          (ach['original_name'] as String?)?.toLowerCase() ?? '';
      final description = (ach['description'] as String).toLowerCase();
      return name.contains(q) ||
          originalName.contains(q) ||
          description.contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const CorpusScreenTitle('Progresión y Logros'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '¿Cómo ganar XP?',
            onPressed: _showXpInfoDialog,
          ),
        ],
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
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusMedium,
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
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
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width < 600
                          ? 0.65
                          : 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final achievement = filteredAchievements[index];
                      final String aId = achievement['id'] as String;
                      String groupId = aId;
                      final matchSuffix = RegExp(
                        r'_(\d+|all)$',
                      ).firstMatch(aId);
                      if (matchSuffix != null) {
                        groupId = aId.substring(
                          0,
                          aId.length - matchSuffix.group(0)!.length,
                        );
                      }
                      final milestonesData =
                          _sagaMilestones[groupId] ??
                          <Map<String, dynamic>>[
                            {'target': 1},
                          ];
                      final milestones = milestonesData
                          .map((e) => e['target'] as int)
                          .toList();
                      final currentProgress = _sagaProgress[groupId] ?? 0;
                      final isUnlocked =
                          _unlockedAchievements.containsKey(
                            achievement['id'],
                          ) ||
                          _unlockedAchievements.keys.any(
                            (key) =>
                                key == groupId || key.startsWith('${groupId}_'),
                          ) ||
                          (currentProgress >= milestones.first);
                      final displayDescription = _getNextMilestoneDescription(
                        groupId,
                        currentProgress,
                        achievement['description'] as String,
                      );
                      final int displayXp = _getNextMilestoneXp(
                        groupId,
                        currentProgress,
                        (achievement['xp_reward'] as int?) ?? 0,
                      );
                      DateTime? unlockedDate =
                          _unlockedAchievements[achievement['id']];
                      for (final entry in _unlockedAchievements.entries) {
                        if (entry.key == groupId ||
                            entry.key.startsWith('${groupId}_') ||
                            entry.key == achievement['id']) {
                          if (unlockedDate == null ||
                              entry.value.isAfter(unlockedDate)) {
                            unlockedDate = entry.value;
                          }
                        }
                      }

                      final badgeStyle = _getAchievementBadgeStyle(
                        achievement,
                        currentProgress,
                        milestones,
                        isUnlocked,
                      );
                      final Color badgeColor = badgeStyle['color'] as Color;
                      final Color borderColor =
                          badgeStyle['borderColor'] as Color;
                      final Color bgColor = badgeStyle['bgColor'] as Color;
                      final IconData badgeIcon = badgeStyle['icon'] as IconData;
                      final bool isMedal = badgeStyle['type'] == 'medal';
                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: isUnlocked ? 4 : 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusLarge,
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusLarge,
                          onTap: () {
                            int? companyId;
                            int? collectionId;
                            int? franchiseId;
                            int? collectionId2;
                            int? franchiseId2;
                            final String aId = achievement['id'] as String;
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
                            if (companyId != null ||
                                collectionId != null ||
                                franchiseId != null) {
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
                                    milestones:
                                        _sagaMilestones[groupId] ??
                                        <Map<String, dynamic>>[
                                          {'target': 1, 'xp': 10},
                                        ],
                                    achievementIcon: badgeIcon,
                                    achievementColor: badgeColor,
                                  ),
                                ),
                              ).then((_) {
                                _fetchAchievementsData();
                              });
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
                                    Builder(
                                      builder: (context) {
                                        final milestones =
                                            _sagaMilestones[groupId] ??
                                            <Map<String, dynamic>>[
                                              {'target': 1},
                                            ];
                                        final maxTarget =
                                            milestones.last['target'] as int;
                                        final current =
                                            _sagaProgress[groupId] ?? 0;
                                        final showCircle =
                                            current > 0 && current < maxTarget;
                                        if (!showCircle) {
                                          return const SizedBox(
                                            width: 56,
                                            height: 56,
                                          );
                                        }
                                        double progress = current / maxTarget;
                                        return SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: CircularProgressIndicator(
                                            value: progress,
                                            strokeWidth: 3,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            color: badgeColor,
                                          ),
                                        );
                                      },
                                    ),
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        shape: BoxShape.circle,
                                        border: isMedal
                                            ? Border.all(
                                                color: badgeColor.withValues(
                                                  alpha: 0.3,
                                                ),
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: Icon(
                                        badgeIcon,
                                        color: badgeColor,
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
                                              .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    displayDescription,
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
                                                .withValues(alpha: 0.5),
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
                                    color: bgColor,
                                    borderRadius: Theme.of(context)
                                        .extension<CorpusThemeExtension>()!
                                        .radiusSmall,
                                    border: Border.all(color: badgeColor),
                                  ),
                                  child: Text(
                                    '+$displayXp XP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                if (isUnlocked && unlockedDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${unlockedDate.day.toString().padLeft(2, '0')}/${unlockedDate.month.toString().padLeft(2, '0')}/${unlockedDate.year}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: badgeColor,
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
