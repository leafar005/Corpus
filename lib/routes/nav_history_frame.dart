import 'package:flutter/widgets.dart';

/// Un nivel dentro de la pila de UN Navigator (una pestaña, o la pila raíz
/// usada por DeepLinkService). Se crea uno por cada ruta empujada, tenga o
/// no una sub-URL propia legible — eso es justamente lo que arregla el Bug D
/// (sección 1.4): la contabilidad de profundidad no depende de que la ruta
/// sea "reconocida" por deepRouteFromRouteSettings, solo de que exista.
class NavHistoryFrame {
  final int token;
  final RouteSettings settings;
  final Route<dynamic>? route;

  const NavHistoryFrame({
    required this.token,
    required this.settings,
    this.route,
  });
}
