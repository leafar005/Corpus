import 'package:flutter/material.dart';

/// Mixin genérico para listas/grids con scroll infinito y precarga.
///
/// Se encarga solo de detectar "casi hemos llegado abajo" y disparar
/// [loadMore]; cada widget que lo use gestiona su propia query a Supabase
/// y su propio estado de items/página.
///
/// Uso:
/// ```dart
/// class _MyTabState extends State<MyTab> with PaginatedScrollMixin {
///   @override
///   void initState() {
///     super.initState();
///     initPagination();
///     loadMore(); // primera página
///   }
///
///   @override
///   void dispose() {
///     disposePagination();
///     super.dispose();
///   }
///
///   @override
///   Future<void> loadMore() async { ... }
/// }
/// ```
mixin PaginatedScrollMixin<T extends StatefulWidget> on State<T> {
  ScrollController? _externalScrollController;
  ScrollController? _internalScrollController;

  ScrollController get scrollController =>
      _externalScrollController ??
      (_internalScrollController ??= ScrollController());

  bool isLoadingMore = false;
  bool hasMore = true;

  /// Distancia (px) al final antes de disparar la siguiente página. Con
  /// esto se precarga *antes* de llegar abajo del todo, no al tocar fondo.
  double get prefetchThreshold => 600;

  void initPagination({ScrollController? externalController}) {
    _externalScrollController?.removeListener(_onScroll);
    _internalScrollController?.removeListener(_onScroll);
    _externalScrollController = externalController;
    scrollController.addListener(_onScroll);
  }

  void disposePagination() {
    _externalScrollController?.removeListener(_onScroll);
    final internal = _internalScrollController;
    _internalScrollController = null;
    if (internal != null) {
      internal.removeListener(_onScroll);
      internal.dispose();
    }
  }

  void _onScroll() {
    if (!mounted || !hasMore || isLoadingMore) return;
    final controller = _externalScrollController ?? _internalScrollController;
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels <= prefetchThreshold) {
      loadMore();
    }
  }

  /// Método para soportar infinite scroll en vistas como NestedScrollView
  /// donde se prefiere NotificationListener sin pasar scrollController.
  void onScrollMetrics(ScrollMetrics metrics) {
    if (!mounted || !hasMore || isLoadingMore) return;
    if (metrics.maxScrollExtent - metrics.pixels <= prefetchThreshold) {
      loadMore();
    }
  }

  /// Fuerzas una comprobación de la posición del scroll después del siguiente
  /// frame. Útil para llamar al final de [loadMore] por si la página cargada
  /// no es suficiente para rellenar la pantalla y disparar el scroll natural.
  void triggerScrollCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onScroll();
      }
    });
  }

  /// Cargar la siguiente página. Cada tab implementa su propia query y
  /// hace `setState` con los nuevos items + `hasMore`/`isLoadingMore`.
  Future<void> loadMore();
}
