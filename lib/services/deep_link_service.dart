import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../repositories/activity_repository.dart';
import '../routes/deep_route_resolver.dart';
import '../routes/explore_navigation.dart';
import '../routes/tab_deep_route.dart';
import '../utils/corpus_logger.dart';

/// Navegación global para deep links (notificaciones push), independiente
/// del árbol de widgets. Parsea payloads a [TabDeepRoute] y delega el
/// ensamblaje de rutas en [DeepRouteResolver] / `CorpusRouter`.
class DeepLinkService {
  DeepLinkService._();

  static final _log = CorpusLogger('DeepLinkService');

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Pestaña pendiente de abrir en MainScreen (1 = Explorar para bundles).
  static final ValueNotifier<int?> pendingTab = ValueNotifier<int?>(null);

  static TabDeepRoute? _pendingRoute;

  @visibleForTesting
  static TabDeepRoute? get pendingRouteForTesting => _pendingRoute;

  @visibleForTesting
  static void clearPendingForTesting() {
    pendingTab.value = null;
    _pendingRoute = null;
  }

  static String? _readString(Map<dynamic, dynamic> data, String key) {
    final raw = data[key];
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Convierte el payload de una notificación en una [TabDeepRoute] sin
  /// acoplarse a widgets ni asumir tipos `String` estrictos en [data].
  @visibleForTesting
  static Future<TabDeepRoute?> resolveNotificationRoute(
    Map<String, dynamic> data, {
    ActivityRepository? activityRepo,
  }) async {
    final type = _readString(data, 'type');

    Future<TabDeepRoute?> resolveReviewOrPost({
      required String? reviewId,
      required String? postId,
      required bool focusComment,
    }) async {
      if (reviewId != null) {
        if (postId != null) {
          try {
            final currentReviewPostId = await (activityRepo ??
                    ActivityRepository())
                .resolvePostIdForReview(reviewId, create: false)
                .timeout(const Duration(seconds: 5));
            if (currentReviewPostId != null && currentReviewPostId != postId) {
              return GroupedPostDeepRoute(
                postId,
                focusComment: focusComment,
              );
            }
          } catch (e) {
            _log.warning(
              'Error resolviendo postId para reseña $reviewId (usando reseña directa): $e',
            );
          }
        }
        return ReviewDeepRoute(
          reviewId,
          postId: postId,
          focusComment: focusComment,
        );
      }

      if (postId != null) {
        return GroupedPostDeepRoute(postId, focusComment: focusComment);
      }
      return null;
    }

    switch (type) {
      case 'comment_on_review':
      case 'reply_to_comment':
        return resolveReviewOrPost(
          reviewId: _readString(data, 'review_id'),
          postId: _readString(data, 'post_id'),
          focusComment: type == 'reply_to_comment',
        );

      case 'friend_activity':
      case null:
        final reviewOrPost = await resolveReviewOrPost(
          reviewId: _readString(data, 'review_id'),
          postId: _readString(data, 'post_id'),
          focusComment: false,
        );
        if (reviewOrPost != null) return reviewOrPost;

        final gameId = int.tryParse(_readString(data, 'game_id') ?? '');
        if (gameId != null && gameId > 0) {
          return GameDeepRoute(gameId);
        }
        return null;

      default:
        return null;
    }
  }

  /// Punto de entrada único: recibe el `data` de un RemoteMessage FCM
  /// (o el payload decodificado de una notificación local/Web) y navega
  /// según `data['type']`.
  static Future<void> handle(
    Map<String, dynamic> data, {
    ActivityRepository? activityRepo,
  }) async {
    final type = _readString(data, 'type');

    try {
      if (type == 'new_bundle' || type == 'bundle_expiring') {
        _openBundles(_readString(data, 'bundle_title'));
        return;
      }

      final deepRoute = await resolveNotificationRoute(
        data,
        activityRepo: activityRepo,
      );
      if (deepRoute == null) return;

      await _pushDeepRoute(deepRoute);
    } catch (e) {
      _log.error('Error navegando deep link', error: e);
    }
  }

  /// Ejecuta la navegación diferida si llegó un deep link en arranque en frío
  /// antes de que `MainScreen` / `navigatorKey.currentState` estuviera listo.
  static Future<void> flushPendingNavigation() async {
    final route = _pendingRoute;
    if (route == null) return;
    if (navigatorKey.currentState == null) return;
    _pendingRoute = null;
    await _pushDeepRoute(route);
  }

  static Future<void> _pushDeepRoute(TabDeepRoute deepRoute) async {
    final state = navigatorKey.currentState;
    if (state == null) {
      _pendingRoute = deepRoute;
      return;
    }

    final route = await DeepRouteResolver.buildRoute(deepRoute);
    if (route == null) return;

    final liveState = navigatorKey.currentState;
    if (liveState == null) {
      _pendingRoute = deepRoute;
      return;
    }
    liveState.push(route);
  }

  static void _openBundles(String? bundleTitle) {
    final state = navigatorKey.currentState;
    if (state != null) {
      state.popUntil((r) => r.isFirst);
    }
    if (bundleTitle != null && bundleTitle.isNotEmpty) {
      ExploreNavigation.targetQuery.value = bundleTitle;
    }
    pendingTab.value = 1;
  }
}
