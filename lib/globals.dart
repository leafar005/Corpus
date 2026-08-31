import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'utils/igdb_constants.dart';

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

/// Badge de notificaciones sociales no leídas (likes, solicitudes de
/// amistad, comentarios y respuestas). Se sincroniza siempre desde el
/// servidor (tabla notifications + RPCs), nunca desde almacenamiento local.
final ValueNotifier<int> unreadNotificationsCount = ValueNotifier<int>(0);

// Flag para desactivar temporizadores infinitos de carrusel/fondo en tests E2E y evitar que pumpAndSettle se cuelgue
bool kDisableCarouselForTests = false;

/// Índice de la pestaña actualmente visible en MainScreen. La usa
/// TabUrlSyncObserver (routes/tab_url_sync.dart) para saber si un push/pop
/// ocurre en la pestaña visible o en una de fondo, y así no pisar la URL
/// por algo que pasa en una pestaña que el usuario no está viendo.
final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);

/// Se activa mientras MainScreen está re-sincronizando el estado de una
/// pestaña a partir de un cambio de URL (botón atrás/adelante del
/// navegador), para que TabUrlSyncObserver no cree una entrada de historial
/// nueva por algo que el propio navegador ya nos disparó. Ver
/// MainScreen._applyTabFromUrl.
bool isSyncingRouteFromBrowser = false;

// Utilidad global para obtener el espaciado inferior en listas (móvil vs escritorio)
double getBottomSpacer(BuildContext context) {
  final isDesktop = MediaQuery.of(context).size.width > 800;
  return isDesktop ? 32.0 : 120.0;
}

/// Define la cantidad de columnas (2, 3 o 4) para las cuadrículas de juegos en móviles.
final ValueNotifier<int> mobileGridColumnsNotifier = ValueNotifier<int>(3);

/// Genera el SliverGridDelegate adaptado a la configuración actual (Móvil vs Escritorio)
SliverGridDelegate getCorpusGridDelegate(
  BuildContext context,
  int mobileColumns, {
  double spacing = 10.0,
  double desktopMaxExtent = 140.0,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width > 800;
  if (isDesktop) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: desktopMaxExtent,
      childAspectRatio: IgdbConstants.coverAspectRatio,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
    );
  } else {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: mobileColumns,
      childAspectRatio: IgdbConstants.coverAspectRatio,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
    );
  }
}
