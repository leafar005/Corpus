// lib/routes/deep_route_resolver.dart
//
// Resuelve una TabDeepRoute (venida de la URL o de un deep link push)
// haciendo el fetch necesario y delegando la creación de rutas a CorpusRouter.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/models/models.dart';
import 'package:corpus/repositories/review_repository.dart';
import 'package:corpus/routes/app_routes.dart';
import 'package:corpus/routes/corpus_router.dart';
import 'package:corpus/routes/tab_deep_route.dart';
import 'package:corpus/utils/achievement_utils.dart';
import 'package:corpus/utils/corpus_logger.dart';
import 'package:corpus/utils/postgrest_utils.dart';

abstract final class DeepRouteResolver {
  static final _log = CorpusLogger('DeepRouteResolver');

  /// Construye la ruta completa (pantalla + `RouteSettings`) correspondiente
  /// a [route], o `null` si el recurso no existe o no se pudo cargar.
  static Future<Route<dynamic>?> buildRoute(
    TabDeepRoute route, {
    SupabaseClient? client,
  }) async {
    final db = client ?? Supabase.instance.client;
    switch (route) {
      case GameDeepRoute(:final igdbId):
        final game = await fetchGameByIgdbId(igdbId, client: db);
        if (game == null) return null;
        return CorpusRouter.route<dynamic>(
          RouteSettings(
            name: AppRoutes.gameDetails,
            arguments: GameDetailsArgs(gameData: Game.fromMap(game)),
          ),
        );

      case BundleDeepRoute(:final bundleId):
        final bundle = await fetchBundleById(bundleId, client: db);
        if (bundle == null) return null;
        return CorpusRouter.route<dynamic>(
          RouteSettings(
            name: AppRoutes.bundleDetails,
            arguments: BundleDetailsArgs(bundleData: bundle),
          ),
        );

      case ProfileDeepRoute(:final userId):
        return CorpusRouter.route<dynamic>(
          RouteSettings(
            name: AppRoutes.profile,
            arguments: ProfileArgs(userId: userId),
          ),
        );

      case FriendsDeepRoute():
        return CorpusRouter.route<dynamic>(
          const RouteSettings(name: AppRoutes.friends),
        );

      case NotificationsFeedDeepRoute():
        return CorpusRouter.route<dynamic>(
          const RouteSettings(name: AppRoutes.notificationsFeed),
        );

      case ReviewDeepRoute(:final reviewId, :final postId, :final focusComment):
        final args = await fetchReviewById(
          reviewId,
          postId: postId,
          focusComment: focusComment,
          client: db,
        );
        if (args == null) return null;
        return CorpusRouter.route<dynamic>(
          RouteSettings(name: AppRoutes.reviewDetails, arguments: args),
        );

      case GroupedPostDeepRoute(:final postId, :final focusComment):
        return CorpusRouter.route<dynamic>(
          RouteSettings(
            name: AppRoutes.groupedPostDetails,
            arguments: GroupedPostDetailsArgs(
              postId: postId,
              focusComment: focusComment,
            ),
          ),
        );

      case AchievementsDeepRoute(:final userId):
        final resolvedId = userId ?? db.auth.currentUser?.id;
        if (resolvedId == null) return null;
        return CorpusRouter.route<dynamic>(
          RouteSettings(
            name: AppRoutes.achievements,
            arguments: AchievementsArgs(userId: resolvedId, initialXp: 0),
          ),
        );

      case AchievementGamesDeepRoute(:final achievementId, :final userId):
        final args = await fetchAchievementGamesArgs(
          achievementId,
          userId,
          client: db,
        );
        if (args == null) return null;
        return CorpusRouter.route<dynamic>(
          RouteSettings(name: AppRoutes.achievementGames, arguments: args),
        );
    }
  }

