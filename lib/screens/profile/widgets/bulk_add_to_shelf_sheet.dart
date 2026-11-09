import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../../repositories/collection_repository.dart';
import '../../../utils/shelf_platforms.dart';
import '../../../widgets/corpus_network_image.dart';

Future<void> showBulkAddToShelfSheet({
  required BuildContext context,
  required CollectionRepository repository,
  required String userId,
  required VoidCallback onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => BulkAddToShelfSheet(
      repository: repository,
      userId: userId,
      onUpdated: onUpdated,
    ),
  );
}

class BulkAddToShelfSheet extends StatefulWidget {
  const BulkAddToShelfSheet({
    super.key,
    required this.repository,
    required this.userId,
    required this.onUpdated,
  });

  final CollectionRepository repository;
  final String userId;
  final VoidCallback onUpdated;

  @override
  State<BulkAddToShelfSheet> createState() => _BulkAddToShelfSheetState();
}

class _BulkAddToShelfSheetState extends State<BulkAddToShelfSheet> {
  String? _platformId;
  List<LibraryGameOption>? _options;
  bool _loading = true;
  bool _saving = false;
  String _query = '';
  bool _hideAlreadyOnShelf = true;
  bool _filterByCatalogPlatform = true;
  final Set<int> _selectedGameIds = {};

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _loading = true);
    try {
      final options = await widget.repository.fetchLibraryForShelf(
        widget.userId,
      );
      if (mounted) {
        setState(() {
          _options = options;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LibraryGameOption> get _filtered {
    final list = _options ?? [];
    var result = list;

    if (_platformId != null && _filterByCatalogPlatform) {
      result = result
          .where(
            (o) => ShelfPlatforms.gameMatchesShelfPlatform(
              o.game.platforms,
              _platformId!,
            ),
          )
          .toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((o) => o.game.title.toLowerCase().contains(q))
          .toList();
    }

    if (_platformId != null && _hideAlreadyOnShelf) {
      result = result
          .where((o) => !o.ownedPlatforms.contains(_platformId))
          .toList();
    }

    return result;
  }

  void _applySmartSelectionForPlatform(String platformId) {
    _selectedGameIds.clear();
    for (final option in _options ?? []) {
      if (option.ownedPlatforms.contains(platformId)) continue;
      if (_filterByCatalogPlatform &&
          !ShelfPlatforms.gameMatchesShelfPlatform(
            option.game.platforms,
            platformId,
          )) {
        continue;
      }
      if (option.suggestedPlatforms.contains(platformId)) {
        _selectedGameIds.add(option.game.igdbId);
      }
    }
  }

  void _selectPlatform(String platformId) {
    setState(() {
      _platformId = platformId;
      _applySmartSelectionForPlatform(platformId);
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final option in _filtered) {
        _selectedGameIds.add(option.game.igdbId);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedGameIds.clear);
  }

  Future<void> _save() async {
    final platformId = _platformId;
    if (platformId == null || _selectedGameIds.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final count = await widget.repository.bulkAddPlatform(
        userId: widget.userId,
        platformName: platformId,
        gameIds: _selectedGameIds,
      );
      if (!mounted) return;
      widget.onUpdated();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? '1 juego añadido a la estantería'
                : '$count juegos añadidos a la estantería',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la selección')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = _platformId != null
        ? ShelfPlatforms.resolve(_platformId!)
        : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selección masiva',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige una plataforma y marca los juegos de tu biblioteca.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PlatformSelector(
                      selectedId: _platformId,
                      onSelected: _selectPlatform,
                    ),
                    if (_platformId != null) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final ext = Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!;
                          final searchBorder = OutlineInputBorder(
                            borderRadius: ext.radiusMedium,
                            borderSide: BorderSide.none,
                          );
                          return TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar en tu biblioteca…',
                              prefixIcon: const CorpusTablerIcon(
                                CorpusIconKind.Search,
                                size: 20,
                              ),
                              border: searchBorder,
                              enabledBorder: searchBorder,
                              focusedBorder: searchBorder,
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              suffixText: platform?.shortLabel,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Solo de esta plataforma'),
                            selected: _filterByCatalogPlatform,
                            onSelected: (v) => setState(() {
                              _filterByCatalogPlatform = v;
                              if (_platformId != null) {
                                _applySmartSelectionForPlatform(_platformId!);
                              }
                            }),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Ocultar en estantería'),
                            selected: _hideAlreadyOnShelf,
                            onSelected: (v) =>
                                setState(() => _hideAlreadyOnShelf = v),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: _filtered.isEmpty ? null : _selectAllVisible,
                            child: const Text('Todos'),
                          ),
                          TextButton(
                            onPressed: _selectedGameIds.isEmpty
                                ? null
                                : _clearSelection,
                            child: const Text('Ninguno'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(child: _buildGameList(scrollController)),
                  ],
                ),
              ),
            ),
            _BottomBar(
              platformId: _platformId,
              selectedCount: _selectedGameIds.length,
              saving: _saving,
              onSave: _save,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameList(ScrollController scrollController) {
    if (_platformId == null) {
      return Center(
        child: Text(
          'Selecciona una plataforma arriba para ver tu biblioteca',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          _options?.isEmpty == true
              ? 'Tu biblioteca está vacía.'
              : _filterByCatalogPlatform
              ? 'Ningún juego de tu biblioteca coincide con $_platformId.\n'
                    'Desactiva "Solo de esta plataforma" para ver todos.'
              : 'No hay juegos que coincidan.\nPrueba a mostrar los ya en estantería.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final option = _filtered[index];
        final gameId = option.game.igdbId;
        final alreadyOnShelf =
            _platformId != null &&
            option.ownedPlatforms.contains(_platformId);

        return CheckboxListTile(
          value: _selectedGameIds.contains(gameId),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedGameIds.add(gameId);
              } else {
                _selectedGameIds.remove(gameId);
              }
            });
          },
          secondary: _CoverThumb(coverUrl: option.game.coverUrl),
          title: Text(
            option.game.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: alreadyOnShelf
              ? Text(
                  'Ya en estantería ($_platformId)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        );
      },
    );
  }
}

class _PlatformSelector extends StatelessWidget {
  const _PlatformSelector({
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (selectedId != null) {
      final platform = ShelfPlatforms.resolve(selectedId!);
      return Material(
        color: platform.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openPlatformList(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: platform.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: _PlatformMiniIcon(platform: platform),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plataforma',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        platform.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const CorpusTablerIcon(CorpusIconKind.ExpandMore),
              ],
            ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _openPlatformList(context),
      icon: const CorpusTablerIcon(CorpusIconKind.SportsEsports),
      label: const Text('Elegir plataforma'),
    );
  }

  void _openPlatformList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PlatformListSheet(
        selectedId: selectedId,
        onSelected: (id) {
          onSelected(id);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _PlatformListSheet extends StatelessWidget {
  const _PlatformListSheet({
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ShelfPlatform>>{};
    for (final p in ShelfPlatforms.all) {
      grouped.putIfAbsent(p.group, () => []).add(p);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return ValueListenableBuilder<bool>(
          valueListenable: floatingMobileNavNotifier,
          builder: (context, _, _) => ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + getFloatingNavModalInset(context),
            ),
            children: [
              Text(
                'Plataforma',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final group in ShelfPlatforms.groupOrder) ...[
                if (grouped.containsKey(group)) ...[
                  Text(
                    group,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final platform in grouped[group]!)
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: platform.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _PlatformMiniIcon(platform: platform),
                      ),
                      title: Text(platform.label),
                      trailing: selectedId == platform.id
                          ? CorpusTablerIcon(CorpusIconKind.CheckCircle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => onSelected(platform.id),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlatformMiniIcon extends StatelessWidget {
  const _PlatformMiniIcon({required this.platform});

  final ShelfPlatform platform;

  @override
  Widget build(BuildContext context) {
    if (platform.iconAsset != null) {
      return Image.asset(
        platform.iconAsset!,
        width: 18,
        height: 18,
        color: platform.textColor,
      );
    }
    return CorpusTablerIcon(platform.fallbackIcon ?? CorpusIconKind.SportsEsports,
      size: 16,
      color: platform.textColor,
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 36,
        height: 48,
        child: url.isNotEmpty
            ? CorpusNetworkImage(url: url, fit: BoxFit.cover)
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const CorpusTablerIcon(CorpusIconKind.VideogameAsset, size: 18),
              ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.platformId,
    required this.selectedCount,
    required this.saving,
    required this.onSave,
  });

  final String? platformId;
  final int selectedCount;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final canSave = platformId != null && selectedCount > 0 && !saving;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: floatingMobileNavNotifier,
          builder: (context, _, _) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + getFloatingNavModalInset(context),
            ),
            child: FilledButton(
              onPressed: canSave ? onSave : null,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      platformId == null
                          ? 'Elige plataforma y juegos'
                          : selectedCount == 0
                          ? 'Marca al menos un juego'
                          : 'Añadir $selectedCount ${selectedCount == 1 ? 'juego' : 'juegos'}',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
