// lib/routes/tab_url_sync.dart
//
// Traduce cada push/pop del Navigator anidado de una pestaña a una URL, y
// viceversa (deep_route_resolver.dart hace el camino inverso).
//
// Se implementa como un NavigatorObserver para no tener que acordarnos de
// llamar a nada manualmente desde cada pushGameDetails/pushProfile/etc: en
// cuanto una de esas pantallas entra o sale de la pila, la URL se actualiza
// sola. Si en el futuro se añade una pantalla nueva con su propia sub-ruta,
// solo hace falta añadir un caso en deepRouteFromRouteSettings.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/globals.dart';
import 'package:corpus/utils/web_js.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/tab_deep_route.dart';

String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

int? _extractIgdbId(Map<String, dynamic> gameData) {
  final raw = gameData['igdb_id'] ?? gameData['id'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

/// A partir de los `arguments` con los que se empujó una pantalla, reconstruye
/// la [TabDeepRoute] que le corresponde. Devuelve `null` para la pantalla
/// raíz de una pestaña o para cualquier ruta sin sub-URL propia (ajustes,
/// login, etc.): esas simplemente no tocan la URL.
TabDeepRoute? deepRouteFromRouteSettings(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.gameDetails:
      final args = settings.arguments;
      if (args is! GameDetailsArgs) return null;
      final igdbId = _extractIgdbId(args.gameData);
      return igdbId == null ? null : GameDeepRoute(igdbId);

    case AppRoutes.profile:
      final args = settings.arguments;
      if (args is! ProfileArgs) return null;
      final userId = args.userId;
      if (userId == null) return null;
      // Si por lo que sea alguien empuja el propio perfil, no le hace falta
      // sub-ruta: es equivalente a la raíz de la pestaña Perfil.
      if (userId == _currentUserId()) return null;
      return ProfileDeepRoute(userId);

    case AppRoutes.reviewDetails:
      final args = settings.arguments;
      if (args is! ReviewDetailsArgs) return null;
      final id = args.reviewData['id'];
      return id == null ? null : ReviewDeepRoute(id.toString());

    case AppRoutes.bundleDetails:
      final args = settings.arguments;
      if (args is! BundleDetailsArgs) return null;
      final bundleId = args.bundleData['id']?.toString();
      if (bundleId == null) return null;
      return BundleDeepRoute(bundleId);

    case AppRoutes.achievements:
      final args = settings.arguments;
      if (args is! AchievementsArgs) return null;
      final userId = args.userId == _currentUserId() ? null : args.userId;
      return AchievementsDeepRoute(userId: userId);

    case AppRoutes.achievementGames:
      final args = settings.arguments;
      if (args is! AchievementGamesArgs) return null;
      // We don't have a userId in AchievementGamesArgs because it always refers to the viewed profile.
      // But we can check if it's the current user from context or just leave userId as null for now,
      // or extract it if we had it. Since AchievementGamesArgs doesn't have userId,
      // it means it's always for the currently viewed profile's achievements.
      // Actually, wait, when we navigate to AchievementGamesScreen, it uses the profile we are in.
      // Let's just return it without userId, it will fall back to the current user's profile URL.
      return AchievementGamesDeepRoute(achievementId: args.achievementId);

    case AppRoutes.friends:
      return const FriendsDeepRoute();

    case AppRoutes.notificationsFeed:
      return const NotificationsFeedDeepRoute();

    default:
      return null;
  }
}

/// Sincroniza la URL del navegador (web) con la pila de navegación de UNA
/// pestaña. Se cuelga como `observer` del `Navigator` anidado de esa
/// pestaña en MainScreen.
///
/// - Al empujar una pantalla con sub-URL propia (juego, perfil, reseña,
///   logros) añade una entrada nueva al historial (`pushState`): así el
///   botón atrás/adelante del navegador funciona.
/// - Al hacer pop (botón atrás nativo, un AppBar, etc.) corrige la URL
///   visible con `replaceState`, sin consumir una entrada del historial:
///   quien controla de verdad el historial es siempre el propio navegador.
///
/// [isSyncingRouteFromBrowser] (globals.dart) desactiva esto mientras
/// MainScreen está re-sincronizando el estado de una pestaña a partir de un
/// cambio de URL (atrás/adelante), para no crear una entrada de historial
/// nueva por algo que el propio navegador ya nos disparó.
class TabUrlSyncObserver extends NavigatorObserver {
  TabUrlSyncObserver(this.tabIndex);

  final int tabIndex;

  /// Ajustes de la ruta que está actualmente arriba del todo en la pila de
  /// esta pestaña. Lo usa MainScreen para saber qué URL mostrar al volver a
  /// esta pestaña tras haber estado en otra, sin depender de una API
  /// pública de Navigator para "asomarse" a su pila.
  RouteSettings? topRouteSettings;

  bool get _isActiveTab => currentTabIndexNotifier.value == tabIndex;

  void _sync(Route<dynamic>? route, {required bool push}) {
    if (!kIsWeb || !_isActiveTab || isSyncingRouteFromBrowser) return;
    final subRoute = route == null
        ? null
        : deepRouteFromRouteSettings(route.settings);
    setWebPath(publicPathForTabRoute(tabIndex, subRoute), replace: !push);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRouteSettings = route.settings;
    // La primerísima ruta que construye el Navigator es la raíz de la
    // pestaña: ya la gestiona MainScreen (_syncWebUrlForTab), no hace falta
    // que la reafirmemos aquí también.
    if (deepRouteFromRouteSettings(route.settings) == null) return;
    _sync(route, push: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRouteSettings = previousRoute?.settings;
    _sync(previousRoute, push: false);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    topRouteSettings = newRoute?.settings;
    if (newRoute == null) return;
    _sync(newRoute, push: false);
  }
}
