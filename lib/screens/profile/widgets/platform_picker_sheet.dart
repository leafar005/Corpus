import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../../repositories/collection_repository.dart';
import '../../../utils/shelf_platforms.dart';

/// Bottom sheet para elegir plataformas de propiedad (catálogo fijo de estantería).
Future<List<String>?> showPlatformPickerSheet({
  required BuildContext context,
  required String gameTitle,
  required List<String> initialSelected,
  List<String> suggestedPlatforms = const [],
  List<String> gamePlatforms = const [],
  int? gameId,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return _PlatformPickerSheet(
        gameTitle: gameTitle,
        initialSelected: ShelfPlatforms.normalizeIds(initialSelected),
        suggestedPlatforms: ShelfPlatforms.normalizeIds(suggestedPlatforms),
        gamePlatforms: gamePlatforms,
        gameId: gameId,
      );
    },
  );
}

class _PlatformPickerSheet extends StatefulWidget {
  const _PlatformPickerSheet({
    required this.gameTitle,
    required this.initialSelected,
    required this.suggestedPlatforms,
    this.gamePlatforms = const [],
    this.gameId,
  });

  final String gameTitle;
  final List<String> initialSelected;
  final List<String> suggestedPlatforms;
  /// Plataformas IGDB del juego (nombres como 'PlayStation 5', 'PC (Windows)', etc.).
  /// Si no está vacío, solo se muestran las plataformas de estantería que
  /// correspondan a alguna de estas plataformas del catálogo.
  final List<String> gamePlatforms;
  final int? gameId;

  @override
  State<_PlatformPickerSheet> createState() => _PlatformPickerSheetState();
}

class _PlatformPickerSheetState extends State<_PlatformPickerSheet> {
  late Set<String> _selected;
  late List<String> _gamePlatforms;
  bool _resolvingPlatforms = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
    _gamePlatforms = List<String>.from(widget.gamePlatforms);
    if (_selected.isEmpty && widget.suggestedPlatforms.isNotEmpty) {
      _selected = widget.suggestedPlatforms.toSet();
    }
    if (_gamePlatforms.isEmpty && widget.gameId != null && widget.gameId! > 0) {
      _resolveMissingPlatforms(widget.gameId!);
    }
  }

  Future<void> _resolveMissingPlatforms(int gameId) async {
    setState(() => _resolvingPlatforms = true);
    try {
      final igdbGame = await IGDBService.getGameById(gameId);
      if (igdbGame != null && igdbGame['platforms'] is List) {
        final names = (igdbGame['platforms'] as List)
            .map((p) => p is Map ? p['name']?.toString() ?? '' : p.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.isNotEmpty) {
          _gamePlatforms = names;
          // Persistir en Supabase para futuras consultas
          Supabase.instance.client
              .from('games')
              .update({'platforms': names})
              .eq('igdb_id', gameId)
              .then((_) {})
              .catchError((_) {});
        }
      }
    } catch (_) {
      // Si falla IGDB, mantenemos la lista actual
    } finally {
      if (mounted) {
        setState(() => _resolvingPlatforms = false);
      }
    }
  }

  List<({String group, List<ShelfPlatform> platforms})> get _grouped {
    final gp = _gamePlatforms;
    final map = <String, List<ShelfPlatform>>{};
    for (final platform in ShelfPlatforms.all) {
      // Si tenemos plataformas del juego, filtramos: solo mostramos las que
      // coinciden con alguna plataforma IGDB del título, o las ya seleccionadas.
      if (gp.isNotEmpty &&
          !ShelfPlatforms.gameMatchesShelfPlatform(gp, platform.id) &&
          !_selected.contains(platform.id)) {
        continue;
      }
      map.putIfAbsent(platform.group, () => []).add(platform);
    }
    return [
      for (final group in ShelfPlatforms.groupOrder)
        if (map.containsKey(group)) (group: group, platforms: map[group]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿En qué plataforma lo tienes?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.gameTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.suggestedPlatforms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    CorpusTablerIcon(CorpusIconKind.LightbulbOutline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sugeridas según tus reseñas o Steam',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _resolvingPlatforms
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        children: [
                          for (final section in _grouped) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          section.group,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final platform in section.platforms)
                        _PlatformTile(
                          platform: platform,
                          isSelected: _selected.contains(platform.id),
                          isSuggested: widget.suggestedPlatforms.contains(
                            platform.id,
                          ),
                          onToggle: () {
                            setState(() {
                              if (_selected.contains(platform.id)) {
                                _selected.remove(platform.id);
                              } else {
                                _selected.add(platform.id);
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected.toList()),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({
    required this.platform,
    required this.isSelected,
    required this.isSuggested,
    required this.onToggle,
  });

  final ShelfPlatform platform;
  final bool isSelected;
  final bool isSuggested;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? platform.color.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: platform.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: _PlatformIcon(platform: platform),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (isSuggested)
                        Text(
                          'Sugerida',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Checkbox(value: isSelected, onChanged: (_) => onToggle()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({required this.platform});

  final ShelfPlatform platform;

  @override
  Widget build(BuildContext context) {
    if (platform.iconAsset != null) {
      return Image.asset(
        platform.iconAsset!,
        width: 20,
        height: 20,
        color: platform.textColor,
        errorBuilder: (_, _, _) => CorpusTablerIcon(platform.fallbackIcon ?? CorpusIconKind.SportsEsports,
          size: 18,
          color: platform.textColor,
        ),
      );
    }
    return CorpusTablerIcon(platform.fallbackIcon ?? CorpusIconKind.SportsEsports,
      size: 18,
      color: platform.textColor,
    );
  }
}

/// Abre el picker y persiste en Supabase.
Future<bool> pickAndSavePlatforms({
  required BuildContext context,
  required CollectionRepository repository,
  required String userId,
  required LibraryGameOption option,
}) async {
  final result = await showPlatformPickerSheet(
    context: context,
    gameTitle: option.game.title,
    initialSelected: option.ownedPlatforms,
    suggestedPlatforms: option.suggestedPlatforms,
    gamePlatforms: option.game.platforms,
    gameId: option.game.igdbId,
  );

  if (result == null) return false;

  await repository.setPlatformsForGame(
    userId: userId,
    gameId: option.game.igdbId,
    selectedPlatforms: result,
  );
  return true;
}
