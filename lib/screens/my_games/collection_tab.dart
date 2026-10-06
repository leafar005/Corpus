import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';

import '../../repositories/collection_repository.dart';
import '../profile/widgets/add_game_to_shelf_sheet.dart';
import '../profile/widgets/bulk_add_to_shelf_sheet.dart';
import '../profile/widgets/platform_picker_sheet.dart';
import '../profile/widgets/shelf_game_box.dart' show ShelfGameBox, ShelfSpineLayout;

/// Pestaña "Colección" de Mis juegos: estantería virtual de juegos por plataforma.
class CollectionTab extends StatefulWidget {
  const CollectionTab({
    super.key,
    required this.userId,
    this.showInlineActions = true,
    this.horizontalPadding,
  });

  final String userId;
  final bool showInlineActions;
  final double? horizontalPadding;

  @override
  State<CollectionTab> createState() => CollectionTabState();
}

class CollectionTabState extends State<CollectionTab> {
  final _repository = CollectionRepository();

  List<ShelfItem> _items = [];
  bool _loading = true;
  String? _error;

  bool get isLoading => _loading;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => _load();

  Future<void> openAddGame() => _openAddGame();

  Future<void> openBulkAdd() => _openBulkAdd();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repository.fetchShelfGames(widget.userId);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la estantería';
        });
      }
    }
  }

  Future<void> _openAddGame() async {
    await showAddGameToShelfSheet(
      context: context,
      repository: _repository,
      userId: widget.userId,
      onUpdated: _load,
    );
  }

  Future<void> _openBulkAdd() async {
    await showBulkAddToShelfSheet(
      context: context,
      repository: _repository,
      userId: widget.userId,
      onUpdated: _load,
    );
  }

  Future<void> _editItemPlatforms(ShelfItem item) async {
    final owned = await _repository.fetchOwnedPlatforms(
      widget.userId,
      item.game.igdbId,
    );

    if (!mounted) return;

    final library = await _repository.fetchLibraryForShelf(widget.userId);
    if (!mounted) return;

    LibraryGameOption option;
    try {
      option = library.firstWhere((o) => o.game.igdbId == item.game.igdbId);
    } catch (_) {
      option = LibraryGameOption(
        game: item.game,
        ownedPlatforms: owned,
      );
    }

    final result = await showPlatformPickerSheet(
      context: context,
      gameTitle: item.game.title,
      initialSelected: owned,
      suggestedPlatforms: option.suggestedPlatforms,
    );

    if (!mounted || result == null) return;

    await _repository.setPlatformsForGame(
      userId: widget.userId,
      gameId: item.game.igdbId,
      selectedPlatforms: result,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorpusTablerIcon(
                  CorpusIconKind.Shelves,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: CollectionEmptyShelf(onAdd: _openAddGame),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = widget.horizontalPadding ?? (isDesktop ? 40.0 : 16.0);
    const gap = ShelfSpineLayout.gap;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.showInlineActions)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                8,
              ),
              child: CollectionShelfActionBar(
                onBulkAdd: _openBulkAdd,
                onAddGame: _openAddGame,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
            child: Text(
              '${_items.length} ${_items.length == 1 ? 'caja' : 'cajas'} en tu estantería',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.crossAxisExtent;
            final rows = ShelfSpineLayout.chunkIntoRows(
              _items,
              width,
              horizontalPadding: horizontalPadding * 2,
              gap: gap,
              itemWidth: (item) =>
                  ShelfSpineLayout.uiWidthForPlatform(item.platformName),
            );

            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                120,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, rowIndex) {
                    return CollectionShelfRow(
                      items: rows[rowIndex],
                      gap: gap,
                      onEditItem: _editItemPlatforms,
                    );
                  },
                  childCount: rows.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class CollectionEmptyShelf extends StatelessWidget {
  const CollectionEmptyShelf({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CorpusTablerIcon(
              CorpusIconKind.Shelves,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Tu estantería está vacía',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Añade plataformas a tus juegos para llenar tu estantería virtual con cajas físicas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const CorpusTablerIcon(CorpusIconKind.Add),
              label: const Text('Añadir primer juego'),
            ),
          ],
        ),
      ),
    );
  }
}

class CollectionShelfActionBar extends StatelessWidget {
  const CollectionShelfActionBar({
    super.key,
    required this.onBulkAdd,
    required this.onAddGame,
  });

  final VoidCallback onBulkAdd;
  final VoidCallback onAddGame;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBulkAdd,
            icon: const CorpusTablerIcon(CorpusIconKind.LibraryAddCheckOutlined),
            label: const Text('Selección masiva'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onAddGame,
            icon: const CorpusTablerIcon(CorpusIconKind.Add),
            label: const Text('Añadir juego'),
          ),
        ),
      ],
    );
  }
}

class CollectionShelfRow extends StatelessWidget {
  const CollectionShelfRow({
    super.key,
    required this.items,
    required this.gap,
    required this.onEditItem,
  });

  final List<ShelfItem> items;
  final double gap;
  final void Function(ShelfItem item) onEditItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                ShelfGameBox(
                  game: items[i].game,
                  platformName: items[i].platformName,
                  onLongPress: () => onEditItem(items[i]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surfaceContainerHigh,
                  colorScheme.surfaceContainerHighest,
                  Color.lerp(
                    colorScheme.surfaceContainerHighest,
                    Colors.black,
                    0.35,
                  )!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          Container(
            height: 3,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
