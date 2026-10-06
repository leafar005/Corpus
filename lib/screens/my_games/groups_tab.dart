import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import '../../models/models.dart';
import '../../utils/igdb_constants.dart';
import 'game_groups_controller.dart';
import 'group_detail_screen.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<GroupsTab> createState() => GroupsTabState();
}

class GroupsTabState extends State<GroupsTab> {
  late final GameGroupsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameGroupsController(userId: widget.userId);
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  Future<void> openCreateGroupDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    );

    if (created != true || !mounted) return;

    final group = await _controller.createGroup(
      name: nameController.text.trim(),
      description: descController.text.trim(),
    );

    if (group != null && mounted) {
      await _openGroupDetail(group);
    }
  }

  Future<void> _openGroupDetail(GameGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          userId: widget.userId,
          groupId: group.id,
          initialName: group.name,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CorpusTablerIcon(
                CorpusIconKind.ErrorOutline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(_controller.errorMessage ?? 'Error al cargar colecciones'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _controller.load,
                icon: const CorpusTablerIcon(CorpusIconKind.Refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.groups.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CorpusTablerIcon(
                  CorpusIconKind.CollectionsBookmarkOutlined,
                  size: 48,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sin colecciones todavía',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea listas para organizar sagas, backlogs por plataforma '
                  'o lo que quieras jugar después.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: openCreateGroupDialog,
                  icon: const CorpusTablerIcon(CorpusIconKind.Add),
                  label: const Text('Crear colección'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, getBottomSpacer(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = _controller.groups[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GroupCard(
                group: group,
                onTap: () => _openGroupDetail(group),
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
                    await _controller.deleteGroup(group.id);
                  }
                },
              ),
            );
          },
          childCount: _controller.groups.length,
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  final GameGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final previews = group.previewGames;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _CoverStack(previews: previews),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.description != null &&
                        group.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      group.gameCount == 1
                          ? '1 juego'
                          : '${group.gameCount} juegos',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: CorpusTablerIcon(
                  CorpusIconKind.Delete,
                  color: colorScheme.error,
                ),
                onPressed: onDelete,
                tooltip: 'Eliminar colección',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.previews});

  final List<Game> previews;

  @override
  Widget build(BuildContext context) {
    const coverW = 36.0;
    final coverH = coverW / IgdbConstants.coverAspectRatio;

    if (previews.isEmpty) {
      return Container(
        width: coverW + 12,
        height: coverH,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: CorpusTablerIcon(
            CorpusIconKind.CollectionsBookmarkOutlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final count = previews.length.clamp(1, 4);
    return SizedBox(
      width: coverW + (count - 1) * 10.0,
      height: coverH,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 10.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: coverW,
                  height: coverH,
                  child: previews[i].coverUrl != null
                      ? CorpusNetworkImage(
                          url: previews[i].coverUrl!,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
