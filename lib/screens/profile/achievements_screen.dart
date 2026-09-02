import 'package:flutter/material.dart';
import 'package:corpus/utils/level_calculator.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../utils/achievement_utils.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'achievements/achievements_controller.dart';

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
  late final AchievementsController _controller;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isLoading => _controller.isLoading;
  int get _currentXp => _controller.currentXp;
  List<Map<String, dynamic>> get _allAchievements =>
      _controller.allAchievements;
  Map<String, DateTime> get _unlockedAchievements =>
      _controller.unlockedAchievements;
  Map<String, int> get _sagaProgress => _controller.sagaProgress;
  Map<String, List<Map<String, dynamic>>> get _sagaMilestones =>
      _controller.sagaMilestones;

  @override
  void initState() {
    super.initState();
    _controller = AchievementsController(
      userId: widget.userId,
      initialXp: widget.initialXp,
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              AppNavigationController.instance.requestBack(context),
        ),
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
                            for (final entry
                                in AchievementUtils
                                    .achievementIgdbIds
                                    .entries) {
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
                              context
                                  .pushAchievementGames(
                                    AchievementGamesArgs(
                                      achievementId: groupId,
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
                                  )
                                  .then((_) {
                                    _controller.load();
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
