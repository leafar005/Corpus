import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../utils/igdb_constants.dart';

/// Pantalla de selección múltiple para una sola categoría de filtro.
///
/// Reutilizable: la instancia `FilterScreen` para las 6 categorías
/// (Plataformas, Géneros, Temas, Modos de Juego, Perspectiva, Categoría).
class FilterOptionScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<int> initialSelected;
  final String Function(String)? labelFormatter;
  final bool isPlatform;

  const FilterOptionScreen({
    super.key,
    required this.title,
    required this.items,
    required this.initialSelected,
    this.labelFormatter,
    this.isPlatform = false,
  });

  @override
  State<FilterOptionScreen> createState() => _FilterOptionScreenState();
}

class _FilterOptionScreenState extends State<FilterOptionScreen> {
  late Set<int> _selected;

  // Precalculados UNA vez en initState (igual que hacía _FilterSectionState
  // en el bottom sheet original): formateo de emoji y estilo de plataforma
  // no se recalculan en cada build/tap.
  late final List<String> _labels;
  late final List<Color?> _brandColors;
  
  // Lista aplanada que contiene Strings (Headers) o ints (índices de widget.items)
  late final List<dynamic> _flatItems;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initialSelected);

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

      final Map<String, List<int>> groups = {
        'PlayStation': [],
        'Xbox': [],
        'Nintendo': [],
        'Sega': [],
        'PC & Mac': [],
        'Móviles': [],
        'Otros': [],
      };
      
      for (var i = 0; i < _labels.length; i++) {
        final label = _labels[i];
        if (label.contains('PlayStation')) groups['PlayStation']!.add(i);
        else if (label.contains('Xbox')) groups['Xbox']!.add(i);
        else if (label.contains('Nintendo') || label.contains('Wii') || label.contains('Game Boy') || label.contains('DS')) groups['Nintendo']!.add(i);
        else if (label.contains('Sega') || label.contains('Dreamcast')) groups['Sega']!.add(i);
        else if (label.contains('PC') || label.contains('Mac') || label.contains('Linux')) groups['PC & Mac']!.add(i);
        else if (label.contains('Android') || label.contains('iOS')) groups['Móviles']!.add(i);
        else groups['Otros']!.add(i);
      }

      _flatItems = [];
      for (final entry in groups.entries) {
        if (entry.value.isNotEmpty) {
          _flatItems.add(entry.key);
          _flatItems.addAll(entry.value);
        }
      }
    } else {
      _brandColors = List.filled(widget.items.length, null);
      _flatItems = List.generate(widget.items.length, (i) => i);
    }
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _selected.isNotEmpty
                ? () => setState(_selected.clear)
                : null,
            child: const Text('Borrar'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
              ),
              child: Text(
                _selected.isEmpty ? 'Aplicar' : 'Aplicar (${_selected.length})',
              ),
            ),
          ),
        ],
      ),
      // ListView.builder = perezoso: solo construye las filas visibles,
      // a diferencia del Wrap de FilterChip anterior (creaba TODOS los
      // chips de la categoría de golpe, aunque no fueran visibles).
      body: ListView.builder(
        padding: EdgeInsets.only(bottom: getBottomSpacer(context)),
        itemCount: _flatItems.length,
        itemBuilder: (context, idx) {
          final dynamic flatItem = _flatItems[idx];
          
          if (flatItem is String) {
            final iconPath = IgdbConstants.getPlatformStyle(flatItem)['icon'] as String?;
            
            return Padding(
              padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
              child: Row(
                children: [
                  if (flatItem == 'PC & Mac') ...[
                    Icon(
                      Icons.computer,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ] else if (iconPath != null) ...[
                    Image.asset(
                      iconPath,
                      height: 18,
                      width: 18,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    flatItem.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final int index = flatItem as int;
          final id = widget.items[index]['id'] as int;
          final isSelected = _selected.contains(id);
          final brandColor = _brandColors[index];

          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggle(id),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: brandColor ?? scheme.primary,
            title: Text(
              _labels[index],
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}
