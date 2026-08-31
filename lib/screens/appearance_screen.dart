import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../services/style_pack_import_service.dart';
import '../services/style_pack_music_service.dart';
import '../theme/style_pack_registry.dart';
import '../theme/corpus_theme_extension.dart';
import '../theme/style_pack.dart';
import '../widgets/corpus_section_title.dart';

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
        title: const CorpusScreenTitle('Apariencia'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: getBottomSpacer(context),
          left: 16,
          right: 16,
        ),
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildStylePackSection(),
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  // ── Style Pack section ─────────────────────────────────────────────────

  Widget _buildStylePackSection() {
    final imported = StylePackRegistry.imported;
    final activeId = themeNotifier.stylePackId;
    final isClassicActive = activeId == 'default';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPackTile(
          pack: StylePack.defaultPack(),
          isActive: isClassicActive,
          isImported: false,
        ),
        if (kDebugMode) ...[
          for (final pack in StylePackRegistry.debugBuiltIn) ...[
            const SizedBox(height: 12),
            _buildPackTile(
              pack: pack,
              isActive: pack.id == activeId,
              isImported: false,
            ),
          ],
        ],
        if (imported.isEmpty && !kDebugMode) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: Theme.of(
                context,
              ).extension<CorpusThemeExtension>()!.radiusLarge,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.extension_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay addons instalados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kIsWeb
                      ? 'Los paquetes de estilo se importan desde la app móvil o de escritorio.'
                      : 'Importa un archivo .corpuspack para añadir temas como Persona 5 Royal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          ...imported.map((entry) {
            final pack = entry.pack;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPackTile(
                pack: pack,
                isActive: pack.id == activeId,
                isImported: true,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPackTile({
    required StylePack pack,
    required bool isActive,
    required bool isImported,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusLarge,
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
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
        title: Text(
          pack.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          isImported
              ? (pack.description ?? 'Addon importado')
              : StylePackRegistry.isDebugOnly(pack.id)
              ? 'Preview de desarrollo (solo debug)'
              : 'Tema predeterminado de Corpus',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isImported
            ? IconButton(
                tooltip: 'Eliminar addon',
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _confirmRemovePack(pack),
              )
            : (isActive
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null),
        onTap: () async {
          await themeNotifier.setStylePack(pack.id);
          StylePackMusicService.instance.syncWithCurrentPack(force: true);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _confirmRemovePack(StylePack pack) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar "${pack.name}"?'),
        content: const Text(
          'Se quitará el addon de este dispositivo. Podrás volver a importarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;

    final wasActive = themeNotifier.stylePackId == pack.id;
    await StylePackRegistry.removeImported(pack.id);
    if (wasActive) {
      await themeNotifier.setStylePack('default');
      StylePackMusicService.instance.syncWithCurrentPack(force: true);
    }
    if (mounted) setState(() {});
  }

  Widget _buildImportPackButton() {
    return FilledButton.icon(
      onPressed: _importPack,
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('Importar addon (.corpuspack)'),
    );
  }

  Future<void> _importPack() async {
    try {
      final result = await StylePackImportService.pickAndImport();
      if (result == null) return;

      await themeNotifier.setStylePack(result.pack.id);
      StylePackMusicService.instance.syncWithCurrentPack(force: true);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isBundle
                  ? 'Addon "${result.pack.name}" instalado'
                  : 'Pack "${result.pack.name}" importado',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
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
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusLarge,
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
        shape: RoundedRectangleBorder(
          borderRadius: Theme.of(
            context,
          ).extension<CorpusThemeExtension>()!.radiusLarge,
        ),
        onTap: () {
          context.pushHomeAppearance();
        },
      ),
    );
  }

  Widget _buildInfoTabTile() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusLarge,
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
        shape: RoundedRectangleBorder(
          borderRadius: Theme.of(
            context,
          ).extension<CorpusThemeExtension>()!.radiusLarge,
        ),
        onTap: () {
          context.pushInfoTabAppearance();
        },
      ),
    );
  }

  Widget _buildThemeOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusLarge,
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
      shape: RoundedRectangleBorder(
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusLarge,
      ),
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
