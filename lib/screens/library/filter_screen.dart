import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/models/models.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../utils/igdb_constants.dart';
import '../../widgets/corpus_section_title.dart';
import 'filter_option_screen.dart';

/// Pantalla completa de filtros de biblioteca/búsqueda, inspirada en el
/// flujo "categoría → lista dedicada" de Stash, adaptada a la estética de
/// Corpus (colores y tipografía siempre vía tema, nunca hardcodeados, para
/// que funcione igual con cualquier `StylePack`).
///
/// Sustituye a `FilterBottomSheet`. Se navega con `Navigator.push` y se
/// espera un `GameFilters?` de vuelta:
/// - `null` → el usuario canceló (atrás), no se aplican cambios.
/// - `GameFilters` → el usuario pulsó "Aplicar", hay que refrescar la
///   búsqueda/listado con el nuevo filtro.
class FilterScreen extends StatefulWidget {
  final GameFilters initialFilters;
  final bool showSort;
  final bool isProfileMode;

  const FilterScreen({
    super.key,
    required this.initialFilters,
    this.showSort = true,
    this.isProfileMode = false,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late GameFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  // ── Opciones de orden ──────────────────────────────────────────────────
  // Mismos value/label que tenía el DropdownButtonFormField original.

  static const List<({String value, String label})> _searchSortOptions = [
    (value: 'total_rating_count', label: 'Popularidad'),
    (value: 'first_release_date', label: 'Fecha de Lanzamiento'),
    (value: 'name', label: 'Alfabético'),
  ];

  static const List<({String value, String label})> _profileSortOptions = [
    (value: 'last_played_at', label: 'Fecha Jugado'),
    (value: 'rating', label: 'Mi Nota'),
    (value: 'release_date', label: 'Fecha de Lanzamiento'),
    (value: 'title', label: 'Nombre'),
    (value: 'metacritic_score', label: 'Metacritic'),
  ];

  // ── Categorías filtrables ────────────────────────────────────────────
  // `static final` a propósito: se construye UNA vez para toda la app (las
  // listas de IgdbConstants son const), no cada vez que se abre la pantalla.

  static final List<_FilterCategoryConfig> _categories = [
    _FilterCategoryConfig(
      title: 'Plataformas',
      items: IgdbConstants.popularPlatforms,
      selected: (f) => f.platforms,
      apply: (f, ids) => f.copyWith(platforms: ids),
      isPlatform: true,
    ),
    _FilterCategoryConfig(
      title: 'Géneros',
      items: IgdbConstants.genres,
      selected: (f) => f.genres,
      apply: (f, ids) => f.copyWith(genres: ids),
      labelFormatter: IgdbConstants.formatGenreWithEmoji,
    ),
    _FilterCategoryConfig(
      title: 'Temas',
      items: IgdbConstants.themes,
      selected: (f) => f.themes,
      apply: (f, ids) => f.copyWith(themes: ids),
      labelFormatter: IgdbConstants.formatThemeWithEmoji,
    ),
    _FilterCategoryConfig(
      title: 'Modos de Juego',
      items: IgdbConstants.gameModes,
      selected: (f) => f.gameModes,
      apply: (f, ids) => f.copyWith(gameModes: ids),
    ),
    _FilterCategoryConfig(
      title: 'Perspectiva',
      items: IgdbConstants.playerPerspectives,
      selected: (f) => f.playerPerspectives,
      apply: (f, ids) => f.copyWith(playerPerspectives: ids),
    ),
    _FilterCategoryConfig(
      title: 'Categoría',
      items: IgdbConstants.categories,
      selected: (f) => f.categories,
      apply: (f, ids) => f.copyWith(categories: ids),
    ),
  ];

  void _clearAll() {
    setState(() => _filters = _filters.clearSelections());
  }

  Future<void> _openCategory(_FilterCategoryConfig config) async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterOptionScreen(
          title: config.title,
          items: config.items,
          initialSelected: config.selected(_filters),
          labelFormatter: config.labelFormatter,
          isPlatform: config.isPlatform,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _filters = config.apply(_filters, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final sortOptions = widget.isProfileMode
        ? _profileSortOptions
        : _searchSortOptions;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const CorpusScreenTitle('Filtros'),
        actions: [
          TextButton(
            onPressed: _filters.hasFilters ? _clearAll : null,
            child: const Text('Borrar'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _filters),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
              ),
              child: const Text('Aplicar'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, getBottomSpacer(context)),
        children: [
          if (widget.showSort) ...[
            const _SectionLabel('Ordenar por'),
            const SizedBox(height: 8),
            _SortChipsRow(
              options: sortOptions,
              selected: _filters.sortBy,
              onSelected: (value) =>
                  setState(() => _filters = _filters.copyWith(sortBy: value)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.arrow_downward, size: 18),
                    label: Text('Descendente'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.arrow_upward, size: 18),
                    label: Text('Ascendente'),
                  ),
                ],
                selected: {_filters.sortAscending},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(
                  () => _filters = _filters.copyWith(
                    sortAscending: selection.first,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 4),
          ],
          const _SectionLabel('Filtrado por'),
          ..._categories.map(
            (config) => _FilterCategoryRow(
              title: config.title,
              valueLabel: _labelForSelection(
                config.selected(_filters),
                config.items,
                config.labelFormatter,
              ),
              onTap: () => _openCategory(config),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto a mostrar en la fila de una categoría:
/// - "Todos" si no hay selección.
/// - El nombre formateado si hay solo un elemento seleccionado.
/// - "N seleccionados" si hay varios.
String _labelForSelection(
  List<int> selectedIds,
  List<Map<String, dynamic>> items,
  String Function(String)? formatter,
) {
  if (selectedIds.isEmpty) return 'Todos';
  if (selectedIds.length == 1) {
    final matches = items.where((e) => e['id'] == selectedIds.first);
    if (matches.isEmpty) return 'Todos';
    final name = matches.first['name'] as String;
    return formatter?.call(name) ?? name;
  }
  return '${selectedIds.length} seleccionados';
}

/// Describe una categoría filtrable: de dónde salen sus opciones, cómo leer
/// la selección actual desde un `GameFilters` y cómo escribir la nueva.
class _FilterCategoryConfig {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<int> Function(GameFilters filters) selected;
  final GameFilters Function(GameFilters filters, List<int> newIds) apply;
  final String Function(String)? labelFormatter;
  final bool isPlatform;

  const _FilterCategoryConfig({
    required this.title,
    required this.items,
    required this.selected,
    required this.apply,
    this.labelFormatter,
    this.isPlatform = false,
  });
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SortChipsRow extends StatelessWidget {
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SortChipsRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(opt.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Fila de una categoría en la pantalla principal de filtros: título a la
/// izquierda, valor actual + chevron a la derecha, separador fino debajo
/// (igual que las filas "Género / Todos" de la referencia de Stash, pero
/// sin caja/tarjeta — lista plana).
class _FilterCategoryRow extends StatelessWidget {
  final String title;
  final String valueLabel;
  final VoidCallback onTap;

  const _FilterCategoryRow({
    required this.title,
    required this.valueLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          onTap: onTap,
        ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }
}
