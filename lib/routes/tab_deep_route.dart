// lib/routes/tab_deep_route.dart
//
// Sub-rutas navegables DENTRO de cada pestaña, reflejadas en la URL (web).
// Cada pestaña ya tiene su propio `Navigator` anidado (ver MainScreen); esto
// añade una capa encima que traduce lo que hay arriba de esa pila a un path
// legible, y viceversa.
//
// Gramática (igual para las 5 pestañas, así que no hace falta un parser
// distinto por cada una):
//
//   {idNumérico}        → ficha de un juego (igdb_id)      /buscar/1942
//   {id}                → perfil de otro usuario            /actividad/3f2a-...
//   resena/{id}         → detalle de una reseña             /actividad/resena/9c1b-...
//   logros              → logros del propio usuario         /perfil/logros
//   {id}/logros         → logros de otro usuario             /perfil/3f2a-.../logros
//
// El primer segmento decide todo: si es numérico es SIEMPRE un juego (los
// ids de IGDB son enteros, los de usuario/reseña son uuids), así que no hay
// ambigüedad posible sin necesidad de prefijos como `juego/`.

import 'package:corpus/routes/app_routes.dart';

/// Una sub-ruta resuelta dentro de una pestaña. Sellada: cualquier `switch`
/// sobre esto es exhaustivo y el analizador avisa si falta cubrir un caso
/// nuevo.
sealed class TabDeepRoute {
  const TabDeepRoute();

  /// Segmentos de path (sin la raíz de la pestaña) que representan esta ruta.
  List<String> toSegments();
}

/// Ficha de un juego, identificado por su `igdb_id`.
final class GameDeepRoute extends TabDeepRoute {
  final int igdbId;
  const GameDeepRoute(this.igdbId);

  @override
  List<String> toSegments() => ['$igdbId'];

  @override
  bool operator ==(Object other) =>
      other is GameDeepRoute && other.igdbId == igdbId;
  @override
  int get hashCode => igdbId.hashCode;
  @override
  String toString() => 'GameDeepRoute($igdbId)';
}

/// Perfil de otro usuario (el propio perfil no tiene sub-ruta: es la raíz
/// de la pestaña Perfil).
final class ProfileDeepRoute extends TabDeepRoute {
  final String userId;
  const ProfileDeepRoute(this.userId);

  @override
  List<String> toSegments() => [userId];

  @override
  bool operator ==(Object other) =>
      other is ProfileDeepRoute && other.userId == userId;
  @override
  int get hashCode => userId.hashCode;
  @override
  String toString() => 'ProfileDeepRoute($userId)';
}

/// Detalle de una reseña.
final class ReviewDeepRoute extends TabDeepRoute {
  final String reviewId;
  const ReviewDeepRoute(this.reviewId);

  @override
  List<String> toSegments() => ['resena', reviewId];

  @override
  bool operator ==(Object other) =>
      other is ReviewDeepRoute && other.reviewId == reviewId;
  @override
  int get hashCode => reviewId.hashCode;
  @override
  String toString() => 'ReviewDeepRoute($reviewId)';
}

/// Logros de un usuario. `userId == null` → los del propio usuario.
final class AchievementsDeepRoute extends TabDeepRoute {
  final String? userId;
  const AchievementsDeepRoute({this.userId});

  @override
  List<String> toSegments() =>
      userId == null ? ['logros'] : [userId!, 'logros'];

  @override
  bool operator ==(Object other) =>
      other is AchievementsDeepRoute && other.userId == userId;
  @override
  int get hashCode => userId.hashCode;
  @override
  String toString() => 'AchievementsDeepRoute($userId)';
}

/// Juegos de un logro concreto. `userId == null` → logros del propio usuario.
final class AchievementGamesDeepRoute extends TabDeepRoute {
  final String? userId;
  final String achievementId;
  const AchievementGamesDeepRoute({this.userId, required this.achievementId});

  @override
  List<String> toSegments() => userId == null
      ? ['logros', achievementId]
      : [userId!, 'logros', achievementId];

  @override
  bool operator ==(Object other) =>
      other is AchievementGamesDeepRoute &&
      other.userId == userId &&
      other.achievementId == achievementId;
  @override
  int get hashCode => Object.hash(userId, achievementId);
  @override
  String toString() =>
      'AchievementGamesDeepRoute(userId: $userId, achievementId: $achievementId)';
}

/// Amigos del propio usuario.
final class FriendsDeepRoute extends TabDeepRoute {
  const FriendsDeepRoute();

  @override
  List<String> toSegments() => ['amigos'];

  @override
  bool operator ==(Object other) => other is FriendsDeepRoute;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'FriendsDeepRoute()';
}

/// Feed de notificaciones del propio usuario.
final class NotificationsFeedDeepRoute extends TabDeepRoute {
  const NotificationsFeedDeepRoute();

  @override
  List<String> toSegments() => ['notificaciones'];

  @override
  bool operator ==(Object other) => other is NotificationsFeedDeepRoute;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'NotificationsFeedDeepRoute()';
}

/// Detalles de un bundle.
final class BundleDeepRoute extends TabDeepRoute {
  final String bundleId;
  const BundleDeepRoute(this.bundleId);

  @override
  List<String> toSegments() => ['bundle', bundleId];

  @override
  bool operator ==(Object other) =>
      other is BundleDeepRoute && other.bundleId == bundleId;
  @override
  int get hashCode => bundleId.hashCode;
  @override
  String toString() => 'BundleDeepRoute($bundleId)';
}

/// Interpreta los segmentos posteriores a la raíz de una pestaña (ver
/// [AppRoutes.subSegmentsFromPublicPath]). Devuelve `null` si no reconoce el
/// patrón, en cuyo caso la pestaña simplemente se queda en su raíz.
TabDeepRoute? parseTabDeepRoute(List<String> segments) {
  if (segments.isEmpty) return null;

  final maybeGameId = int.tryParse(segments[0]);
  if (maybeGameId != null) return GameDeepRoute(maybeGameId);

  if (segments[0] == 'resena') {
    if (segments.length < 2 || segments[1].isEmpty) return null;
    return ReviewDeepRoute(segments[1]);
  }

  if (segments[0] == 'bundle') {
    if (segments.length < 2 || segments[1].isEmpty) return null;
    return BundleDeepRoute(segments[1]);
  }

  if (segments[0] == 'logros') {
    if (segments.length >= 2) {
      return AchievementGamesDeepRoute(achievementId: segments[1]);
    }
    return const AchievementsDeepRoute();
  }

  if (segments[0] == 'amigos') {
    return const FriendsDeepRoute();
  }

  if (segments[0] == 'notificaciones') {
    return const NotificationsFeedDeepRoute();
  }

  final userId = segments[0];
  if (segments.length >= 2 && segments[1] == 'logros') {
    if (segments.length >= 3) {
      return AchievementGamesDeepRoute(
        userId: userId,
        achievementId: segments[2],
      );
    }
    return AchievementsDeepRoute(userId: userId);
  }
  return ProfileDeepRoute(userId);
}

/// Construye el path público completo (pestaña + sub-ruta) para sincronizar
/// con la URL del navegador.
String publicPathForTabRoute(int tabIndex, [TabDeepRoute? subRoute]) {
  final root = AppRoutes.publicPathForTab(tabIndex);
  if (subRoute == null) return root;
  return '$root/${subRoute.toSegments().join('/')}';
}
