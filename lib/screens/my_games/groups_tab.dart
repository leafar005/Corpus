import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/utils/igdb_constants.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/design/corpus_empty_state.dart';
import 'package:corpus/widgets/design/corpus_snackbar.dart';
import '../../models/models.dart';
import 'game_groups_controller.dart';
import 'group_detail_screen.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({
    super.key,
    required this.userId,
    this.allowCreate = false,
  });

  final String userId;
  final bool allowCreate;

  @override
  State<GroupsTab> createState() => GroupsTabState();
}

class GroupsTabState extends State<GroupsTab> {
  late final GameGroupsController _controller;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isOwner =>
      Supabase.instance.client.auth.currentUser?.id == widget.userId;

  bool get _canCreate => widget.allowCreate && _isOwner;

  @override
  void initState() {
    super.initState();
    _controller = GameGroupsController(userId: widget.userId);
    _controller.addListener(_onUpdate);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() => _controller.load();

  List<GameGroup> get _filteredGroups {
    final q = _searchQuery.trim();
    if (q.isEmpty) return _controller.groups;
    return _controller.groups.where((g) {
      return g.name.toLowerCase().contains(q) ||
          (g.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> openCreateGroupDialog() async {
    if (!_isOwner) return;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isRanked = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('Nueva colección'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Saga Souls, Backlog PS5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Colección rankeada'),
                subtitle: const Text(
                  'Los juegos tendrán un número de posición (#1, #2…)',
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
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    final group = await _controller.createGroup(
      name: nameController.text.trim(),
      description: descController.text.trim(),
      isRanked: isRanked,
    );

    if (!mounted) return;
    if (group != null) {
      await _openGroupDetail(group);
    } else {
      showCorpusSnackBar(
        context,
        message: 'No se pudo crear la colección',
        variant: CorpusSnackBarVariant.error,
      );
    }
  }

  Future<void> _openEditGroupDialog(GameGroup group) async {
    if (!_isOwner) return;
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
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
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Colección rankeada'),
                subtitle: const Text(
                  'Los juegos tendrán un número de posición (#1, #2…)',
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
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final updated = await _controller.updateGroup(
      groupId: group.id,
      name: nameController.text.trim(),
      description: descController.text.trim(),
      isRanked: isRanked,
    );

    if (!mounted) return;
    if (updated != null) {
      showCorpusSnackBar(
        context,
        message: 'Colección actualizada',
        variant: CorpusSnackBarVariant.success,
      );
    } else {
      showCorpusSnackBar(
        context,
        message: 'No se pudo actualizar la colección',
        variant: CorpusSnackBarVariant.error,
      );
    }
  }

  Future<void> _openReorderGroupsSheet() async {
    if (!_isOwner || _controller.groups.length < 2) return;
    var groups = List<GameGroup>.from(_controller.groups);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
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
                            'Reordenar colecciones',
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
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
                      itemCount: groups.length,
                      onReorderItem: (oldIdx, newIdx) async {
                        final rawNewIdx =
                            oldIdx < newIdx ? newIdx + 1 : newIdx;
                        await _controller.reorderGroups(oldIdx, rawNewIdx);
                        setSheetState(() {
                          groups = List<GameGroup>.from(_controller.groups);
                        });
                      },
                      itemBuilder: (ctx, index) {
                        final g = groups[index];
                        return ListTile(
                          key: ValueKey(g.id),
                          leading: const CorpusTablerIcon(
                            CorpusIconKind.DragHandle,
                          ),
                          title: Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            g.gameCount == 1
                                ? '1 juego'
                                : '${g.gameCount} juegos',
                            style: const TextStyle(fontSize: 12),
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
  }

  Future<void> _openGroupDetail(GameGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          userId: widget.userId,
          groupId: group.id,
          initialName: group.name,
          isRanked: group.isRanked,
          onChanged: () => _controller.load(silent: true),
        ),
      ),
    );
    if (mounted) await _controller.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_controller.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CorpusEmptyState(
            icon: CorpusIconKind.ErrorOutline,
            title: _controller.errorMessage ?? 'Error al cargar colecciones',
            actionLabel: 'Reintentar',
            actionIcon: CorpusIconKind.Refresh,
            onAction: _controller.load,
          ),
        ),
      );
    }

    if (_controller.groups.isEmpty) {
      final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
      final colorScheme = Theme.of(context).colorScheme;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CorpusEmptyState(
                icon: CorpusIconKind.CollectionsBookmarkOutlined,
                title: 'Sin colecciones todavía',
                subtitle: _canCreate
                    ? 'Crea listas para organizar sagas, tops rankeados o lo que quieras jugar después.'
                    : 'Aún no hay colecciones creadas.',
              ),
              if (_canCreate)
                OutlinedButton.icon(
                  onPressed: openCreateGroupDialog,
                  icon: const CorpusTablerIcon(CorpusIconKind.Add, size: 18),
                  label: const Text('Nueva colección'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: ext.radiusMedium,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isDesktop ? 40.0 : 16.0;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredGroups;

    return SliverMainAxisGroup(
      slivers: [
        // ── Buscador + acciones discretas con altura y esquinas unificadas ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              14,
            ),
            child: SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Buscar colección…',
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
                  if (_canCreate && _controller.groups.length >= 2) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Reordenar colecciones',
                      child: SizedBox(
                        width: 44,
                        child: Material(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: ext.radiusMedium,
                          child: InkWell(
                            borderRadius: ext.radiusMedium,
                            onTap: _openReorderGroupsSheet,
                            child: Center(
                              child: CorpusTablerIcon(
                                CorpusIconKind.DragHandle,
                                size: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_canCreate) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: ext.radiusMedium,
                      child: InkWell(
                        borderRadius: ext.radiusMedium,
                        onTap: openCreateGroupDialog,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CorpusTablerIcon(
                                CorpusIconKind.Add,
                                size: 18,
                                color: colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nueva',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // ── Mosaico de colecciones ────────────────────────────────
        if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: CorpusEmptyState(
                icon: CorpusIconKind.Search,
                title: 'Sin resultados',
                subtitle: 'No hay colecciones que coincidan con la búsqueda.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              getBottomSpacer(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isDesktop ? 240 : 200,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isDesktop ? 0.60 : 0.57,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final group = filtered[index];
                  return _GroupCard(
                    group: group,
                    isOwner: _canCreate,
                    onTap: () => _openGroupDetail(group),
                    onEdit: () => _openEditGroupDialog(group),
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminar colección'),
                          content: Text(
                            '¿Eliminar «${group.name}»? Los juegos no se borran de tu biblioteca.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final ok = await _controller.deleteGroup(group.id);
                        if (context.mounted && ok) {
                          showCorpusSnackBar(
                            context,
                            message: 'Colección eliminada',
                          );
                        }
                      }
                    },
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de colección en mosaico: cuadrícula 2×2 de portadas sin superposición
// ─────────────────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isOwner,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final GameGroup group;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final previews = group.previewGames;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Mosaico adaptativo de portadas 3:4 sin recortes ─
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: IgdbConstants.coverAspectRatio,
                    child: _CoverMosaic2x2(previews: previews),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Nombre + menú de acciones ───────────────────────
              SizedBox(
                height: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner)
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: CorpusTablerIcon(
                            CorpusIconKind.MoreVert,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Opciones',
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  CorpusTablerIcon(
                                    CorpusIconKind.EditOutlined,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  CorpusTablerIcon(
                                    CorpusIconKind.Delete,
                                    size: 18,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: colorScheme.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 16,
                child:
                    (group.description != null && group.description!.isNotEmpty)
                    ? Text(
                        group.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              // ── Pie: Cantidad de juegos + Insignia Rankeada ─────
              SizedBox(
                height: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.gameCount == 1
                            ? '1 juego'
                            : '${group.gameCount} juegos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (group.isRanked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CorpusTablerIcon(
                              CorpusIconKind.EmojiEventsOutlined,
                              size: 11,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Rankeada',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mosaico adaptativo de hasta 4 portadas 3:4 completas (sin recortes ni huecos)
// ─────────────────────────────────────────────────────────────────────────────

class _CoverMosaic2x2 extends StatelessWidget {
  const _CoverMosaic2x2({required this.previews});

  final List<Game> previews;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    if (previews.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: ext.radiusSmall,
        ),
        child: Center(
          child: CorpusTablerIcon(
            CorpusIconKind.CollectionsBookmarkOutlined,
            size: 32,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    Widget buildCoverTile(Game game, {double borderRadius = 6}) {
      final coverUrl = game.coverUrl;
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: coverUrl != null
            ? CorpusNetworkImage(
                url: coverUrl,
                fit: BoxFit.cover,
              )
            : Container(
                color: colorScheme.surfaceContainerHighest,
                child: Center(
                  child: CorpusTablerIcon(
                    CorpusIconKind.VideogameAsset,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      );
    }

    // 1 juego: portada completa 3:4 ocupando todo el marco
    if (previews.length == 1) {
      return buildCoverTile(previews[0], borderRadius: 8);
    }

    // 4+ juegos: cuadrícula 2×2 exacta donde cada celda mantiene proporción 3:4
    if (previews.length >= 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildCoverTile(previews[0])),
                const SizedBox(width: 4),
                Expanded(child: buildCoverTile(previews[1])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildCoverTile(previews[2])),
                const SizedBox(width: 4),
                Expanded(child: buildCoverTile(previews[3])),
              ],
            ),
          ),
        ],
      );
    }

    // Fondo ambiental desenfocado para composiciones de 2 y 3 juegos
    final coverUrls = previews
        .map((g) => g.coverUrl)
        .whereType<String>()
        .toList();

    Widget buildAmbientBackdrop() {
      if (coverUrls.isEmpty) {
        return ColoredBox(color: colorScheme.surfaceContainerHighest);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colorScheme.surfaceContainerHighest),
          Opacity(
            opacity: 0.35,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final url in coverUrls)
                    Expanded(
                      child: CorpusNetworkImage(
                        url: url,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 2 juegos: 2 portadas 3:4 completas centradas verticalmente sobre fondo ambiental
    if (previews.length == 2) {
      return ClipRRect(
        borderRadius: ext.radiusSmall,
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildAmbientBackdrop(),
            Center(
              child: Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: IgdbConstants.coverAspectRatio,
                      child: buildCoverTile(previews[0]),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: IgdbConstants.coverAspectRatio,
                      child: buildCoverTile(previews[1]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3 juegos: 2 portadas 3:4 arriba + 1 portada 3:4 centrada abajo sobre fondo ambiental
    return ClipRRect(
      borderRadius: ext.radiusSmall,
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildAmbientBackdrop(),
          Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCoverTile(previews[0])),
                    const SizedBox(width: 4),
                    Expanded(child: buildCoverTile(previews[1])),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: IgdbConstants.coverAspectRatio,
                    child: buildCoverTile(previews[2]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
