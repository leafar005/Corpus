import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/models/models.dart';
import 'package:corpus/theme/corpus_theme_extension.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_network_image.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import '../../../utils/igdb_constants.dart';

/// Modal para elegir un juego de los juegos terminados del usuario.
Future<Game?> showGameSearchPicker(
  BuildContext context, {
  Set<int> excludeGameIds = const {},
  String title = 'Añadir a la colección',
  String subtitle = 'Elige entre tus juegos terminados',
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
    this.title = 'Añadir a la colección',
    this.subtitle = 'Elige entre tus juegos terminados',
  });

  final Set<int> excludeGameIds;
  final String title;
  final String subtitle;

  @override
  State<GameSearchPickerSheet> createState() => _GameSearchPickerSheetState();
}

class _GameSearchPickerSheetState extends State<GameSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<Game> _beatenGames = [];
  Map<int, double> _ratingsByGameId = {};
  bool _isLoading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadBeatenGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBeatenGames() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Inicia sesión para ver tus juegos terminados.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('user_games')
          .select('rating, status, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'beaten')
          .order('updated_at', ascending: false);

      if (!mounted) return;

      final list = <Game>[];
      final ratings = <int, double>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final gameRaw = map['games'];
        if (gameRaw == null) continue;
        final gameMap = Map<String, dynamic>.from(gameRaw as Map);
        final game = Game.fromMap(gameMap);
        final rating = (map['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          ratings[game.igdbId] = rating;
        }
        if (!widget.excludeGameIds.contains(game.igdbId)) {
          list.add(game);
        }
      }

      setState(() {
        _beatenGames = list;
        _ratingsByGameId = ratings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudieron cargar tus juegos terminados.';
      });
    }
  }

  List<Game> get _filteredGames {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _beatenGames;
    return _beatenGames
        .where((g) => g.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final searchBorder = OutlineInputBorder(
      borderRadius: ext.radiusMedium,
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
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
                      decoration: InputDecoration(
                        hintText: 'Filtrar juegos terminados…',
                        prefixIcon: const CorpusTablerIcon(
                          CorpusIconKind.Search,
                          size: 20,
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const CorpusTablerIcon(
                                  CorpusIconKind.Clear,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
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
                      onChanged: (val) => setState(() => _query = val),
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
    if (_isLoading) {
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

    if (_beatenGames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No tienes juegos terminados disponibles para añadir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final filtered = _filteredGames;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ningún juego terminado coincide con "$_query".',
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final game = filtered[index];
        final rating = _ratingsByGameId[game.igdbId];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
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
          trailing: (rating != null && rating > 0)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CorpusTablerIcon(
                      CorpusIconKind.StarRounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(
                        rating.truncateToDouble() == rating ? 0 : 1,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () => Navigator.pop(context, game),
        );
      },
    );
  }
}
