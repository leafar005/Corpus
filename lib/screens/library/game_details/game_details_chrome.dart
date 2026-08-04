// Fase 4 del refactor B-C2.
// Piezas de "chrome" reutilizadas por game_details_screen.dart:
// los SliverPersistentHeaderDelegate y los botones de la barra de tabs.
//
// Origen:
//   _buildTabButton               -> líneas 2556-2587
//   _buildNavBar                  -> líneas 2588-2628
//   _GameDetailsHeaderDelegate    -> líneas 4294-4369
//   _GameDetailsTabBarDelegate    -> líneas 4370-4385

import 'package:flutter/material.dart';

class GameDetailsTabBarButton extends StatelessWidget {
  const GameDetailsTabBarButton({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // TODO: portar cuerpo de _buildTabButton (líneas 2556-2587).
    throw UnimplementedError();
  }
}

class GameDetailsNavBar extends StatelessWidget {
  const GameDetailsNavBar({
    super.key,
    required this.isDesktop,
    required this.selectedIndex,
    required this.onSelect,
    required this.infoTabIdx,
    required this.communityTabIdx,
    required this.mediaTabIdx,
    required this.relatedTabIdx,
    required this.linksTabIdx,
    required this.hasMedia,
    required this.hasRelated,
    required this.hasLinks,
  });

  final bool isDesktop;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final int infoTabIdx;
  final int communityTabIdx;
  final int mediaTabIdx;
  final int relatedTabIdx;
  final int linksTabIdx;
  final bool hasMedia;
  final bool hasRelated;
  final bool hasLinks;

  @override
  Widget build(BuildContext context) {
    // TODO: portar cuerpo de _buildNavBar (líneas 2588-2628), reemplazando
    // las llamadas a setState(_selectedMainTabIndex = i) por onSelect(i).
    throw UnimplementedError();
  }
}

class GameDetailsHeaderDelegate extends SliverPersistentHeaderDelegate {
  GameDetailsHeaderDelegate({
    required this.topPadding,
    required this.background,
    required this.leading,
    required this.title,
    required this.backgroundColor,
  });

  final double topPadding;
  final Widget background;
  final Widget leading;
  final String title;
  final Color backgroundColor;

  @override
  double get minExtent => 56.0 + topPadding;

  @override
  double get maxExtent => 250.0 + topPadding;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // TODO: portar cuerpo exacto (líneas 4294-4348).
    throw UnimplementedError();
  }

  @override
  bool shouldRebuild(covariant GameDetailsHeaderDelegate oldDelegate) {
    // TODO: portar (línea 4349-4369).
    throw UnimplementedError();
  }
}

class GameDetailsTabBarDelegate extends SliverPersistentHeaderDelegate {
  GameDetailsTabBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant GameDetailsTabBarDelegate oldDelegate) {
    // TODO: portar (línea 4382-4385).
    throw UnimplementedError();
  }
}
