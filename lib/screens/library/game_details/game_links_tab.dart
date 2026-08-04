// Fase 3 del refactor B-C2.
// Tampoco estaba en la propuesta original; ver nota en el plan, sección 4.
// Origen: _buildLinksTab -> líneas 2886-3133 (incluye getCategory,
// isConsoleStore, buildLinkSection, extractDomain, todos locales).

import 'package:flutter/material.dart';

class GameLinksTab extends StatelessWidget {
  const GameLinksTab({
    super.key,
    required this.websitesList,
    required this.localizeLinks,
  });

  final List websitesList;
  final bool localizeLinks; // controller.localizeLinks

  @override
  Widget build(BuildContext context) {
    // TODO: portar _buildLinksTab (líneas 2886-3133). Usa
    // game_details_formatters.localizeUrlToSpain() para reemplazar
    // _localizeUrlToSpain.
    throw UnimplementedError();
  }
}
