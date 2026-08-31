// lib/routes/deep_route_resolver.dart
//
// Resuelve una TabDeepRoute (venida de la URL, ya sea al cargar la app
// directamente en una URL profunda o al pulsar atrás/adelante en el
// navegador) en la pantalla real, haciendo el fetch de datos necesario.
//
// Comparte las mismas queries que DeepLinkService usa para notificaciones
// push, para no duplicar lógica de fetch (ver services/deep_link_service.dart).

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/screens/activity/review_details_screen.dart';
import 'package:corpus/screens/library/game_details_screen.dart';
import 'package:corpus/screens/profile/achievements_screen.dart';
import 'package:corpus/screens/profile/achievement_games_screen.dart';
import 'package:corpus/screens/profile/profile_screen.dart';
import 'package:corpus/screens/social/friends_screen.dart';
import 'package:corpus/screens/social/notifications_feed_screen.dart';
import 'package:corpus/screens/bundles/bundle_details_screen.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/utils/achievement_utils.dart';

abstract final class DeepRouteResolver {
  /// Construye la ruta completa (pantalla + `RouteSettings`) correspondiente
  /// a [route], o `null` si el recurso no existe o no se pudo cargar (p. ej.
  /// un id inventado en la URL, o el juego/reseña se borró entre tanto).
  ///
  /// Lleva los mismos `RouteSettings` que usan `pushGameDetails`/
  /// `pushProfile`/etc. (ver corpus_router.dart) a propósito: así, una vez
  /// empujada, esta pantalla es indistinguible de una alcanzada navegando
  /// normalmente, y TabUrlSyncObserver puede reconocerla si más tarde el
  /// usuario cambia de pestaña y vuelve.
  static Future<Route<dynamic>?> buildRoute(TabDeepRoute route) async {
    switch (route) {
      case GameDeepRoute(:final igdbId):
        final game = await fetchGameByIgdbId(igdbId);
        if (game == null) return null;
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.gameDetails,
            arguments: GameDetailsArgs(gameData: game),
          ),
          builder: (_) => GameDetailsScreen(gameData: game),
        );

