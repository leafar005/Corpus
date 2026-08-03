import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeAppearanceScreen extends StatefulWidget {
  const HomeAppearanceScreen({super.key});

  @override
  State<HomeAppearanceScreen> createState() => _HomeAppearanceScreenState();
}

class _HomeAppearanceScreenState extends State<HomeAppearanceScreen> {
  static const List<String> defaultOrder = [
    'hero',
    'stash_activity',
    'wishlist_anticipated',
    'anticipated_games',
  ];

  static const Map<String, String> itemLabels = {
    'hero': 'Destacados / Jugando Actualmente',
    'stash_activity': 'Actividad global de Stash',
    'wishlist_anticipated': 'Próximos en tu Wishlist',
    'anticipated_games': 'Más Anticipados',
  };

  static const Map<String, IconData> itemIcons = {
    'hero': Icons.view_carousel_outlined,
    'stash_activity': Icons.public_outlined,
    'wishlist_anticipated': Icons.favorite_border,
    'anticipated_games': Icons.event_available_outlined,
  };

  List<String> _order = [];
  Set<String> _hiddenItems = {};
  String _countdownStyle = 'full';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('home_sections_order');
    final savedHidden = prefs.getStringList('home_sections_hidden') ?? [];
    final savedCountdownStyle =
        prefs.getString('anticipated_countdown_style') ?? 'full';

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
        _countdownStyle = savedCountdownStyle;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('home_sections_order', _order);
    await prefs.setStringList('home_sections_hidden', _hiddenItems.toList());
    await prefs.setString('anticipated_countdown_style', _countdownStyle);
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

  Future<void> _showCountdownStyleDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Formato de Cuenta Atrás'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: const Text('Completa (Días, Horas, Minutos)'),
                value: 'full',
                // ignore: deprecated_member_use
                groupValue: _countdownStyle,
                // ignore: deprecated_member_use
                onChanged: (value) => Navigator.pop(context, value),
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: const Text('Solo días totales'),
                value: 'days_only',
                // ignore: deprecated_member_use
                groupValue: _countdownStyle,
                // ignore: deprecated_member_use
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result != _countdownStyle && mounted) {
      setState(() {
        _countdownStyle = result;
      });
      _savePreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Inicio'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Mantén pulsado y arrastra para reordenar las secciones en la pantalla de inicio. También puedes ocultarlas usando los interruptores.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onReorderItem: (oldIndex, newIndex) {
                _onReorderItem(oldIndex, newIndex);
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      elevation: 8,
                      child: child,
                    );
                  },
              children: [
                for (final key in _order)
                  Container(
                    key: ValueKey(key),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        itemIcons[key],
                        color: _hiddenItems.contains(key)
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        itemLabels[key] ?? key,
                        style: TextStyle(
                          color: _hiddenItems.contains(key)
                              ? Colors.grey
                              : null,
                          decoration: _hiddenItems.contains(key)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (key == 'anticipated_games' ||
                              key == 'wishlist_anticipated')
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              onPressed: _showCountdownStyleDialog,
                            ),
                          Switch(
                            value: !_hiddenItems.contains(key),
                            onChanged: (val) => _toggleVisibility(key, val),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.drag_handle,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