  /// Busca un juego local por su `igdb_id`.
  static Future<Map<String, dynamic>?> fetchGameByIgdbId(
    int igdbId, {
    SupabaseClient? client,
  }) async {
    try {
      final db = client ?? Supabase.instance.client;
      return await db
          .from('games')
          .select(kGameDetailColumns)
          .eq('igdb_id', igdbId)
          .maybeSingle();
    } catch (e) {
      _log.warning('Error cargando juego $igdbId: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchBundleById(
    String bundleId, {
    SupabaseClient? client,
  }) async {
    try {
      final db = client ?? Supabase.instance.client;
      return await db
          .from('active_bundles')
          .select(kActiveBundleColumns)
          .eq('id', bundleId)
          .maybeSingle();
    } catch (e) {
      _log.warning('Error cargando bundle $bundleId: $e');
      return null;
    }
  }

  /// Busca una reseña con su juego y autor ya unidos (join).
  static Future<ReviewDetailsArgs?> fetchReviewById(
    String reviewId, {
    String? postId,
    bool focusComment = false,
    SupabaseClient? client,
  }) async {
    try {
      final db = client ?? Supabase.instance.client;
      final res = await db
          .from('reviews')
          .select(
            '$kReviewColumns, games!inner($kGameDetailColumns), '
            'users!reviews_user_id_users_fkey($kPublicUserBasicColumns)',
          )
          .eq('id', reviewId)
          .maybeSingle();
      if (res == null) return null;
      final reviewMap = Map<String, dynamic>.from(res);
      await ReviewRepository(client: db).injectPartners([reviewMap]);
      final rawGames = reviewMap['games'];
      final rawUsers = reviewMap['users'];
      return ReviewDetailsArgs(
        gameData: Game.fromMap(
          rawGames is Map ? Map<String, dynamic>.from(rawGames) : const {},
        ),
        userData: rawUsers is Map
            ? Map<String, dynamic>.from(rawUsers)
            : null,
        reviewData: reviewMap,
        postId: postId,
        focusComment: focusComment,
      );
    } catch (e) {
      _log.warning('Error cargando reseña $reviewId: $e');
      return null;
    }
  }

  static Future<AchievementGamesArgs?> fetchAchievementGamesArgs(
    String achievementId,
    String? userId, {
    SupabaseClient? client,
  }) async {
    final trimmedId = achievementId.trim();
    if (trimmedId.isEmpty) return null;

    try {
      final db = client ?? Supabase.instance.client;
      final groupId = AchievementUtils.extractSagaGroupId(trimmedId);
      final likePrefix = escapeLikePattern(groupId);

      final res = await db
          .from('achievements')
          .select(kAchievementColumns)
          .like('id', '$likePrefix%')
          .order('id', ascending: true)
          .limit(50);

      final matchingRows = (res as List).whereType<Map>().where((row) {
        final rowId = row['id']?.toString() ?? '';
        return rowId == trimmedId ||
            AchievementUtils.extractSagaGroupId(rowId) == groupId;
      }).toList();

      if (matchingRows.isEmpty) return null;

      final igdbIds = AchievementUtils.resolveIgdbIdsForGroup(groupId);
      final int? companyId = igdbIds?['companyId'];
      final int? collectionId = igdbIds?['collectionId'];
      final int? franchiseId = igdbIds?['franchiseId'];
      final int? collectionId2 = igdbIds?['collectionId2'];
      final int? franchiseId2 = igdbIds?['franchiseId2'];

      final firstAchievement = matchingRows.first;
      final titleStr = (firstAchievement['name'] as String?) ?? '';
      final sagaStr = AchievementUtils.cleanSagaBaseName(titleStr);

      final milestones = matchingRows.map((row) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(row);
        m['target'] = AchievementUtils.resolveMilestoneTarget(m);
        m['xp'] = (m['xp_reward'] as num?)?.toInt() ?? 10;
        return m;
      }).toList();

      milestones.sort(
        (a, b) => (a['target'] as int).compareTo(b['target'] as int),
      );

      final trimmedUserId = userId?.trim();
      final normalizedUserId =
          (trimmedUserId == null || trimmedUserId.isEmpty) ? null : trimmedUserId;

      return AchievementGamesArgs(
        userId: normalizedUserId,
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
      _log.warning('Error cargando saga de logro $achievementId: $e');
      return null;
    }
  }
}
