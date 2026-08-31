import 'package:flutter/material.dart';
import '../routes/deep_route_resolver.dart';
import '../screens/activity/review_details_screen.dart';
import '../screens/bundles/bundles_screen.dart';
import '../screens/library/game_details_screen.dart';

/// Navegación global para deep links (notificaciones push), independiente
/// del árbol de widgets. Las pantallas de detalle se empujan por encima de
/// toda la navegación de pestañas, así no importa en qué tab estaba el
/// usuario cuando llegó el aviso.
class DeepLinkService {
  DeepLinkService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Pestaña pendiente de abrir en MainScreen (3 = Bundles).
  /// Mismo patrón que BundlesNavigation.targetQuery.
  static final ValueNotifier<int?> pendingTab = ValueNotifier<int?>(null);

  /// Punto de entrada único: recibe el `data` de un RemoteMessage FCM
  /// (o el payload decodificado de una notificación local) y navega
  /// según `data['type']`.
  static Future<void> handle(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (type == null) return;

    try {
      switch (type) {
        case 'friend_activity':
          await _openReviewByUserAndGame(data);
          break;
        case 'comment_on_review':
        case 'reply_to_comment':
          await _openReviewById(
            data['review_id'] as String?,
            focusComment: type == 'reply_to_comment',
          );
          break;
        case 'new_bundle':
        case 'bundle_expiring':
          _openBundles(data['bundle_title'] as String?);
          break;
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Error navegando: $e');
    }
  }

  static Future<void> _openReviewById(
    String? reviewId, {
    bool focusComment = false,
  }) async {
    if (reviewId == null || reviewId.isEmpty) return;

    // Misma query que usa la resolución de URLs profundas
    // (/actividad/resena/{id}); ver routes/deep_route_resolver.dart.
    final args = await DeepRouteResolver.fetchReviewById(
      reviewId,
      focusComment: focusComment,
    );
    if (args == null) return;

    final state = navigatorKey.currentState;
    if (state == null) return;

    state.push(
      MaterialPageRoute(
        builder: (_) => ReviewDetailsScreen(
          gameData: args.gameData,
          userData: args.userData,
          reviewData: args.reviewData,
          focusComment: args.focusComment,
        ),
      ),
    );
  }

  static Future<void> _openReviewByUserAndGame(
    Map<String, dynamic> data,
  ) async {
    // Camino normal: activity_feed ya trae review_id enlazado.
    final reviewId = data['review_id'] as String?;
    if (reviewId != null && reviewId.isNotEmpty) {
      await _openReviewById(reviewId);
      return;
    }

    // Fallback (notificaciones antiguas o sin reseña asociada):
    // abrimos la ficha del juego en vez de un post concreto. Misma query
    // que usa /buscar/{igdb_id}; ver routes/deep_route_resolver.dart.
    final gameId = int.tryParse(data['game_id'] ?? '');
    if (gameId == null) return;
    final game = await DeepRouteResolver.fetchGameByIgdbId(gameId);
    if (game == null) return;

    final state = navigatorKey.currentState;
    if (state == null) return;
    state.push(
      MaterialPageRoute(builder: (_) => GameDetailsScreen(gameData: game)),
    );
  }

  static void _openBundles(String? bundleTitle) {
    if (bundleTitle != null && bundleTitle.isNotEmpty) {
      BundlesNavigation.targetQuery.value = bundleTitle;
    }
    pendingTab.value = 3;
  }
}
