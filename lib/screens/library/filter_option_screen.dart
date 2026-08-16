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
  late final List<Widget?> _avatars;

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
      _avatars = _labels.map((label) {
        final icon = IgdbConstants.getPlatformStyle(label)['icon'] as String?;
        if (icon == null) return null;
        return Image.asset(
          icon,
          height: 22,
          width: 22,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          cacheWidth: 44,
        );
      }).toList();
    } else {
      _brandColors = List.filled(widget.items.length, null);
      _avatars = List.filled(widget.items.length, null);
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
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final id = widget.items[index]['id'] as int;
          final isSelected = _selected.contains(id);
          final brandColor = _brandColors[index];

          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggle(id),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: brandColor ?? scheme.primary,
            secondary: _avatars[index],
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
