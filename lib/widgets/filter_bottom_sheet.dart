import 'package:flutter/material.dart';
import '../utils/igdb_constants.dart';

class GameFilters {
  String sortBy;
  bool sortAscending;
  List<int> genres;
  List<int> themes;
  List<int> gameModes;
  List<int> playerPerspectives;
  List<int> platforms;
  List<int> categories;

  GameFilters({
    this.sortBy = 'total_rating_count',
    this.sortAscending = false,
    this.genres = const [],
    this.themes = const [],
    this.gameModes = const [],
    this.playerPerspectives = const [],
    this.platforms = const [],
    this.categories = const [],
  });

  GameFilters copyWith({
    String? sortBy,
    bool? sortAscending,
    List<int>? genres,
    List<int>? themes,
    List<int>? gameModes,
    List<int>? playerPerspectives,
    List<int>? platforms,
    List<int>? categories,
  }) {
    return GameFilters(
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      genres: genres ?? List.from(this.genres),
      themes: themes ?? List.from(this.themes),
      gameModes: gameModes ?? List.from(this.gameModes),
      playerPerspectives:
          playerPerspectives ?? List.from(this.playerPerspectives),
      platforms: platforms ?? List.from(this.platforms),
      categories: categories ?? List.from(this.categories),
    );
  }

  bool get hasFilters =>
      genres.isNotEmpty ||
      themes.isNotEmpty ||
      gameModes.isNotEmpty ||
      playerPerspectives.isNotEmpty ||
      platforms.isNotEmpty ||
      categories.isNotEmpty;

  int get filterCount =>
      genres.length +
      themes.length +
      gameModes.length +
      playerPerspectives.length +
      platforms.length +
      categories.length;
}

class FilterBottomSheet extends StatefulWidget {
  final GameFilters initialFilters;
  final bool showSort;
  final bool isProfileMode;

