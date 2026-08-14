import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';
import '../../theme/corpus_typography.dart';
import 'corpus_button.dart';

enum CorpusDialogVariant { info, confirm, destructive }

/// Shows a pack-aware confirmation or info dialog.
Future<bool?> showCorpusDialog({
  required BuildContext context,
  required String title,
  String? message,
  CorpusDialogVariant variant = CorpusDialogVariant.confirm,
  String confirmLabel = 'Aceptar',
  String cancelLabel = 'Cancelar',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CorpusDialog(
      title: title,
      message: message,
      variant: variant,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class CorpusDialog extends StatelessWidget {
  final String title;
  final String? message;
  final CorpusDialogVariant variant;
  final String confirmLabel;
  final String cancelLabel;

  const CorpusDialog({
    super.key,
    required this.title,
    this.message,
    this.variant = CorpusDialogVariant.confirm,
    this.confirmLabel = 'Aceptar',
    this.cancelLabel = 'Cancelar',
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    final confirmVariant = switch (variant) {
      CorpusDialogVariant.destructive => CorpusButtonVariant.primary,
      CorpusDialogVariant.info => CorpusButtonVariant.primary,
      CorpusDialogVariant.confirm => CorpusButtonVariant.primary,
    };

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: ext.radiusLarge),
      backgroundColor: cs.surface,
      title: Text(
        title,
        style: CorpusTypography.display(
          context,
          ext,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      content: message != null
          ? Text(message!, style: TextStyle(color: cs.onSurfaceVariant))
          : null,
      actions: [
        if (variant != CorpusDialogVariant.info)
          CorpusButton(
            label: cancelLabel,
            variant: CorpusButtonVariant.ghost,
            size: CorpusButtonSize.small,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        if (variant == CorpusDialogVariant.destructive)
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: cs.copyWith(
                primary: cs.error,
                onPrimary: cs.onError,
              ),
            ),
            child: CorpusButton(
              label: confirmLabel,
              variant: confirmVariant,
              size: CorpusButtonSize.small,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          )
        else
          CorpusButton(
            label: confirmLabel,
            variant: confirmVariant,
            size: CorpusButtonSize.small,
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
    );
  }
}
