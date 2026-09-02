import 'package:flutter/material.dart';
import '../../../repositories/achievements_repository.dart';

/// Controller para [AchievementsScreen].
///
/// Encapsula todas las queries (delegadas a [AchievementsRepository] con
/// [Future.wait] paralelo) y la lógica de procesamiento: agrupación de logros
/// en "sagas", ordenación y cálculo de progreso por saga.
///
/// La pantalla solo llama a [load()] y reacciona a [addListener].
class AchievementsController extends ChangeNotifier {
  AchievementsController({required this.userId, required this.initialXp});

  final String userId;
  int initialXp;

  final _repo = AchievementsRepository();
  bool _disposed = false;

  // ── Estado público ─────────────────────────────────────────────────────────

  bool isLoading = true;
  int currentXp = 0;
  List<Map<String, dynamic>> allAchievements = [];
  Map<String, DateTime> unlockedAchievements = {};
  Map<String, int> sagaProgress = {};
  Map<String, List<Map<String, dynamic>>> sagaMilestones = {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Carga de datos ─────────────────────────────────────────────────────────

  /// Carga en paralelo todas las queries y procesa los resultados.
  Future<void> load() async {
    isLoading = true;
    currentXp = initialXp;
    _notify();

    try {
      final data = await _repo.fetchAll(userId);

      currentXp = data.xp;

      // ── Combinar reviews + user_games, deduplicando por igdb_id ───────────
      final Map<int, dynamic> uniqueBeaten = {};
      for (var item in [...data.reviews, ...data.userGames]) {
        final st = item['status'];
        if (st != 'beaten' && st != 'completed') continue;
        final game = item['games'];
        if (game == null) continue;
        final int? gameId = game['igdb_id'] as int?;
        if (gameId != null) uniqueBeaten[gameId] = item;
      }
      final beatenList = uniqueBeaten.values.toList();

      // ── Agrupar achievements en "sagas" ────────────────────────────────────
      final Map<String, Map<String, dynamic>> grouped = {};
      final Map<String, List<Map<String, dynamic>>> milestones = {};

      for (final ach in data.achievements) {
        final String name = ach['name'] as String;
        final String baseName = name
            .replaceAll(RegExp(r'\s*\(.*\)'), '')
            .replaceAll(RegExp(r'\s+\d+$'), '');
        final String aId = ach['id'] as String;

        String groupId = aId;
        final matchSuffix = RegExp(r'_(\d+|all)$').firstMatch(aId);
        if (matchSuffix != null) {
          groupId = aId.substring(0, aId.length - matchSuffix.group(0)!.length);
        }

        final int target = (ach['saga_target'] as num?)?.toInt() ?? 1;

        if (!grouped.containsKey(groupId)) {
          grouped[groupId] = Map<String, dynamic>.from(ach)
            ..['name'] = baseName
            ..['original_name'] = name;
          milestones[groupId] = [
            {
              'target': target,
              'xp': ach['xp_reward'],
              'description': ach['description'],
            },
          ];
        } else {
          milestones[groupId]!.add({
            'target': target,
            'xp': ach['xp_reward'],
            'description': ach['description'],
          });
          final int currentXpReward = grouped[groupId]!['xp_reward'] as int;
          final int newXpReward = ach['xp_reward'] as int;
          if (newXpReward > currentXpReward) {
            grouped[groupId]!
              ..['id'] = aId
              ..['name'] = baseName
              ..['description'] = ach['description']
              ..['xp_reward'] = ach['xp_reward']
              ..['rarity'] = ach['rarity']
              ..['original_name'] = name;
          }
        }
      }

      for (final list in milestones.values) {
        list.sort((a, b) => (a['target'] as int).compareTo(b['target'] as int));
      }

      // ── Calcular progreso de cada saga ────────────────────────────────────
      final progress = calculateSagaProgress(
        beatenList,
        grouped.values.toList(),
      );

      // ── Ordenar: en progreso → completados → sin empezar; luego por XP ────
      final sorted = grouped.values.toList();
      sorted.sort((a, b) {
        String groupIdOf(String id) {
          final m = RegExp(r'_(\d+|all)$').firstMatch(id);
          return m != null
              ? id.substring(0, id.length - m.group(0)!.length)
              : id;
        }

        final String gIdA = groupIdOf(a['id'] as String);
        final String gIdB = groupIdOf(b['id'] as String);
        final int progA = progress[gIdA] ?? 0;
        final int progB = progress[gIdB] ?? 0;

        final List<Map<String, dynamic>> msA =
            milestones[gIdA] ??
            [
              {'target': 1},
            ];
        final List<Map<String, dynamic>> msB =
            milestones[gIdB] ??
            [
              {'target': 1},
            ];
        final int maxA = msA.last['target'] as int;
        final int maxB = msB.last['target'] as int;

        final bool unlockedA =
            data.unlocked.containsKey(a['id']) ||
            data.unlocked.keys.any(
              (k) => k == gIdA || k.startsWith('${gIdA}_'),
            ) ||
            progA >= maxA;
        final bool unlockedB =
            data.unlocked.containsKey(b['id']) ||
            data.unlocked.keys.any(
              (k) => k == gIdB || k.startsWith('${gIdB}_'),
            ) ||
            progB >= maxB;

        int cat(int prog, int maxT, bool unlocked) {
          if (prog >= maxT || (unlocked && maxT <= 1)) {
            return 1; // completo → abajo
          }
          if (prog > 0) return 0; // en progreso → arriba
          return 2; // sin empezar → al final
        }

        final int catA = cat(progA, maxA, unlockedA);
        final int catB = cat(progB, maxB, unlockedB);
        if (catA != catB) return catA.compareTo(catB);

        final int xpA = (a['xp_reward'] as num?)?.toInt() ?? 0;
        final int xpB = (b['xp_reward'] as num?)?.toInt() ?? 0;
        if (xpA != xpB) return xpB.compareTo(xpA);

        return (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        );
      });

      allAchievements = sorted;
      unlockedAchievements = data.unlocked;
      sagaProgress = progress;
      sagaMilestones = milestones;
      isLoading = false;
    } catch (e) {
      debugPrint('[AchievementsController] Error: $e');
      isLoading = false;
    }

    _notify();
  }

  // ── Lógica pura (testeable) ────────────────────────────────────────────────

  /// Calcula cuántos juegos del [beatenList] aplican a cada saga/prefijo.
  ///
  /// Devuelve un Map { groupId → count }.
  /// Este método es estático y puro para facilitar los tests.
  static Map<String, int> calculateSagaProgress(
    List<dynamic> beatenList,
    List<Map<String, dynamic>> achievementsList,
  ) {
    final Map<String, int> counts = {};
    for (final item in beatenList) {
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
      final fra = franchises?.join(' ').toLowerCase() ?? '';
      final saga = '$col $fra';
      final title = (game['title'] as String?)?.toLowerCase() ?? '';

      void inc(String prefix) => counts[prefix] = (counts[prefix] ?? 0) + 1;

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
          title.contains('demon souls') ||
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
                  saga.contains("dragon's dogma") ||
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
                  title.contains("dragon's dogma") ||
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
      if (!isCrossover &&
          (saga.contains('pokemon') ||
              saga.contains('pokémon') ||
              title.contains('pokemon') ||
              title.contains('pokémon'))) {
        inc('pokemon');
      }
      if (!isCrossover) {
        if (saga.contains('zelda') || title.contains('zelda')) inc('zelda');
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
        if (saga.contains('sonic') || title.contains('sonic')) inc('sonic');
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
        if (saga.contains('kirby') || title.contains('kirby')) inc('kirby');
        if (saga.contains('devil may cry') || title.contains('devil may cry')) {
          inc('devil_may_cry');
        }
        if (saga.contains('castlevania') || title.contains('castlevania')) {
          inc('castlevania');
        }
        if (saga.contains('mass effect') || title.contains('mass effect')) {
          inc('mass_effect');
        }
        if (saga.contains('doom') || title.contains('doom')) inc('doom');
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
        if (saga.contains('halo') || title.contains('halo')) inc('halo');
      }
      if (gameModes != null &&
          gameModes.any(
            (mode) => mode.toString().toLowerCase().contains('single player'),
          )) {
        inc('lone_wolf');
      }
    }
    return counts;
  }
}
