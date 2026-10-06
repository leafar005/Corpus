import 'dart:async';
import 'package:flutter/material.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/services/igdb_service.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import '../../../utils/igdb_constants.dart';

const int kGameSearchLimit = 15;
const int kMinQueryLength = 2;

/// Modal de búsqueda IGDB para elegir un juego.
Future<Game?> showGameSearchPicker(
  BuildContext context, {
  Set<int> excludeGameIds = const {},
  String title = 'Buscar juego',
  String subtitle = 'Máx. $kGameSearchLimit resultados por búsqueda',
}) {
  return showModalBottomSheet<Game>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => GameSearchPickerSheet(
      excludeGameIds: excludeGameIds,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class GameSearchPickerSheet extends StatefulWidget {
  const GameSearchPickerSheet({
    super.key,
    this.excludeGameIds = const {},
    this.title = 'Buscar juego',
    this.subtitle = 'Máx. $kGameSearchLimit resultados por búsqueda',
  });

  final Set<int> excludeGameIds;
  final String title;
  final String subtitle;

  @override
  State<GameSearchPickerSheet> createState() => _GameSearchPickerSheetState();
}

class _GameSearchPickerSheetState extends State<GameSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Game> _results = [];
  bool _isSearching = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    if (query.length < kMinQueryLength) {
      setState(() {
        _results = [];
        _error = null;
        _isSearching = false;
        _lastQuery = query;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
      _lastQuery = query;
    });

    try {
      final raw = await IGDBService.searchGames(
        query,
        limit: kGameSearchLimit,
        offset: 0,
      );
      if (!mounted) return;

      final games = raw
          .map((e) => Game.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((g) => !widget.excludeGameIds.contains(g.igdbId))
          .toList();

      setState(() {
        _results = games;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'No se pudo buscar. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Nombre del juego…',
                        prefixIcon: const CorpusTablerIcon(
                          CorpusIconKind.Search,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const CorpusTablerIcon(
                                  CorpusIconKind.Clear,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onQueryChanged('');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(scrollController)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_lastQuery.length < kMinQueryLength) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Escribe al menos $kMinQueryLength caracteres para buscar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se encontraron juegos para "$_lastQuery".',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final game = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 40,
              height: 40 / IgdbConstants.coverAspectRatio,
              child: game.coverUrl != null
                  ? CorpusNetworkImage(url: game.coverUrl!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CorpusTablerIcon(
                          CorpusIconKind.VideogameAsset,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            game.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.pop(context, game),
        );
      },
    );
  }
}
