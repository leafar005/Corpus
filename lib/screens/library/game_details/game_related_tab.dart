// Fase 3 del refactor B-C2.
// No estaba en la propuesta original de B-C2, pero es una pestaña completa
// (~200 líneas) con su propia navegación; ver nota en el plan, sección 4.
// Origen: _buildRelatedTab -> líneas 2688-2885 (incluye gameTypeLabel local).

import 'package:flutter/material.dart';
import 'game_details_controller.dart';

class GameRelatedTab extends StatelessWidget {
  const GameRelatedTab({
    super.key,
    required this.controller,
    required this.onNavigateToGame, // reemplaza _navigateToOriginalGame
  });

  final GameDetailsController controller;
  final void Function(int id, String? name) onNavigateToGame;

  @override
  Widget build(BuildContext context) {
    // TODO: portar _buildRelatedTab (líneas 2688-2885), usando
    // controller.relatedGames / controller.isLoadingRelated, y llamando a
    // onNavigateToGame(...) en vez de _navigateToOriginalGame directo
    // (esa función necesita Navigator y se queda en game_details_screen.dart).
    throw UnimplementedError();
  }
}
