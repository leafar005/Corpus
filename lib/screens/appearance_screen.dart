import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../globals.dart';
import '../theme/style_pack.dart';
import '../theme/style_pack_registry.dart';
import 'settings/info_tab_appearance_screen.dart';
import 'settings/home_appearance_screen.dart';
import '../theme/corpus_theme_extension.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final List<Color> _availableColors = const [
    Colors.deepPurpleAccent,
    Colors.blueAccent,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.orange,
    Colors.redAccent,
    Colors.pinkAccent,
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
        padding: EdgeInsets.only(top: 8, bottom: getBottomSpacer(context), left: 16, right: 16),
        children: [
          // ── Style Pack selector ─────────────────────────────────────
          const SizedBox(height: 16),
          const Text(
            'Paquete de estilo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cambia toda la apariencia de Corpus de una vez.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildStylePackGrid(),
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            _buildImportPackButton(),
          ],

          // ── Theme mode ──────────────────────────────────────────────
          const SizedBox(height: 32),
          const Text(
            'Tema de la aplicación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildThemeOptions(),

          // ── Accent colour ───────────────────────────────────────────
          const SizedBox(height: 32),
          const Text(
            'Color principal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige el tono que dominará los elementos visuales de Corpus.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _buildColorPicker(),

          // ── Screen customisation ────────────────────────────────────
          const SizedBox(height: 32),
          const Text(
            'Personalización de pantallas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildHomeTabTile(),
          const SizedBox(height: 12),
          _buildInfoTabTile(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Style Pack grid ────────────────────────────────────────────────────

  Widget _buildStylePackGrid() {
    final packs = StylePackRegistry.all;
    final activeId = themeNotifier.stylePackId;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: packs.map((pack) {
        final isActive = pack.id == activeId;
        return GestureDetector(
          onTap: () {
            themeNotifier.setStylePack(pack.id);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pack.seedColor,
                    shape: BoxShape.circle,
                  ),
                  child: isActive
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  pack.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImportPackButton() {
    return TextButton.icon(
      onPressed: _importPack,
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('Importar paquete (.json)'),
    );
  }

  Future<void> _importPack() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final jsonStr = utf8.decode(bytes);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pack = StylePackRegistry.importFromJson(json);

      themeNotifier.setStylePack(pack.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pack "${pack.name}" importado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al importar el paquete'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ── Existing builders (unchanged logic) ────────────────────────────────

  Widget _buildHomeTabTile() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
      ),
      child: ListTile(
        leading: Icon(
          Icons.dashboard_customize_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          'Personalizar Inicio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Orden y visibilidad de las secciones'),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeAppearanceScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTabTile() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
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
        shape: RoundedRectangleBorder(borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge),
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
        borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
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
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
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
      shape: RoundedRectangleBorder(borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge),
      onTap: () {
        themeNotifier.setTheme(mode);
        setState(() {});
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