  const FilterBottomSheet({
    super.key,
    required this.initialFilters,
    this.showSort = true,
    this.isProfileMode = false,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late GameFilters _filters;

  // Se incrementa solo al pulsar "Limpiar", para forzar que las secciones
  // se reconstruyan desde cero (con selección vacía). El resto del tiempo
  // las instancias de las secciones se cachean y se reutilizan tal cual,
  // así que un setState del sort/orden NO reconstruye los ~80 chips.
  int _resetKey = 0;
  late List<Widget> _filterSectionWidgets;
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.copyWith();
    _rebuildFilterSectionWidgets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contentReady = true);
    });
  }

  void _rebuildFilterSectionWidgets() {
    _filterSectionWidgets = [
      _FilterSection(
        key: ValueKey('platforms_$_resetKey'),
        title: 'Plataformas',
        items: IgdbConstants.popularPlatforms,
        initialSelected: _filters.platforms,
        onChanged: (val) => _filters.platforms = val,
        isPlatform: true,
      ),
      _FilterSection(
        key: ValueKey('genres_$_resetKey'),
        title: 'Géneros',
        items: IgdbConstants.genres,
        initialSelected: _filters.genres,
        onChanged: (val) => _filters.genres = val,
        labelFormatter: IgdbConstants.formatGenreWithEmoji,
      ),
      _FilterSection(
        key: ValueKey('themes_$_resetKey'),
        title: 'Temas',
        items: IgdbConstants.themes,
        initialSelected: _filters.themes,
        onChanged: (val) => _filters.themes = val,
        labelFormatter: IgdbConstants.formatThemeWithEmoji,
      ),
      _FilterSection(
        key: ValueKey('gameModes_$_resetKey'),
        title: 'Modos de Juego',
        items: IgdbConstants.gameModes,
        initialSelected: _filters.gameModes,
        onChanged: (val) => _filters.gameModes = val,
      ),
      _FilterSection(
        key: ValueKey('perspectives_$_resetKey'),
        title: 'Perspectiva',
        items: IgdbConstants.playerPerspectives,
        initialSelected: _filters.playerPerspectives,
        onChanged: (val) => _filters.playerPerspectives = val,
      ),
      _FilterSection(
        key: ValueKey('categories_$_resetKey'),
        title: 'Categoría',
        items: IgdbConstants.categories,
        initialSelected: _filters.categories,
        onChanged: (val) => _filters.categories = val,
      ),
    ];
  }

  void _handleClear() {
    setState(() {
      _filters = GameFilters(
        sortBy: _filters.sortBy,
        sortAscending: _filters.sortAscending,
      );
      _resetKey++;
      _rebuildFilterSectionWidgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      height: isDesktop ? null : MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _handleClear,
                  child: const Text('Limpiar'),
                ),
                const Text(
                  'Filtros',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (widget.showSort) ...[
                  const Text(
                    'Ordenar por',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _filters.sortBy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: widget.isProfileMode
                        ? const [
                            DropdownMenuItem(
                              value: 'updated_at',
                              child: Text('Fecha de Añadido'),
                            ),
                            DropdownMenuItem(
                              value: 'rating',
                              child: Text('Mi Nota'),
                            ),
                            DropdownMenuItem(
                              value: 'release_date',
                              child: Text('Fecha de Lanzamiento'),
                            ),
                            DropdownMenuItem(
                              value: 'title',
                              child: Text('Nombre'),
                            ),
                            DropdownMenuItem(
                              value: 'metacritic_score',
                              child: Text('Metacritic'),
                            ),
                          ]
                        : const [
                            DropdownMenuItem(
                              value: 'total_rating_count',
                              child: Text('Popularidad'),
                            ),
                            DropdownMenuItem(
                              value: 'first_release_date',
                              child: Text('Fecha de Lanzamiento'),
                            ),
                            DropdownMenuItem(
                              value: 'rating',
                              child: Text('Nota IGDB'),
                            ),
                            DropdownMenuItem(
                              value: 'aggregated_rating',
                              child: Text('Metacritic'),
                            ),
                            DropdownMenuItem(
                              value: 'name',
                              child: Text('Alfabético'),
                            ),
                          ],
                    // OJO: este setState solo reconstruye el Column de arriba (sort/orden).
                    // Las secciones de chips vienen de _filterSectionWidgets, que son las
                    // MISMAS instancias que antes -> Flutter las salta (identical widget).
                    onChanged: (val) {
                      if (val != null) setState(() => _filters.sortBy = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Orden:'),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              size: 16,
                              color: !_filters.sortAscending
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Descendente',
                              style: TextStyle(
                                color: !_filters.sortAscending
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        selected: !_filters.sortAscending,
                        showCheckmark: false,
                        onSelected: (val) =>
                            setState(() => _filters.sortAscending = !val),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: _filters.sortAscending
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ascendente',
                              style: TextStyle(
                                color: _filters.sortAscending
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        selected: _filters.sortAscending,
                        showCheckmark: false,
                        onSelected: (val) =>
                            setState(() => _filters.sortAscending = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                ],

                if (_contentReady) ..._filterSectionWidgets,

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de filtro aislada: tiene su propio estado de selección,
/// así que tocar un chip aquí SOLO reconstruye esta sección, no las otras 5.
/// Los labels formateados (emoji) y los estilos de plataforma se calculan
/// UNA vez en initState, no en cada build.
class _FilterSection extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<int> initialSelected;
  final ValueChanged<List<int>> onChanged;
  final String Function(String)? labelFormatter;
  final bool isPlatform;

  const _FilterSection({
    super.key,
    required this.title,
    required this.items,
    required this.initialSelected,
    required this.onChanged,
    this.labelFormatter,
    this.isPlatform = false,
  });

  @override
  State<_FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<_FilterSection> {
  late List<int> _selected;
  late final List<String> _labels;
  late final List<Widget?> _avatars;
  late final List<Color?> _brandColors;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);

    _labels = widget.items
        .map(
          (item) =>
              widget.labelFormatter?.call(item['name'] as String) ??
              item['name'] as String,
        )
        .toList();

    if (widget.isPlatform) {
      _brandColors = _labels
          .map((l) => IgdbConstants.getPlatformStyle(l)['color'] as Color?)
          .toList();
      _avatars = _labels.map((label) {
        final icon = IgdbConstants.getPlatformStyle(label)['icon'] as String?;
        if (icon == null) return null;
        return Image.asset(
          icon,
          height: 16,
          width: 16,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          cacheWidth: 32,
        );
      }).toList();
    } else {
      _brandColors = List.filled(widget.items.length, null);
      _avatars = List.filled(widget.items.length, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unselectedTextColor = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.items.length, (i) {
              final id = widget.items[i]['id'] as int;
              final isSelected = _selected.contains(id);
              final baseAvatar = _avatars[i];
              final brandColor = _brandColors[i];

              return FilterChip(
                avatar: baseAvatar,
                label: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? scheme.onPrimary : unselectedTextColor,
                  ),
                ),
                selected: isSelected,
                selectedColor: brandColor ?? scheme.primary,
                checkmarkColor: scheme.onPrimary,
                showCheckmark: false,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  });
                  widget.onChanged(_selected);
                },
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