      case BundleDeepRoute(:final bundleId):
        final bundle = await fetchBundleById(bundleId);
        if (bundle == null) return null;
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.bundleDetails,
            arguments: BundleDetailsArgs(bundleData: bundle),
          ),
          builder: (_) => BundleDetailsScreen(bundleData: bundle),
        );

      case ProfileDeepRoute(:final userId):
        // ProfileScreen resuelve sus propios datos a partir del userId, así
        // que aquí no hace falta ningún fetch previo.
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.profile,
            arguments: ProfileArgs(userId: userId),
          ),
          builder: (_) => ProfileScreen(userId: userId),
        );

      case FriendsDeepRoute():
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.friends),
          builder: (_) => const FriendsScreen(),
        );

      case NotificationsFeedDeepRoute():
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.notificationsFeed),
          builder: (_) => const NotificationsFeedScreen(),
        );

      case ReviewDeepRoute(:final reviewId):
        final args = await fetchReviewById(reviewId);
        if (args == null) return null;
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.reviewDetails,
            arguments: args,
          ),
          builder: (_) => ReviewDetailsScreen(
            gameData: args.gameData,
            userData: args.userData,
            reviewData: args.reviewData,
          ),
        );

      case AchievementsDeepRoute(:final userId):
        final resolvedId =
            userId ?? Supabase.instance.client.auth.currentUser?.id;
        if (resolvedId == null) return null;
        // initialXp en 0: es solo un valor optimista para el primer frame,
        // AchievementsScreen recarga el xp real desde `users` nada más
        // montarse (ver achievements_screen.dart línea ~97).
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.achievements,
            arguments: AchievementsArgs(userId: resolvedId, initialXp: 0),
          ),
          builder: (_) => AchievementsScreen(userId: resolvedId, initialXp: 0),
        );

      case AchievementGamesDeepRoute(:final achievementId, :final userId):
        final args = await fetchAchievementGamesArgs(achievementId, userId);
        if (args == null) return null;
        return MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.achievementGames,
            arguments: args,
          ),
          builder: (_) => AchievementGamesScreen(
            achievementId: args.achievementId,
            achievementName: args.achievementName,
            companyId: args.companyId,
            collectionId: args.collectionId,
            franchiseId: args.franchiseId,
            collectionId2: args.collectionId2,
            franchiseId2: args.franchiseId2,
            milestones: args.milestones,
            achievementIcon: args.achievementIcon,
            achievementColor: args.achievementColor,
          ),
        );
    }
  }

  /// Busca un juego local por su `igdb_id`. Misma query que usa
  /// [DeepLinkService] para el fallback de notificaciones de actividad.
  static Future<Map<String, dynamic>?> fetchGameByIgdbId(int igdbId) async {
    try {
      return await Supabase.instance.client
          .from('games')
          .select()
          .eq('igdb_id', igdbId)
          .maybeSingle();
    } catch (e) {
      debugPrint('[DeepRouteResolver] Error cargando juego $igdbId: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchBundleById(String bundleId) async {
    try {
      return await Supabase.instance.client
          .from('active_bundles')
          .select()
          .eq('id', bundleId)
          .maybeSingle();
    } catch (e) {
      debugPrint('[DeepRouteResolver] Error cargando bundle $bundleId: $e');
      return null;
    }
  }

  /// Busca una reseña con su juego y autor ya unidos (join). Misma query que
  /// usa [DeepLinkService] para notificaciones de comentarios/respuestas.
  static Future<ReviewDetailsArgs?> fetchReviewById(
    String reviewId, {
    bool focusComment = false,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('reviews')
          .select('*, games!inner(*), users!reviews_user_id_users_fkey(*)')
          .eq('id', reviewId)
          .maybeSingle();
      if (res == null) return null;
      return ReviewDetailsArgs(
        gameData: Map<String, dynamic>.from(res['games']),
        userData: res['users'] != null
            ? Map<String, dynamic>.from(res['users'])
            : null,
        reviewData: res,
        focusComment: focusComment,
      );
    } catch (e) {
      debugPrint('[DeepRouteResolver] Error cargando reseña $reviewId: $e');
      return null;
    }
  }

  static Future<AchievementGamesArgs?> fetchAchievementGamesArgs(
    String achievementId,
    String? userId,
  ) async {
    try {
      final groupId = achievementId.split('_').first;

      final res = await Supabase.instance.client
          .from('achievements')
          .select()
          .like('id', '$groupId%')
          .order('id', ascending: true);

      if (res.isEmpty) return null;

      int? companyId;
      int? collectionId;
      int? franchiseId;
      int? collectionId2;
      int? franchiseId2;

      for (final entry in AchievementUtils.achievementIgdbIds.entries) {
        if (groupId.startsWith(entry.key)) {
          companyId = entry.value['companyId'];
          collectionId = entry.value['collectionId'];
          franchiseId = entry.value['franchiseId'];
          collectionId2 = entry.value['collectionId2'];
          franchiseId2 = entry.value['franchiseId2'];
          break;
        }
      }

      final firstAchievement = res.first;
      final titleStr = (firstAchievement['name'] as String?) ?? '';
      final sagaStr = titleStr.split(' (').first;

      final milestones = res.map((row) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(row);
        final aId = m['id'] as String;
        int target = 1;
        final matchSuffix = RegExp(r'_(\d+)$').firstMatch(aId);
        if (matchSuffix != null) {
          target = int.parse(matchSuffix.group(1)!);
        } else if (aId.endsWith('_all')) {
          if (aId.startsWith('fromsoftware') || aId.startsWith('zelda')) {
            target = 7;
          } else if (aId.startsWith('mario')) {
            target = 15;
          } else if (aId.startsWith('dark_souls')) {
            target = 3;
          }
        }
        m['target'] = target;
        m['xp'] = m['xp_reward'] ?? 10;
        return m;
      }).toList();

      milestones.sort(
        (a, b) => (a['target'] as int).compareTo(b['target'] as int),
      );

      return AchievementGamesArgs(
        userId: userId,
        achievementId: groupId,
        achievementName: sagaStr,
        companyId: companyId,
        collectionId: collectionId,
        franchiseId: franchiseId,
        collectionId2: collectionId2,
        franchiseId2: franchiseId2,
        milestones: milestones,
      );
    } catch (e) {
      debugPrint(
        '[DeepRouteResolver] Error cargando saga de logro $achievementId: $e',
      );
      return null;
    }
  }
}
