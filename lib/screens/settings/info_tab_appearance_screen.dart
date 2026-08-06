import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:corpus/globals.dart';
import '../../theme/corpus_theme_extension.dart';

class InfoTabAppearanceScreen extends StatefulWidget {
  const InfoTabAppearanceScreen({super.key});

  @override
  State<InfoTabAppearanceScreen> createState() =>
      _InfoTabAppearanceScreenState();
}

class _InfoTabAppearanceScreenState extends State<InfoTabAppearanceScreen> {
  static const List<String> defaultOrder = [
    'franchise',
    'genres_themes',
    'platforms',
    'metacritic',
    'stash_stats',
    'summary',
    'hltb',
    'engine',
  ];

  static const Map<String, String> itemLabels = {
    'franchise': 'Franquicia / Colección',
    'genres_themes': 'Géneros y temáticas',
    'platforms': 'Plataformas',
    'metacritic': 'Nota crítica',
    'stash_stats': 'Estadísticas de la comunidad',
    'summary': 'Sinopsis',
    'hltb': 'Tiempo estimado (HLTB)',
    'engine': 'Motor gráfico',
  };

  static const Map<String, IconData> itemIcons = {
    'franchise': Icons.collections_bookmark_outlined,
    'genres_themes': Icons.category_outlined,
    'platforms': Icons.devices,
    'metacritic': Icons.rate_review_outlined,
    'stash_stats': Icons.groups_outlined,
    'summary': Icons.description_outlined,
    'hltb': Icons.timer_outlined,
    'engine': Icons.memory,
  };

  List<String> _order = [];
  Set<String> _hiddenItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('info_tab_order');
    final savedHidden = prefs.getStringList('info_tab_hidden') ?? [];

    List<String> loadedOrder = [];
    if (savedOrder != null && savedOrder.isNotEmpty) {
      loadedOrder = List<String>.from(savedOrder);
      // Añadir claves nuevas por si se actualizaron en el código en su orden natural
      for (int i = 0; i < defaultOrder.length; i++) {
        final key = defaultOrder[i];
        if (!loadedOrder.contains(key)) {
          loadedOrder.insert(i.clamp(0, loadedOrder.length), key);
        }
      }
      // Eliminar claves inválidas
      loadedOrder.removeWhere((key) => !defaultOrder.contains(key));
    } else {
      loadedOrder = List<String>.from(defaultOrder);
    }

    if (mounted) {
      setState(() {
        _order = loadedOrder;
        _hiddenItems = savedHidden.toSet();
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('info_tab_order', _order);
    await prefs.setStringList('info_tab_hidden', _hiddenItems.toList());
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    _savePreferences();
  }

  void _toggleVisibility(String key, bool isVisible) {
    setState(() {
      if (isVisible) {
        _hiddenItems.remove(key);
      } else {
        _hiddenItems.add(key);
      }
    });
    _savePreferences();
  }

  void _resetToDefault() {
    setState(() {
      _order = List<String>.from(defaultOrder);
      _hiddenItems.clear();
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Personalizar pestaña Información'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restablecer por defecto',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Text(
                    'Arrastra para reordenar las secciones y usa el interruptor para ocultar o mostrar cada una en los detalles del juego.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.only(top: 8, bottom: getBottomSpacer(context), left: 16, right: 16),
                    itemCount: _order.length,
                    onReorderItem: _onReorderItem,
                    itemBuilder: (context, index) {
                      final key = _order[index];
                      final isVisible = !_hiddenItems.contains(key);
                      final label = itemLabels[key] ?? key;
                      final icon = itemIcons[key] ?? Icons.info_outline;

                      return Container(
                        key: ValueKey(key),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusMedium,
                          border: Border.all(
                            color: isVisible
                                ? Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            icon,
                            color: isVisible
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: isVisible
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isVisible
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isVisible,
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (value) =>
                                    _toggleVisibility(key, value),
                              ),
                              const SizedBox(width: 8),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
