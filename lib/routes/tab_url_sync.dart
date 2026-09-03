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

import 'package:flutter/widgets.dart';

import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/routes/app_navigation_controller.dart';
import 'package:corpus/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String? _currentUserId() => Supabase.instance.client.auth.currentUser?.id;

int? _extractIgdbId(Game gameData) {
  return gameData.igdbId;
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
      final userId = args.userId == _currentUserId() ? null : args.userId;
      return AchievementGamesDeepRoute(
        userId: userId,
        achievementId: args.achievementId,
      );

    case AppRoutes.friends:
      return const FriendsDeepRoute();

    case AppRoutes.notificationsFeed:
      return const NotificationsFeedDeepRoute();

    default:
      return null;
  }
}

class TabUrlSyncObserver extends NavigatorObserver {
  TabUrlSyncObserver(this.stackIndex);

  final int stackIndex;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNavigationController.instance.onNavigatorPush(stackIndex, route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNavigationController.instance.onNavigatorPop(stackIndex);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNavigationController.instance.onNavigatorPop(stackIndex);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    AppNavigationController.instance.onNavigatorReplace(
      stackIndex,
      newRoute: newRoute,
    );
  }
}
