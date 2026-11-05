import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/utils/shelf_platforms.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/design/corpus_empty_state.dart';
import 'package:corpus/widgets/game_card.dart';

import '../../repositories/collection_repository.dart';
import '../profile/widgets/add_game_to_shelf_sheet.dart';
import '../profile/widgets/bulk_add_to_shelf_sheet.dart';
import '../profile/widgets/platform_picker_sheet.dart';
import '../profile/widgets/shelf_game_box.dart'
    show ShelfGameBox, ShelfSpineLayout;

/// Pestaña "Estantería" de Mis juegos: estantería virtual de juegos por plataforma.
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
  bool _spineView = true; // true = lomo de juego físico, false = GameCards

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedPlatform;

  bool get isLoading => _loading;

  bool get _isOwner =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    reload();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ShelfItem> get _filteredItems {
    var list = _items;
    final q = _searchQuery.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((i) => i.game.title.toLowerCase().contains(q)).toList();
    }
    if (_selectedPlatform != null) {
      list = list.where((i) => i.platformName == _selectedPlatform).toList();
    }
    return list;
  }

  List<String> get _availablePlatforms {
    final set = <String>{};
    for (final item in _items) {
      if (item.platformName.isNotEmpty) {
        set.add(item.platformName);
      }
    }
    final list = set.toList()..sort();
    return list;
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
          if (_selectedPlatform != null &&
              !items.any((i) => i.platformName == _selectedPlatform)) {
            _selectedPlatform = null;
          }
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
    if (!_isOwner) return;
    await showAddGameToShelfSheet(
      context: context,
      repository: _repository,
      userId: widget.userId,
      onUpdated: _load,
    );
  }

  Future<void> _openBulkAdd() async {
    if (!_isOwner) return;
    await showBulkAddToShelfSheet(
      context: context,
      repository: _repository,
      userId: widget.userId,
      onUpdated: _load,
    );
  }

  Future<void> _editItemPlatforms(ShelfItem item) async {
    if (!_isOwner) return;
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
      gamePlatforms: item.game.platforms.isNotEmpty
          ? item.game.platforms
          : option.game.platforms,
      gameId: item.game.igdbId,
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
          child: CorpusEmptyState(
            icon: CorpusIconKind.Shelves,
            title: _error!,
            actionLabel: 'Reintentar',
            actionIcon: CorpusIconKind.Refresh,
            onAction: _load,
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: CollectionEmptyShelf(onAdd: _isOwner ? _openAddGame : null),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final horizontalPadding =
        widget.horizontalPadding ?? (isDesktop ? 40.0 : 16.0);
    const gap = ShelfSpineLayout.gap;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final filtered = _filteredItems;
    final platforms = _availablePlatforms;

    return SliverMainAxisGroup(
      slivers: [
        if (widget.showInlineActions && _isOwner)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                8,
              ),
              child: CollectionShelfActionBar(
                onBulkAdd: _openBulkAdd,
                onAddGame: _openAddGame,
              ),
            ),
          ),
        // ── Barra de controles: Buscador + Switch Vista ───────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              4,
              horizontalPadding,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Buscador
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: 'Buscar en estantería…',
                            prefixIcon: const CorpusTablerIcon(
                              CorpusIconKind.Search,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const CorpusTablerIcon(
                                      CorpusIconKind.Clear,
                                      size: 18,
                                    ),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: ext.radiusMedium,
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: ext.radiusMedium,
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: ext.radiusMedium,
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Switch de estilo visual con esquinas y altura unificadas
                      _ShelfViewToggle(
                        spineView: _spineView,
                        onChanged: (val) => setState(() => _spineView = val),
                      ),
                    ],
                  ),
                ),
                // ── Filtros por plataforma ─────────────────────────
                if (platforms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            showCheckmark: false,
                            label: Text('Todas (${_items.length})'),
                            selected: _selectedPlatform == null,
                            onSelected: (_) =>
                                setState(() => _selectedPlatform = null),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                        for (final p in platforms) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Builder(
                              builder: (context) {
                                final resolved = ShelfPlatforms.resolve(p);
                                final count = _items
                                    .where((i) => i.platformName == p)
                                    .length;
                                return FilterChip(
                                  showCheckmark: false,
                                  avatar: CircleAvatar(
                                    radius: 5,
                                    backgroundColor: resolved.color,
                                  ),
                                  label: Text('${resolved.shortLabel} ($count)'),
                                  selected: _selectedPlatform == p,
                                  onSelected: (sel) => setState(
                                    () => _selectedPlatform = sel ? p : null,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_isOwner) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CorpusTablerIcon(
                        CorpusIconKind.InfoOutline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _spineView
                              ? 'Toca una caja para ver su ficha · Mantén pulsado para editar o quitar plataformas'
                              : 'Toca la portada para ver su ficha o el icono superior para editar plataformas',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Contenido ─────────────────────────────────────────────
        if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: CorpusEmptyState(
                icon: CorpusIconKind.Search,
                title: 'Sin resultados',
                subtitle: 'No hay cajas que coincidan con los filtros.',
              ),
            ),
          )
        else if (_spineView)
          _buildSpineSliver(filtered, horizontalPadding, gap)
        else
          _buildGridSliver(filtered, horizontalPadding),
      ],
    );
  }

  Widget _buildSpineSliver(
    List<ShelfItem> items,
    double horizontalPadding,
    double gap,
  ) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final rows = ShelfSpineLayout.chunkIntoRows(
          items,
          width,
          horizontalPadding: horizontalPadding * 2,
          gap: gap,
          itemWidth: (item) =>
              ShelfSpineLayout.uiWidthForPlatform(item.platformName),
        );

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            getBottomSpacer(context),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, rowIndex) {
                return CollectionShelfRow(
                  items: rows[rowIndex],
                  gap: gap,
                  onEditItem: _isOwner ? _editItemPlatforms : null,
                );
              },
              childCount: rows.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridSliver(List<ShelfItem> items, double horizontalPadding) {
    return ValueListenableBuilder<int>(
      valueListenable: mobileGridColumnsNotifier,
      builder: (context, columns, _) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            getBottomSpacer(context),
          ),
          sliver: SliverGrid(
            gridDelegate: getCorpusGridDelegate(
              context,
              columns,
              desktopMaxExtent: 120.0,
              spacing: 12.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final item = items[i];
                final platform = ShelfPlatforms.resolve(item.platformName);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GameCard(
                      key: ValueKey('${item.game.igdbId}_${item.platformName}'),
                      game: item.game,
                      onReturn: _load,
                    ),
                    // Insignia de plataforma (arriba izquierda)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: platform.color.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            platform.shortLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: platform.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Botón para editar plataformas de esta caja (arriba derecha)
                    if (_isOwner)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _editItemPlatforms(item),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: CorpusTablerIcon(
                                CorpusIconKind.EditOutlined,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

class _ShelfViewToggle extends StatelessWidget {
  const _ShelfViewToggle({
    required this.spineView,
    required this.onChanged,
  });

  final bool spineView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildOption({
      required bool value,
      required CorpusIconKind icon,
      required String tooltip,
    }) {
      final selected = spineView == value;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: ext.radiusSmall,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: ext.radiusSmall,
            ),
            alignment: Alignment.center,
            child: CorpusTablerIcon(
              icon,
              size: 18,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: ext.radiusMedium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildOption(
            value: true,
            icon: CorpusIconKind.Shelves,
            tooltip: 'Estilo estantería (lomos)',
          ),
          const SizedBox(width: 2),
          buildOption(
            value: false,
            icon: CorpusIconKind.ViewCarouselOutlined,
            tooltip: 'Estilo portadas (GameCards)',
          ),
        ],
      ),
    );
  }
}

class CollectionEmptyShelf extends StatelessWidget {
  const CollectionEmptyShelf({super.key, this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CorpusEmptyState(
        icon: CorpusIconKind.Shelves,
        title: onAdd != null
            ? 'Tu estantería está vacía'
            : 'Esta estantería está vacía',
        subtitle: onAdd != null
            ? 'Añade plataformas a tus juegos para llenar tu estantería virtual con cajas físicas.'
            : 'Este usuario aún no ha añadido juegos a su estantería.',
        actionLabel: onAdd != null ? 'Añadir primer juego' : null,
        actionIcon: onAdd != null ? CorpusIconKind.Add : null,
        onAction: onAdd,
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
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onBulkAdd,
              style: buttonStyle,
              icon: CorpusTablerIcon(
                CorpusIconKind.LibraryAddCheckOutlined,
                size: 18,
                color: colorScheme.onSurface,
              ),
              label: const Text('Selección masiva'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onAddGame,
              style: buttonStyle.copyWith(
                backgroundColor: WidgetStatePropertyAll(
                  colorScheme.primary.withValues(alpha: 0.18),
                ),
                foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
              ),
              icon: CorpusTablerIcon(
                CorpusIconKind.Add,
                size: 18,
                color: colorScheme.primary,
              ),
              label: const Text('Añadir juego'),
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionShelfRow extends StatelessWidget {
  const CollectionShelfRow({
    super.key,
    required this.items,
    required this.gap,
    this.onEditItem,
  });

  final List<ShelfItem> items;
  final double gap;
  final void Function(ShelfItem item)? onEditItem;

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
                  onLongPress:
                      onEditItem != null ? () => onEditItem!(items[i]) : null,
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
