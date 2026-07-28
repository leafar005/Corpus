import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';

class ProfileAchievementsTab extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const ProfileAchievementsTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  State<ProfileAchievementsTab> createState() => _ProfileAchievementsTabState();
}

class _ProfileAchievementsTabState extends State<ProfileAchievementsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _achievedList = [];
  Map<String, List<Map<String, dynamic>>> _sagaMilestones = {};

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
    _fetchAchievements();
  }

  @override
  void didUpdateWidget(covariant ProfileAchievementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isOwnProfile != widget.isOwnProfile) {
      _fetchAchievements();
    }
  }

  Future<void> _fetchAchievements() async {
    try {
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

      // Consultar tanto reviews como user_games para capturar todos los juegos completados
      final reviewsResp = await Supabase.instance.client
          .from('reviews')
          .select('*, games(*)')
          .eq('user_id', widget.userId);

      final userGamesResp = await Supabase.instance.client
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', widget.userId);

      // Deduplicar juegos completados por su id de juego
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

      final Map<String, Map<String, dynamic>> grouped = {};
      final Map<String, List<Map<String, dynamic>>> sagaMilestones = {};

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

      // Filtrar y clasificar por hito / rareza conseguida
      final List<Map<String, dynamic>> candidateList = grouped.values.toList();
      final List<Map<String, dynamic>> filteredAchieved = [];

      for (var ach in candidateList) {
        final String aId = ach['id'] as String;
        String groupId = aId;
        final matchSuffix = RegExp(r'_(\d+|all)$').firstMatch(aId);
        if (matchSuffix != null) {
          groupId = aId.substring(0, aId.length - matchSuffix.group(0)!.length);
        }
        final milestonesData =
            sagaMilestones[groupId] ??
            <Map<String, dynamic>>[
              {'target': 1},
            ];
        final milestones = milestonesData
            .map((e) => e['target'] as int)
            .toList();
        final currentProgress = sagaProgress[groupId] ?? 0;

        final isUnlocked =
            unlockedMap.containsKey(aId) ||
            unlockedMap.keys.any(
              (key) => key == groupId || key.startsWith('${groupId}_'),
            ) ||
            (currentProgress >= milestones.first);

        final sortRank = _getAchievementSortRank(
          currentProgress,
          milestones,
          isUnlocked,
        );
        if (sortRank > 0) {
          ach['_sortRank'] = sortRank;
          ach['_groupId'] = groupId;
          ach['_currentProgress'] = currentProgress;
          ach['_milestones'] = milestones;
          ach['_isUnlocked'] = isUnlocked;
          DateTime? unlockedDate = unlockedMap[aId];
          for (final entry in unlockedMap.entries) {
            if (entry.key == groupId ||
                entry.key.startsWith('${groupId}_') ||
                entry.key == aId) {
              if (unlockedDate == null || entry.value.isAfter(unlockedDate)) {
                unlockedDate = entry.value;
              }
            }
          }
          ach['_unlockedDate'] = unlockedDate;
          ach['_displayDescription'] = _getNextMilestoneDescription(
            groupId,
            currentProgress,
            ach['description'] as String,
            sagaMilestones,
          );
          ach['xp_reward'] = _getAchievedMilestoneXp(
            groupId,
            currentProgress,
            (ach['xp_reward'] as int?) ?? 0,
            sagaMilestones,
          );
          filteredAchieved.add(ach);
        }
      }

      // Ordenar de más a menos experiencia conseguida en el logro (XP) -> Nombre
      filteredAchieved.sort((a, b) {
        final int xpA = (a['xp_reward'] as int?) ?? 0;
        final int xpB = (b['xp_reward'] as int?) ?? 0;
        if (xpA != xpB) {
          return xpB.compareTo(xpA);
        }
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (mounted) {
        setState(() {
          _achievedList = filteredAchieved;
          _sagaMilestones = sagaMilestones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileAchievementsTab] Error fetching achievements: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Rango de ordenación de hitos (4=Oro, 3=Un solo hito, 2=Plata, 1=Bronce, 0=Ninguno)
  int _getAchievementSortRank(
    int currentProgress,
    List<int> milestones,
    bool isUnlocked,
  ) {
    final int totalStages = milestones.length;
    if (totalStages <= 1) {
      return isUnlocked ? 3 : 0;
    }
    int stageIdx = 0;
    for (int i = 0; i < totalStages; i++) {
      if (currentProgress >= milestones[i]) {
        stageIdx = i + 1;
      }
    }
    if (totalStages == 2 && stageIdx == 2) {
      stageIdx = 3; // Mapear hito 2 de 2 a Oro
    }
    if (stageIdx >= 3) return 4; // Oro (3 o más hitos alcanzados)
    if (stageIdx == 2) return 2; // Plata
    if (stageIdx == 1) return 1; // Bronce
    return 0; // Bloqueado (0 hitos alcanzados)
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
      if (dev.contains('square enix') ||
          dev.contains('square-enix') ||
          dev.contains('squaresoft') ||
          dev.contains('enix') ||
          dev.contains('tri-ace') ||
          dev.contains('tokyo rpg factory') ||
          dev.contains('luminous productions') ||
          (!isCrossover &&
              (saga.contains('final fantasy') ||
                  saga.contains('dragon quest') ||
                  saga.contains('kingdom hearts') ||
                  saga.contains('tomb raider') ||
                  saga.contains('nier') ||
                  saga.contains('chrono') ||
                  saga.contains('mana') ||
                  saga.contains('star ocean') ||
                  saga.contains('valkyrie profile') ||
                  saga.contains('parasite eve') ||
                  title.contains('final fantasy') ||
                  title.contains('dragon quest') ||
                  title.contains('kingdom hearts') ||
                  title.contains('tomb raider') ||
                  title.contains('nier') ||
                  title.contains('chrono') ||
                  title.contains('mana') ||
                  title.contains('star ocean') ||
                  title.contains('valkyrie profile') ||
                  title.contains('parasite eve')))) {
        inc('square_enix');
      }
      if (dev.contains('ubisoft') ||
          saga.contains('assassin') ||
          saga.contains('far cry') ||
          saga.contains('prince of persia') ||
          saga.contains('rayman') ||
          saga.contains('tom clancy') ||
          saga.contains('splinter cell') ||
          saga.contains('watch dogs') ||
          title.contains('assassin') ||
          title.contains('far cry') ||
          title.contains('prince of persia') ||
          title.contains('rayman') ||
          title.contains('tom clancy') ||
          title.contains('splinter cell') ||
          title.contains('watch dogs')) {
        inc('ubisoft');
      }
      if (dev.contains('electronic arts') ||
          dev.contains('ea ') ||
          dev.contains('bioware') ||
          dev.contains('dice') ||
          dev.contains('maxis') ||
          dev.contains('criterion') ||
          dev.contains('respawn') ||
          saga.contains('need for speed') ||
          saga.contains('battlefield') ||
          saga.contains('mass effect') ||
          saga.contains('dragon age') ||
          saga.contains('dead space') ||
          saga.contains('the sims') ||
          saga.contains('fifa') ||
          saga.contains('madden') ||
          title.contains('need for speed') ||
          title.contains('battlefield') ||
          title.contains('mass effect') ||
          title.contains('dragon age') ||
          title.contains('dead space') ||
          title.contains('the sims') ||
          title.contains('fifa') ||
          title.contains('madden')) {
        inc('ea');
      }
      if (dev.contains('sony') ||
          dev.contains('naughty dog') ||
          dev.contains('insomniac') ||
          dev.contains('santa monica') ||
          dev.contains('guerrilla') ||
          dev.contains('sucker punch') ||
          dev.contains('polyphony') ||
          dev.contains('japan studio') ||
          dev.contains('bend studio') ||
          saga.contains('god of war') ||
          saga.contains('uncharted') ||
          saga.contains('last of us') ||
          saga.contains('spider-man') ||
          saga.contains('horizon zero') ||
          saga.contains('ratchet') ||
          saga.contains('gran turismo') ||
          saga.contains('bloodborne') ||
          saga.contains('shadow of the colossus') ||
          title.contains('god of war') ||
          title.contains('uncharted') ||
          title.contains('last of us') ||
          title.contains('spider-man') ||
          title.contains('horizon zero') ||
          title.contains('ratchet') ||
          title.contains('gran turismo') ||
          title.contains('bloodborne') ||
          title.contains('shadow of the colossus')) {
        inc('sony');
      }
      if (dev.contains('atlus') ||
          (!isCrossover &&
              (saga.contains('persona') ||
                  saga.contains('shin megami tensei') ||
                  saga.contains('catherine') ||
                  saga.contains('etrian odyssey') ||
                  title.contains('persona') ||
                  title.contains('shin megami tensei') ||
                  title.contains('catherine') ||
                  title.contains('etrian odyssey')))) {
        inc('atlus');
      }
      if (dev.contains('konami') ||
          dev.contains('kojima productions') ||
          (!isCrossover &&
              (saga.contains('metal gear') ||
                  saga.contains('silent hill') ||
                  saga.contains('castlevania') ||
                  saga.contains('contra') ||
                  saga.contains('suikoden') ||
                  saga.contains('zone of the enders') ||
                  saga.contains('bomberman') ||
                  title.contains('metal gear') ||
                  title.contains('silent hill') ||
                  title.contains('castlevania') ||
                  title.contains('contra') ||
                  title.contains('suikoden') ||
                  title.contains('zone of the enders') ||
                  title.contains('bomberman')))) {
        inc('konami');
      }
      if (dev.contains('sega') ||
          dev.contains('ryu ga gotoku') ||
          dev.contains('sonic team') ||
          dev.contains('atlus') ||
          (!isCrossover &&
              (saga.contains('sonic') ||
                  saga.contains('yakuza') ||
                  saga.contains('like a dragon') ||
                  saga.contains('persona') ||
                  saga.contains('shenmue') ||
                  saga.contains('phantasy star') ||
                  saga.contains('virtua fighter') ||
                  saga.contains('streets of rage') ||
                  title.contains('sonic') ||
                  title.contains('yakuza') ||
                  title.contains('like a dragon') ||
                  title.contains('persona') ||
                  title.contains('shenmue') ||
                  title.contains('phantasy star') ||
                  title.contains('virtua fighter') ||
                  title.contains('streets of rage')))) {
        inc('sega');
      }
      if (dev.contains('valve') ||
          saga.contains('half-life') ||
          saga.contains('portal') ||
          saga.contains('left 4 dead') ||
          saga.contains('team fortress') ||
          saga.contains('counter-strike') ||
          title.contains('half-life') ||
          title.contains('portal') ||
          title.contains('left 4 dead') ||
          title.contains('team fortress') ||
          title.contains('counter-strike')) {
        inc('valve');
      }
      if (dev.contains('rockstar') ||
          saga.contains('grand theft auto') ||
          saga.contains('gta') ||
          saga.contains('red dead') ||
          saga.contains('max payne') ||
          saga.contains('bully') ||
          title.contains('grand theft auto') ||
          title.contains('gta') ||
          title.contains('red dead') ||
          title.contains('max payne') ||
          title.contains('bully')) {
        inc('rockstar');
      }
      if (dev.contains('bethesda') ||
          dev.contains('id software') ||
          dev.contains('arkane') ||
          dev.contains('machinegames') ||
          dev.contains('zenimax') ||
          dev.contains('tango gameworks') ||
          saga.contains('elder scrolls') ||
          saga.contains('fallout') ||
          saga.contains('doom') ||
          saga.contains('wolfenstein') ||
          saga.contains('dishonored') ||
          saga.contains('prey') ||
          saga.contains('evil within') ||
          title.contains('elder scrolls') ||
          title.contains('fallout') ||
          title.contains('doom') ||
          title.contains('wolfenstein') ||
          title.contains('dishonored') ||
          title.contains('prey') ||
          title.contains('evil within')) {
        inc('bethesda');
      }

      if (saga.isNotEmpty || title.isNotEmpty) {
        if (saga.contains('mario') || title.contains('mario')) {
          inc('mario');
        }
        if (saga.contains('zelda') || title.contains('zelda')) {
          inc('zelda');
        }
        if (saga.contains('pokemon') ||
            saga.contains('pokémon') ||
            title.contains('pokemon') ||
            title.contains('pokémon')) {
          inc('pokemon');
        }
        if (saga.contains('grand theft auto') ||
            saga.contains('gta') ||
            title.contains('grand theft auto') ||
            title.contains('gta')) {
          inc('gta');
        }
        if (saga.contains('final fantasy') || title.contains('final fantasy')) {
          inc('final_fantasy');
        }
        if (saga.contains('assassin') || title.contains('assassin')) {
          inc('assassins_creed');
        }
        if (saga.contains('resident evil') || title.contains('resident evil')) {
          inc('resident_evil');
        }
        if (saga.contains('silent hill') || title.contains('silent hill')) {
          inc('silent_hill');
        }
        if (saga.contains('metal gear') || title.contains('metal gear')) {
          inc('metal_gear');
        }
        if (saga.contains('castlevania') || title.contains('castlevania')) {
          inc('castlevania');
        }
        if (saga.contains('metroid') || title.contains('metroid')) {
          inc('metroid');
        }
        if (saga.contains('kirby') || title.contains('kirby')) {
          inc('kirby');
        }
        if (saga.contains('god of war') || title.contains('god of war')) {
          inc('god_of_war');
        }
        if (saga.contains('halo') || title.contains('halo')) {
          inc('halo');
        }
        if (saga.contains('fallout') || title.contains('fallout')) {
          inc('fallout');
        }
        if (saga.contains('elder scrolls') || title.contains('elder scrolls')) {
          inc('elder_scrolls');
        }
        if (saga.contains('witcher') || title.contains('witcher')) {
          inc('witcher');
        }
        if (saga.contains('mass effect') || title.contains('mass effect')) {
          inc('mass_effect');
        }
        if (saga.contains('bioshock') || title.contains('bioshock')) {
          inc('bioshock');
        }
        if (saga.contains('tomb raider') || title.contains('tomb raider')) {
          inc('tomb_raider');
        }
        if (saga.contains('street fighter') ||
            title.contains('street fighter')) {
          inc('street_fighter');
        }
        if (saga.contains('mortal kombat') || title.contains('mortal kombat')) {
          inc('mortal_kombat');
        }
        if (saga.contains('tekken') || title.contains('tekken')) {
          inc('tekken');
        }
        if (saga.contains('persona') || title.contains('persona')) {
          inc('persona');
        }
        if (saga.contains('yakuza') ||
            saga.contains('like a dragon') ||
            title.contains('yakuza') ||
            title.contains('like a dragon')) {
          inc('yakuza');
        }
        if (saga.contains('monster hunter') ||
            title.contains('monster hunter')) {
          inc('monster_hunter');
        }
        if (saga.contains('devil may cry') || title.contains('devil may cry')) {
          inc('devil_may_cry');
        }
        if (saga.contains('borderlands') || title.contains('borderlands')) {
          inc('borderlands');
        }
        if (saga.contains('far cry') || title.contains('far cry')) {
          inc('far_cry');
        }
        if (saga.contains('need for speed') ||
            title.contains('need for speed')) {
          inc('need_for_speed');
        }
        if (saga.contains('sonic') || title.contains('sonic')) {
          inc('sonic');
        }
        if (saga.contains('crash bandicoot') ||
            title.contains('crash bandicoot')) {
          inc('crash_bandicoot');
        }
        if (saga.contains('spyro') || title.contains('spyro')) {
          inc('spyro');
        }
        if (saga.contains('ratchet') || title.contains('ratchet')) {
          inc('ratchet');
        }
        if (saga.contains('uncharted') || title.contains('uncharted')) {
          inc('uncharted');
        }
        if (saga.contains('kingdom hearts') ||
            title.contains('kingdom hearts')) {
          inc('kingdom_hearts');
        }
        if (saga.contains('dragon quest') || title.contains('dragon quest')) {
          inc('dragon_quest');
        }
        if (saga.contains('tales of') || title.contains('tales of')) {
          inc('tales_of');
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
    String fallback, [
    Map<String, List<Map<String, dynamic>>>? milestonesMap,
  ]) {
    final milestonesData = (milestonesMap ?? _sagaMilestones)[groupId];
    if (milestonesData == null || milestonesData.isEmpty) return fallback;
    for (final m in milestonesData) {
      final target = m['target'] as int;
      if (currentProgress < target) {
        return (m['description'] as String?) ?? fallback;
      }
    }
    return (milestonesData.last['description'] as String?) ?? fallback;
  }

  int _getAchievedMilestoneXp(
    String groupId,
    int currentProgress,
    int fallback, [
    Map<String, List<Map<String, dynamic>>>? milestonesMap,
  ]) {
    final milestonesData = (milestonesMap ?? _sagaMilestones)[groupId];
    if (milestonesData == null || milestonesData.isEmpty) return fallback;
    int achievedXp = fallback;
    for (final m in milestonesData) {
      final target = m['target'] as int;
      if (currentProgress >= target) {
        achievedXp = (m['xp'] as int?) ?? fallback;
      } else {
        break;
      }
    }
    return achievedXp;
  }

  Map<String, dynamic> _getBadgeStyle(
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

  void _onAchievementTap(Map<String, dynamic> achievement) {
    if (!widget.isOwnProfile) {
      return; // Inhabilitado si estás viendo un perfil ajeno
    }

    int? companyId;
    int? collectionId;
    int? franchiseId;
    int? collectionId2;
    int? franchiseId2;
    final String aId = achievement['id'] as String;
    final String groupId = achievement['_groupId'] as String;

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
      final milestones = achievement['_milestones'] as List<int>;
      final badgeStyle = _getBadgeStyle(
        achievement,
        achievement['_currentProgress'] as int,
        milestones,
        achievement['_isUnlocked'] as bool,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AchievementGamesScreen(
            achievementId: aId,
            achievementName: achievement['name'] as String,
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
            achievementIcon: badgeStyle['icon'] as IconData,
            achievementColor: badgeStyle['color'] as Color,
          ),
        ),
      ).then((_) => _fetchAchievements());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_achievedList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no hay logros conseguidos en este perfil',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Logros e Hitos Conseguidos (${_achievedList.length})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: _achievedList.length,
          itemBuilder: (context, index) {
            final achievement = _achievedList[index];
            final milestones = achievement['_milestones'] as List<int>;
            final currentProgress = achievement['_currentProgress'] as int;
            final isUnlocked = achievement['_isUnlocked'] as bool;
            final unlockedDate = achievement['_unlockedDate'] as DateTime?;

            final badgeStyle = _getBadgeStyle(
              achievement,
              currentProgress,
              milestones,
              isUnlocked,
            );
            final Color badgeColor = badgeStyle['color'] as Color;
            final Color borderColor = badgeStyle['borderColor'] as Color;
            final IconData badgeIcon = badgeStyle['icon'] as IconData;

            return Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.isOwnProfile
                    ? () => _onAchievementTap(achievement)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(badgeIcon, size: 32, color: badgeColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement['name'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        badgeStyle['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (achievement['_displayDescription'] ??
                                achievement['description'])
                            as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        unlockedDate != null
                            ? '${unlockedDate.day.toString().padLeft(2, '0')}/${unlockedDate.month.toString().padLeft(2, '0')}/${unlockedDate.year}'
                            : 'Desbloqueado',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
