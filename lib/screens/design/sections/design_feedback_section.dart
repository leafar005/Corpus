import 'package:flutter/material.dart';

import '../../../widgets/design/corpus_button.dart';
import '../../../widgets/design/corpus_dialog.dart';
import '../../../widgets/design/corpus_empty_state.dart';
import '../../../widgets/design/corpus_loading.dart';
import '../../../widgets/design/corpus_section.dart';
import '../../../widgets/design/corpus_snackbar.dart';

class DesignFeedbackSection extends StatelessWidget {
  const DesignFeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CorpusSection(
          title: 'Snackbars',
          subtitle: 'Info, éxito y error.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CorpusButton(
                label: 'Info',
                size: CorpusButtonSize.small,
                variant: CorpusButtonVariant.secondary,
                onPressed: () => showCorpusSnackBar(
                  context,
                  message: 'Cambios guardados en borrador',
                ),
              ),
              CorpusButton(
                label: 'Éxito',
                size: CorpusButtonSize.small,
                variant: CorpusButtonVariant.accent,
                onPressed: () => showCorpusSnackBar(
                  context,
                  message: 'Reseña publicada',
                  variant: CorpusSnackBarVariant.success,
                ),
              ),
              CorpusButton(
                label: 'Error',
                size: CorpusButtonSize.small,
                variant: CorpusButtonVariant.outline,
                onPressed: () => showCorpusSnackBar(
                  context,
                  message: 'No se pudo guardar',
                  variant: CorpusSnackBarVariant.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Diálogos',
          subtitle: 'Confirmación, info y destructivo.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CorpusButton(
                label: 'Confirmar',
                size: CorpusButtonSize.small,
                onPressed: () => showCorpusDialog(
                  context: context,
                  title: '¿Eliminar reseña?',
                  message: 'Esta acción no se puede deshacer.',
                ),
              ),
              CorpusButton(
                label: 'Info',
                size: CorpusButtonSize.small,
                variant: CorpusButtonVariant.secondary,
                onPressed: () => showCorpusDialog(
                  context: context,
                  title: 'Sincronización',
                  message: 'Tu biblioteca se actualizará en segundo plano.',
                  variant: CorpusDialogVariant.info,
                  confirmLabel: 'Entendido',
                ),
              ),
              CorpusButton(
                label: 'Destructivo',
                size: CorpusButtonSize.small,
                variant: CorpusButtonVariant.outline,
                onPressed: () => showCorpusDialog(
                  context: context,
                  title: 'Eliminar juego',
                  message: 'Se quitará de tu biblioteca permanentemente.',
                  variant: CorpusDialogVariant.destructive,
                  confirmLabel: 'Eliminar',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const CorpusSection(
          title: 'Loading',
          subtitle: 'Indicador inline.',
          child: CorpusLoadingIndicator(label: 'Cargando biblioteca…'),
        ),
        const SizedBox(height: 32),
        CorpusSection(
          title: 'Empty state',
          subtitle: 'Listas vacías y zonas sin contenido.',
          child: CorpusEmptyState(
            icon: Icons.videogame_asset_outlined,
            title: 'Tu biblioteca está vacía',
            subtitle: 'Añade juegos desde la búsqueda o importa desde Steam.',
            actionLabel: 'Buscar juegos',
            actionIcon: Icons.search,
            onAction: () {},
          ),
        ),
      ],
    );
  }
}
