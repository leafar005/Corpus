import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/collection_repository.dart';
import 'widgets/add_game_to_shelf_sheet.dart';
import 'widgets/bulk_add_to_shelf_sheet.dart';
import 'widgets/platform_picker_sheet.dart';
import 'widgets/shelf_game_box.dart' show ShelfGameBox, ShelfSpineLayout;

/// Pantalla de depuración: estantería virtual de juegos por plataforma.
/// Ruta: `/private/collection`
class CollectionShelfScreen extends StatefulWidget {
  const CollectionShelfScreen({super.key});

  @override
  State<CollectionShelfScreen> createState() => _CollectionShelfScreenState();
}

class _CollectionShelfScreenState extends State<CollectionShelfScreen> {
  final _repository = CollectionRepository();

  List<ShelfItem> _items = [];
  bool _loading = true;
  String? _error;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Inicia sesión para ver tu estantería';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repository.fetchShelfGames(userId);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la estantería';
        });
      }
    }
  }

  Future<void> _openAddGame() async {
    final userId = _userId;
    if (userId == null) return;
    await showAddGameToShelfSheet(
      context: context,
      repository: _repository,
      userId: userId,
      onUpdated: _load,
    );
  }

  Future<void> _editItemPlatforms(ShelfItem item) async {
    final userId = _userId;
    if (userId == null) return;

    final owned = await _repository.fetchOwnedPlatforms(
      userId,
      item.game.igdbId,
    );

    if (!mounted) return;

    final library = await _repository.fetchLibraryForShelf(userId);
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
      userId: userId,
      gameId: item.game.igdbId,
      selectedPlatforms: result,
    );
    await _load();
  }

  Future<void> _openBulkAdd() async {
    final userId = _userId;
    if (userId == null) return;
    await showBulkAddToShelfSheet(
      context: context,
      repository: _repository,
      userId: userId,
      onUpdated: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Estantería'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      bottomNavigationBar: _userId != null
          ? _ShelfBottomBar(
              onBulkAdd: _openBulkAdd,
              onAddGame: _openAddGame,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shelves,
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
      );
    }

    if (_items.isEmpty) {
      return _EmptyShelf(onAdd: _openAddGame);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const horizontalPadding = 20.0;
        const gap = ShelfSpineLayout.gap;

        final rows = ShelfSpineLayout.chunkIntoRows(
          _items,
          width,
          horizontalPadding: horizontalPadding * 2,
          gap: gap,
          itemWidth: (item) =>
              ShelfSpineLayout.uiWidthForPlatform(item.platformName),
        );

        return RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '${_items.length} ${_items.length == 1 ? 'caja' : 'cajas'} en tu estantería',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  120,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rowIndex) {
                      final rowItems = rows[rowIndex];
                      return _ShelfRow(
                        items: rowItems,
                        gap: gap,
                        onEditItem: _editItemPlatforms,
                      );
                    },
                    childCount: rows.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shelves,
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
              icon: const Icon(Icons.add),
              label: const Text('Añadir primer juego'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBottomBar extends StatelessWidget {
  const _ShelfBottomBar({
    required this.onBulkAdd,
    required this.onAddGame,
  });

  final VoidCallback onBulkAdd;
  final VoidCallback onAddGame;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBulkAdd,
                  icon: const Icon(Icons.library_add_check_outlined),
                  label: const Text('Selección masiva'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddGame,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir juego'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
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
          // Tablón de estantería
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
