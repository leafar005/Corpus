import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

// Notificador global. Lo incrementaremos cada vez que el usuario añada/edite un juego en su biblioteca.
// Cualquier pantalla que necesite refrescarse (como ProfileScreen o HomeScreen) puede escuchar este notificador.
final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier<int>(0);

// Notificador global para el tema claro/oscuro
final ThemeNotifier themeNotifier = ThemeNotifier();

// NUEVO: Estado global de usuarios conectados en tiempo real
final ValueNotifier<Set<String>> onlineUsersNotifier =
    ValueNotifier<Set<String>>({});

/// IDs de activity_feed vistos por el usuario actual (actualización optimista
/// + reactiva para pintar los anillos de historias en gris al instante).
final ValueNotifier<Set<String>> viewedStoryIdsNotifier =
    ValueNotifier<Set<String>>({});

// Badge de actividad no leída: se incrementa al llegar eventos realtime
// mientras el usuario no está en la pestaña Actividad.
final ValueNotifier<int> unreadActivityCount = ValueNotifier<int>(0);

// Badge de solicitudes de amistad pendientes: se incrementa al llegar una solicitud nueva
// y se resetea al abrir la pantalla de Amigos.
final ValueNotifier<int> unreadFriendRequestsCount = ValueNotifier<int>(0);

// Flag para desactivar temporizadores infinitos de carrusel/fondo en tests E2E y evitar que pumpAndSettle se cuelgue
bool kDisableCarouselForTests = false;

// Utilidad global para obtener el espaciado inferior en listas (móvil vs escritorio)
double getBottomSpacer(BuildContext context) {
  final isDesktop = MediaQuery.of(context).size.width > 800;
  return isDesktop ? 32.0 : 120.0;
}
