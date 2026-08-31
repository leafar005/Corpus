import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:corpus/globals.dart';
import '../../../services/style_pack_music_service.dart';
import '../../../theme/style_pack_registry.dart';
import '../../../widgets/design/corpus_chip.dart';
import '../../../widgets/design/corpus_section.dart';

class DesignStylePacksSection extends StatelessWidget {
  const DesignStylePacksSection({super.key});

  Future<void> _selectPack(String id) async {
    await themeNotifier.setStylePack(id);
    StylePackMusicService.instance.syncWithCurrentPack(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final activeId = themeNotifier.stylePackId;
        final cs = Theme.of(context).colorScheme;
        final packs = StylePackRegistry.selectable;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CorpusSection(
              title: 'Style packs',
              subtitle: kDebugMode
                  ? 'En debug puedes probar Persona 5 Royal sin importar el addon. También: ?style=persona5 en la URL.'
                  : 'Cambia el pack aquí, en Apariencia o importa un .corpuspack.',
              child: packs.isEmpty
                  ? Text(
                      'No hay packs disponibles.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final pack in packs)
                          CorpusChip(
                            label: StylePackRegistry.isDebugOnly(pack.id)
                                ? '${pack.name} (dev)'
                                : pack.name,
                            selected: pack.id == activeId,
                            variant: CorpusChipVariant.choice,
                            onTap: () => _selectPack(pack.id),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            CorpusSection(
              title: 'Modo de tema',
              subtitle: 'Claro, oscuro o seguir el sistema.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in ThemeMode.values)
                    CorpusChip(
                      label: _modeLabel(mode),
                      selected: themeNotifier.currentMode == mode,
                      variant: CorpusChipVariant.filter,
                      onTap: () => themeNotifier.setTheme(mode),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Pack activo: ${themeNotifier.currentPack.name}\n'
                'id: ${themeNotifier.stylePackId}\n'
                'useDynamicFrames: ${themeNotifier.currentPack.useDynamicFrames}\n'
                'navBarStyle: ${themeNotifier.currentPack.navBarStyle.name}\n'
                'debug: $kDebugMode',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
  };
}
