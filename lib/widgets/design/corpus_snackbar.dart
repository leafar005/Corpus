import 'package:flutter/material.dart';

import '../../theme/corpus_theme_extension.dart';

enum CorpusSnackBarVariant { info, success, error }

/// Shows a themed snackbar message.
void showCorpusSnackBar(
  BuildContext context, {
  required String message,
  CorpusSnackBarVariant variant = CorpusSnackBarVariant.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final cs = Theme.of(context).colorScheme;
  final ext = Theme.of(context).extension<CorpusThemeExtension>()!;

  final (bg, fg) = switch (variant) {
    CorpusSnackBarVariant.success => (const Color(0xFF2E7D32), Colors.white),
    CorpusSnackBarVariant.error => (cs.error, cs.onError),
    CorpusSnackBarVariant.info => (cs.inverseSurface, cs.onInverseSurface),
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: fg)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: ext.radiusMedium),
      duration: duration,
    ),
  );
}
