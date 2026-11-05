import 'package:flutter/material.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

import '../../../repositories/collection_repository.dart';
import '../../../widgets/corpus_network_image.dart';
import 'platform_picker_sheet.dart';

/// Lista la biblioteca del usuario para añadir juegos a la estantería.
Future<void> showAddGameToShelfSheet({
  required BuildContext context,
  required CollectionRepository repository,
  required String userId,
  required VoidCallback onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AddGameToShelfSheet(
      repository: repository,
      userId: userId,
      onUpdated: onUpdated,
    ),
  );
}

class _AddGameToShelfSheet extends StatefulWidget {
  const _AddGameToShelfSheet({
    required this.repository,
    required this.userId,
    required this.onUpdated,
  });

  final CollectionRepository repository;
  final String userId;
  final VoidCallback onUpdated;

  @override
  State<_AddGameToShelfSheet> createState() => _AddGameToShelfSheetState();
}

class _AddGameToShelfSheetState extends State<_AddGameToShelfSheet> {
  List<LibraryGameOption>? _options;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((o) => o.game.title.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _onTapOption(LibraryGameOption option) async {
    final saved = await pickAndSavePlatforms(
      context: context,
      repository: widget.repository,
      userId: widget.userId,
      option: option,
    );
    if (saved && mounted) {
      widget.onUpdated();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
                'Añadir a la estantería',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Elige entre tus juegos terminados',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
                      hintText: 'Filtrar juegos terminados…',
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
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _options?.isEmpty == true
                              ? 'No tienes juegos terminados disponibles para añadir.'
                              : 'Sin resultados',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final option = _filtered[index];
                          return _LibraryGameTile(
                            option: option,
                            onTap: () => _onTapOption(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryGameTile extends StatelessWidget {
  const _LibraryGameTile({required this.option, required this.onTap});

  final LibraryGameOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final game = option.game;
    final coverUrl = game.coverUrl ?? '';
    final onShelf = option.ownedPlatforms.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 36,
          height: 48,
          child: coverUrl.isNotEmpty
              ? CorpusNetworkImage(url: coverUrl, fit: BoxFit.cover)
              : ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: const CorpusTablerIcon(CorpusIconKind.VideogameAsset, size: 20),
                ),
        ),
      ),
      title: Text(
        game.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: onShelf
          ? Text(
              '${option.ownedPlatforms.length} en estantería',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : option.suggestedPlatforms.isNotEmpty
          ? const Text(
              'Plataformas sugeridas disponibles',
              style: TextStyle(fontSize: 12),
            )
          : null,
      trailing: const CorpusTablerIcon(CorpusIconKind.ChevronRight),
      onTap: onTap,
    );
  }
}
