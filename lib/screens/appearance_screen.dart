import 'package:flutter/material.dart';
import '../../globals.dart';
import 'settings/info_tab_appearance_screen.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  // Lista de colores base disponibles
  final List<Color> _availableColors = const [
    Colors.deepPurpleAccent, // Morado (Default)
    Colors.blueAccent, // Azul
    Colors.teal, // Turquesa
    Colors.green, // Verde
    Colors.amber, // Ámbar
    Colors.orange, // Naranja
    Colors.redAccent, // Rojo
    Colors.pinkAccent, // Rosa
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Apariencia'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        children: [
          const SizedBox(height: 16),
          const Text(
            'Tema de la aplicación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildThemeOptions(),
          const SizedBox(height: 32),
          const Text(
            'Color principal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige el tono que dominará los elementos visuales de Corpus.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildColorPicker(),
          const SizedBox(height: 32),
          const Text(
            'Detalles del juego',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoTabTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoTabTile() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          Icons.view_list_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          'Personalizar pestaña Información',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Orden y visibilidad de los campos'),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InfoTabAppearanceScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildThemeTile(
            title: 'Sistema',
            icon: Icons.brightness_auto,
            mode: ThemeMode.system,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeTile(
            title: 'Claro',
            icon: Icons.light_mode,
            mode: ThemeMode.light,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeTile(
            title: 'Oscuro',
            icon: Icons.dark_mode,
            mode: ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile({
    required String title,
    required IconData icon,
    required ThemeMode mode,
  }) {
    final isSelected = themeNotifier.currentMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () {
        themeNotifier.setTheme(mode);
        setState(() {}); // Actualiza la UI de esta pantalla
      },
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: _availableColors.map((color) {
        final isSelected = themeNotifier.seedColor == color;
        return GestureDetector(
          onTap: () {
            themeNotifier.setColor(color);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 30)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
