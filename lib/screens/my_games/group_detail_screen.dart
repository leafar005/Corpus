import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import '../../models/models.dart';
import '../../repositories/game_group_repository.dart';
import '../../utils/igdb_constants.dart';
import 'widgets/game_search_picker_sheet.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.userId,
    required this.groupId,
    required this.initialName,
    this.onChanged,
  });

  final String userId;
  final String groupId;
  final String initialName;
  final VoidCallback? onChanged;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _repository = GameGroupRepository();

  GameGroup? _group;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
        if (group == null) _error = 'Grupo no encontrado';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el grupo';
      });
    }
  }

  Future<void> _addGame() async {
    final excludeIds = (_group?.items ?? [])
        .map((i) => i.gameId)
        .toSet();

    final game = await showGameSearchPicker(
      context,
      excludeGameIds: excludeIds,
      title: 'Añadir al grupo',
      subtitle: 'Busca un juego (máx. $kGameSearchLimit resultados)',
    );

    if (game == null) return;

    try {
      await _repository.addGameToGroup(
        groupId: widget.groupId,
        game: game,
      );
      widget.onChanged?.call();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${game.title}» añadido')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo añadir el juego (¿ya está en el grupo?)'),
          ),
        );
      }
    }
  }

  Future<void> _removeItem(GameGroupItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del grupo'),
        content: Text(
          '¿Quitar «${item.game?.title ?? 'este juego'}» del grupo?',
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
    if (oldIndex < newIndex) newIndex -= 1;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? widget.initialName),
        actions: [
          IconButton(
            icon: const CorpusTablerIcon(CorpusIconKind.Add),
            tooltip: 'Añadir juego',
            onPressed: _addGame,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: getBottomSpacer(context) - 72),
        child: FloatingActionButton.extended(
          onPressed: _addGame,
          icon: const CorpusTablerIcon(CorpusIconKind.Add),
          label: const Text('Añadir juego'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final group = _group!;
    final items = group.items;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CorpusTablerIcon(
                CorpusIconKind.VideogameAsset,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Grupo vacío',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Añade juegos en el orden que quieras jugarlos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: items.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        return _GroupGameTile(
          key: ValueKey(item.id),
          listIndex: index,
          displayIndex: index + 1,
          item: item,
          onTap: () {
            final game = item.game;
            if (game != null) context.pushGameDetails(game);
          },
          onRemove: () => _removeItem(item),
        );
      },
    );
  }
}

class _GroupGameTile extends StatelessWidget {
  const _GroupGameTile({
    super.key,
    required this.listIndex,
    required this.displayIndex,
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final int listIndex;
  final int displayIndex;
  final GameGroupItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final game = item.game;
    final colorScheme = Theme.of(context).colorScheme;
    final status = item.libraryStatus;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: listIndex,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CorpusTablerIcon(
                  CorpusIconKind.DragHandle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$displayIndex',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 40,
                height: 40 / IgdbConstants.coverAspectRatio,
                child: game?.coverUrl != null
                    ? CorpusNetworkImage(
                        url: game!.coverUrl!,
                        fit: BoxFit.cover,
                      )
                    : ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                      ),
              ),
            ),
          ],
        ),
        title: Text(
          game?.title ?? 'Juego',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: status != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _StatusChip(status: status),
              )
            : item.note != null
            ? Text(item.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: IconButton(
          icon: CorpusTablerIcon(
            CorpusIconKind.Delete,
            color: colorScheme.error,
          ),
          onPressed: onRemove,
          tooltip: 'Quitar del grupo',
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.shortLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.color(context),
        ),
      ),
    );
  }
}
