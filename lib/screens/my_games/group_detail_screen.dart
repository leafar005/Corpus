import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/design/corpus_empty_state.dart';
import 'package:corpus/widgets/design/corpus_snackbar.dart';
import '../../models/models.dart';
import '../../repositories/game_group_repository.dart';
import '../../widgets/game_card.dart';
import 'widgets/game_search_picker_sheet.dart';

/// Vista de detalle de una colección.
///
/// Parámetros:
/// - [userId] — propietario de la colección (puede ser otro usuario).
/// - [isRanked] — si true muestra el número de posición en cada tarjeta.
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.userId,
    required this.groupId,
    required this.initialName,
    this.isRanked = false,
    this.onChanged,
  });

  final String userId;
  final String groupId;
  final String initialName;
  final bool isRanked;
  final VoidCallback? onChanged;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _repository = GameGroupRepository();

  GameGroup? _group;
  bool _loading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isOwner =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  bool get _isRanked => _group?.isRanked ?? widget.isRanked;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final group = await _repository.fetchGroupDetail(
        widget.groupId,
        widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _group = group;
        _loading = false;
        if (group == null) _error = 'Colección no encontrada';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la colección';
      });
    }
  }

  List<GameGroupItem> get _filteredItems {
    final items = _group?.items ?? [];
    final q = _searchQuery.trim();
    if (q.isEmpty) return items;
    return items.where((i) {
      return i.game?.title.toLowerCase().contains(q) ?? false;
    }).toList();
  }

  Future<void> _addGame() async {
    if (!_isOwner) return;
    final excludeIds = (_group?.items ?? []).map((i) => i.gameId).toSet();

    final game = await showGameSearchPicker(
      context,
      excludeGameIds: excludeIds,
      title: 'Añadir a la colección',
      subtitle: 'Elige entre tus juegos terminados',
    );

    if (game == null) return;

    try {
      await _repository.addGameToGroup(groupId: widget.groupId, game: game);
      widget.onChanged?.call();
      await _load();
      if (mounted) {
        showCorpusSnackBar(
          context,
          message: '«${game.title}» añadido',
          variant: CorpusSnackBarVariant.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showCorpusSnackBar(
          context,
          message:
              'No se pudo añadir el juego (¿ya está en la colección?)',
          variant: CorpusSnackBarVariant.error,
        );
      }
    }
  }

  Future<void> _removeItem(GameGroupItem item) async {
    if (!_isOwner) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar de la colección'),
        content: Text(
          '¿Quitar «${item.game?.title ?? 'este juego'}» de la colección?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _repository.removeGameFromGroup(item.id);
    widget.onChanged?.call();
    await _load();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final items = List<GameGroupItem>.from(_group?.items ?? []);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    setState(() {
      _group = _group?.copyWith(items: items);
    });

    await _repository.reorderItems(
      widget.groupId,
      items.map((i) => i.id).toList(),
    );
    widget.onChanged?.call();
  }

  Future<void> _openReorderSheet() async {
    if (!_isOwner) return;
    var items = List<GameGroupItem>.from(_group?.items ?? []);
    if (items.length < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reordenar juegos',
                            style:
                                Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ),
                        IconButton(
                          icon: const CorpusTablerIcon(CorpusIconKind.Close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: items.length,
                      onReorderItem: (oldIdx, newIdx) async {
                        await _onReorder(oldIdx, newIdx);
                        setSheetState(() {
                          items = List<GameGroupItem>.from(
                            _group?.items ?? [],
                          );
                        });
                      },
                      itemBuilder: (ctx, index) {
                        final item = items[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CorpusTablerIcon(
                                CorpusIconKind.DragHandle,
                              ),
                              const SizedBox(width: 8),
                              if (_isRanked)
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _rankBadgeStyle(
                                        ctx,
                                        index + 1,
                                      ).accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            item.game?.title ?? 'Juego',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    await _load();
  }

  Future<void> _editCollection() async {
    if (!_isOwner) return;
    final group = _group;
    if (group == null) return;

    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description ?? '');
    bool isRanked = group.isRanked;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Editar colección'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Colección rankeada'),
                subtitle: const Text(
                  'Muestra número de posición (#1, #2…) en cada juego',
                  style: TextStyle(fontSize: 12),
                ),
                value: isRanked,
                onChanged: (v) => setInner(() => isRanked = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await _repository.updateGroup(
        groupId: widget.groupId,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        isRanked: isRanked,
      );
      widget.onChanged?.call();
      await _load();
      if (mounted) {
        showCorpusSnackBar(
          context,
          message: 'Colección actualizada',
          variant: CorpusSnackBarVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showCorpusSnackBar(
          context,
          message: 'No se pudieron guardar los cambios',
          variant: CorpusSnackBarVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? widget.initialName),
        actions: [
          if (_isOwner) ...[
            if ((_group?.items.length ?? 0) >= 2)
              IconButton(
                icon: const CorpusTablerIcon(CorpusIconKind.DragHandle),
                tooltip: 'Reordenar juegos',
                onPressed: _openReorderSheet,
              ),
            IconButton(
              icon: const CorpusTablerIcon(CorpusIconKind.EditOutlined),
              tooltip: 'Editar colección',
              onPressed: _editCollection,
            ),
            IconButton(
              icon: const CorpusTablerIcon(CorpusIconKind.Add),
              tooltip: 'Añadir juego',
              onPressed: _addGame,
            ),
          ],
        ],
      ),
      body: _buildBody(items),
    );
  }

  Widget _buildBody(List<GameGroupItem> items) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: CorpusEmptyState(
          icon: CorpusIconKind.ErrorOutline,
          title: _error!,
          actionLabel: 'Reintentar',
          actionIcon: CorpusIconKind.Refresh,
          onAction: _load,
        ),
      );
    }

    final allItems = _group?.items ?? [];
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isDesktop ? 40.0 : 16.0;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final description = _group?.description?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Cabecera de metadatos y descripción ───────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      allItems.length == 1
                          ? '1 juego'
                          : '${allItems.length} juegos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_isRanked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CorpusTablerIcon(
                            CorpusIconKind.EmojiEventsOutlined,
                            size: 13,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Colección rankeada',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // ── Buscador ──────────────────────────────────────────────
        if (allItems.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              8,
            ),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Buscar juego en la colección…',
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
          ),
        // ── Contenido ─────────────────────────────────────────────
        Expanded(
          child: allItems.isEmpty
              ? Center(
                  child: CorpusEmptyState(
                    icon: CorpusIconKind.VideogameAsset,
                    title: 'Colección vacía',
                    subtitle: _isOwner
                        ? 'Añade juegos a esta colección en el orden que prefieras.'
                        : 'Esta colección aún no tiene juegos.',
                    actionLabel: _isOwner ? 'Añadir juego' : null,
                    actionIcon: _isOwner ? CorpusIconKind.Add : null,
                    onAction: _isOwner ? _addGame : null,
                  ),
                )
              : items.isEmpty
                  ? Center(
                      child: CorpusEmptyState(
                        icon: CorpusIconKind.Search,
                        title: 'Sin resultados',
                        subtitle:
                            'No hay juegos que coincidan con "$_searchQuery".',
                      ),
                    )
                  : _buildGridView(items, horizontalPadding),
        ),
      ],
    );
  }

  // ── Vista mosaico (GameCards) ──────────────────────────────────────────────

  Widget _buildGridView(List<GameGroupItem> items, double horizontalPadding) {
    final allGroupItems = _group?.items ?? [];

    return ValueListenableBuilder<int>(
      valueListenable: mobileGridColumnsNotifier,
      builder: (context, columns, _) {
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            getBottomSpacer(context),
          ),
          gridDelegate: getCorpusGridDelegate(
            context,
            columns,
            desktopMaxExtent: 130.0,
            spacing: 12.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final game = item.game;
            if (game == null) return const SizedBox.shrink();

            final rawRank = allGroupItems.indexWhere((i) => i.id == item.id);
            final rankNum = rawRank >= 0 ? rawRank + 1 : index + 1;
            final rankColors = _rankBadgeStyle(context, rankNum);

            return Stack(
              fit: StackFit.expand,
              children: [
                GameCard(
                  key: ValueKey(item.id),
                  game: game,
                  isInLibrary: item.libraryStatus != null,
                  onReturn: _load,
                ),
                if (_isRanked)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: rankColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rankColors.accent,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '#$rankNum',
                          style: TextStyle(
                            color: rankColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isOwner)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _removeItem(item),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: CorpusTablerIcon(
                            CorpusIconKind.Close,
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
        );
      },
    );
  }

  ({Color background, Color accent}) _rankBadgeStyle(
    BuildContext context,
    int rankNum,
  ) {
    return switch (rankNum) {
      1 => (
        background: const Color(0xFF2B2105).withValues(alpha: 0.92),
        accent: const Color(0xFFFFD700), // Oro
      ),
      2 => (
        background: const Color(0xFF1E242B).withValues(alpha: 0.92),
        accent: const Color(0xFFD6DEE8), // Plata
      ),
      3 => (
        background: const Color(0xFF2A190B).withValues(alpha: 0.92),
        accent: const Color(0xFFE08B44), // Bronce
      ),
      _ => (
        background: Colors.black.withValues(alpha: 0.82),
        accent: Theme.of(context).colorScheme.primary,
      ),
    };
  }
}
