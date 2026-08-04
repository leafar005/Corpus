// Fase 4 del refactor B-C2 (la más acoplada; dejar para el final).
// Cubre: portada + carrusel de fondo, título/desarrollador/fecha, botón de
// estado (biblioteca/wishlist/ratings), card de tu review / review de tu
// pareja, y lista de amigos con el juego.
//
// Origen:
//   _selectRandomScreenshot / _startCarousel  -> líneas 583-628 (estado local, timer)
//   _buildFriendsWithGame                     -> líneas 498-569
//   _buildStatusButton                        -> líneas 1664-1793
//   coverArtWidget / headerInfoWidget          -> líneas 3807-3972 (dentro de build())
//   interactiveWidget (status + reviews)       -> líneas 3973-3999

import 'dart:async';
import 'package:flutter/material.dart';

import 'game_details_controller.dart';

class GameHeroSection extends StatefulWidget {
  const GameHeroSection({
    super.key,
    required this.gameData,
    required this.controller,
    required this.isDesktop,
    this.onEditReview,
    this.onShowFriendActivity,
  });

  final Map<String, dynamic> gameData; // TODO(B-A1): GameModel
  final GameDetailsController controller;
  final bool isDesktop;
  final VoidCallback? onEditReview;
  final ValueChanged<Map<String, dynamic>>? onShowFriendActivity;

  @override
  State<GameHeroSection> createState() => _GameHeroSectionState();
}

class _GameHeroSectionState extends State<GameHeroSection> {
  // Estado puramente visual: qué screenshot se muestra de fondo. No le
  // importa a nadie fuera de este widget, por eso NO vive en el controller.
  String? _selectedScreenshotUrl;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    // TODO: portar _startCarousel(widget.gameData['screenshots']) (línea 607-628).
  }

  @override
  void didUpdateWidget(covariant GameHeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Importante (ver plan, sección 6): solo reiniciar el timer si
    // widget.gameData['screenshots'] cambió realmente, no en cada
    // notifyListeners() del controller.
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  Widget _buildBackground(BuildContext context) {
    // TODO: portar el Stack con AnimatedSwitcher + gradiente (líneas 3660-3806 aprox).
    throw UnimplementedError();
  }

  Widget _buildCoverArt(BuildContext context) {
    // TODO: portar coverArtWidget (líneas 3807-3825).
    throw UnimplementedError();
  }

  Widget _buildHeaderInfo(BuildContext context) {
    // TODO: portar headerInfoWidget (líneas 3826-3972).
    throw UnimplementedError();
  }

  Widget _buildStatusButton(BuildContext context) {
    // TODO: portar _buildStatusButton (líneas 1664-1793), usando
    // widget.controller en vez de campos del State.
    throw UnimplementedError();
  }

  Widget _buildFriendsWithGame(BuildContext context) {
    // TODO: portar _buildFriendsWithGame (líneas 498-569).
    throw UnimplementedError();
  }

  @override
  Widget build(BuildContext context) {
    // Ensambla: coverArt + headerInfo + [_buildStatusButton, GameReviewsCard]
    // + _buildFriendsWithGame. El layout desktop/mobile (Row vs Column) se
    // queda decidido por game_details_screen.dart; este widget solo entrega
    // las piezas ya construidas o recibe `isDesktop` para adaptarse.
    throw UnimplementedError();
  }
}
