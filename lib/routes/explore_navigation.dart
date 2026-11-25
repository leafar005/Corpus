import 'package:flutter/foundation.dart';

/// Estado compartido para pre-rellenar la barra de búsqueda de Explorar
/// desde notificaciones push, accesos de Inicio o deep links.
class ExploreNavigation {
  ExploreNavigation._();

  static final ValueNotifier<String?> targetQuery = ValueNotifier<String?>(null);
}
