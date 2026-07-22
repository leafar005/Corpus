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
      playerPerspectives: playerPerspectives ?? List.from(this.playerPerspectives),
      platforms: platforms ?? List.from(this.platforms),
      categories: categories ?? List.from(this.categories),
    );
  }

  bool get hasFilters => 
    genres.isNotEmpty || themes.isNotEmpty || gameModes.isNotEmpty || 
    playerPerspectives.isNotEmpty || platforms.isNotEmpty || categories.isNotEmpty;
    
  int get filterCount => 
    genres.length + themes.length + gameModes.length + 
    playerPerspectives.length + platforms.length + categories.length;
}

class FilterBottomSheet extends StatefulWidget {
  final GameFilters initialFilters;
  final bool showSort;

  const FilterBottomSheet({
    super.key,
    required this.initialFilters,
    this.showSort = true,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late GameFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.copyWith();
  }

  Widget _buildFilterSection(String title, List<Map<String, dynamic>> items, List<int> selectedItems, Function(List<int>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final id = item['id'] as int;
            final isSelected = selectedItems.contains(id);
            return FilterChip(
              label: Text(item['name'], style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade300)),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.white,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedItems.add(id);
                  } else {
                    selectedItems.remove(id);
                  }
                  onChanged(selectedItems);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  onPressed: () {
                    setState(() {
                      _filters = GameFilters(sortBy: _filters.sortBy, sortAscending: _filters.sortAscending);
                    });
                  },
                  child: const Text('Limpiar'),
                ),
                const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showSort) ...[
                    const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _filters.sortBy,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: const [
                        DropdownMenuItem(value: 'total_rating_count', child: Text('Popularidad')),
                        DropdownMenuItem(value: 'first_release_date', child: Text('Fecha de Lanzamiento')),
                        DropdownMenuItem(value: 'rating', child: Text('Nota')),
                        DropdownMenuItem(value: 'name', child: Text('Alfabético')),
                      ],
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
                          label: const Text('Descendente'),
                          selected: !_filters.sortAscending,
                          onSelected: (val) => setState(() => _filters.sortAscending = !val),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Ascendente'),
                          selected: _filters.sortAscending,
                          onSelected: (val) => setState(() => _filters.sortAscending = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                  ],

                  _buildFilterSection('Plataformas', IgdbConstants.popularPlatforms, _filters.platforms, (val) => _filters.platforms = val),
                  _buildFilterSection('Géneros', IgdbConstants.genres, _filters.genres, (val) => _filters.genres = val),
                  _buildFilterSection('Temas', IgdbConstants.themes, _filters.themes, (val) => _filters.themes = val),
                  _buildFilterSection('Modos de Juego', IgdbConstants.gameModes, _filters.gameModes, (val) => _filters.gameModes = val),
                  _buildFilterSection('Perspectiva', IgdbConstants.playerPerspectives, _filters.playerPerspectives, (val) => _filters.playerPerspectives = val),
                  _buildFilterSection('Categoría', IgdbConstants.categories, _filters.categories, (val) => _filters.categories = val),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
