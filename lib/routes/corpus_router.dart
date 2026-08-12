import 'package:flutter/material.dart';

import '../screens/activity/review_details_screen.dart';
import '../screens/appearance_screen.dart';
import '../screens/design/design_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/info_screen.dart';
import '../screens/library/game_details_screen.dart';
import '../screens/library/group_games_screen.dart';
import '../screens/library/search_screen.dart';
import '../screens/profile/achievement_games_screen.dart';
import '../screens/profile/achievements_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/hall_of_fame_selector_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/home_appearance_screen.dart';
import '../screens/settings/import_preview_screen.dart';
import '../screens/settings/info_tab_appearance_screen.dart';
import '../screens/settings/integrations_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/steam_import_progress_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/social/friends_screen.dart';
import '../services/import_service.dart';
import 'app_routes.dart';

// ── Argumentos de rutas ──────────────────────────────────────────────────────

class GameDetailsArgs {
  final Map<String, dynamic> gameData;
  final ScrollController? scrollController;
  final bool autoOpenReview;

  const GameDetailsArgs({
    required this.gameData,
    this.scrollController,
    this.autoOpenReview = false,
  });
}

class ReviewDetailsArgs {
  final Map<String, dynamic> gameData;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic> reviewData;
  final bool focusComment;

  const ReviewDetailsArgs({
    required this.gameData,
    required this.userData,
    required this.reviewData,
    this.focusComment = false,
  });
}

class ProfileArgs {
  final String? userId;

  const ProfileArgs({this.userId});
}

class SearchArgs {
  final String? initialQuery;
  final bool isSelectionMode;

  const SearchArgs({this.initialQuery, this.isSelectionMode = false});
}

class SettingsArgs {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>?> hallOfFame;

  const SettingsArgs({
    required this.userProfile,
    required this.hallOfFame,
  });
}

class EditProfileArgs {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>?> hallOfFame;

  const EditProfileArgs({
    required this.userProfile,
    required this.hallOfFame,
  });
}

class AchievementsArgs {
  final String userId;
  final int initialXp;

  const AchievementsArgs({required this.userId, required this.initialXp});
}

class AchievementGamesArgs {
  final String achievementId;
  final String achievementName;
  final int? companyId;
  final int? collectionId;
  final int? franchiseId;
  final int? collectionId2;
  final int? franchiseId2;
  final List<Map<String, dynamic>> milestones;
  final IconData? achievementIcon;
  final Color? achievementColor;

  const AchievementGamesArgs({
    required this.achievementId,
    required this.achievementName,
    this.companyId,
    this.collectionId,
    this.franchiseId,
    this.collectionId2,
    this.franchiseId2,
    required this.milestones,
    this.achievementIcon,
    this.achievementColor,
  });
}

class GroupGamesArgs {
  final String title;
  final int collectionId;
  final bool isFranchise;
  final bool isCompany;

  const GroupGamesArgs({
    required this.title,
    required this.collectionId,
    this.isFranchise = false,
    this.isCompany = false,
  });
}

class HallOfFameSelectorArgs {
  final int pinOrder;

  const HallOfFameSelectorArgs({required this.pinOrder});
}

class SteamImportProgressArgs {
  final int minPlaytimeMinutes;

  const SteamImportProgressArgs({required this.minPlaytimeMinutes});
}

class ImportPreviewArgs {
  final List<CsvGameRow> rows;

  const ImportPreviewArgs({required this.rows});
}

// ── Generador de rutas ─────────────────────────────────────────────────────────

abstract final class CorpusRouter {
  static Route<T> route<T>(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.gameDetails:
        final args = settings.arguments! as GameDetailsArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => GameDetailsScreen(
            gameData: args.gameData,
            scrollController: args.scrollController,
            autoOpenReview: args.autoOpenReview,
          ),
        );

      case AppRoutes.reviewDetails:
        final args = settings.arguments! as ReviewDetailsArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => ReviewDetailsScreen(
            gameData: args.gameData,
            userData: args.userData,
            reviewData: args.reviewData,
            focusComment: args.focusComment,
          ),
        );

      case AppRoutes.profile:
        final args = settings.arguments as ProfileArgs?;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => ProfileScreen(userId: args?.userId),
        );

      case AppRoutes.search:
        final args = settings.arguments as SearchArgs?;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => SearchScreen(
            initialQuery: args?.initialQuery,
            isSelectionMode: args?.isSelectionMode ?? false,
          ),
        );

      case AppRoutes.friends:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const FriendsScreen(),
        );

      case AppRoutes.settings:
        final args = settings.arguments! as SettingsArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => SettingsScreen(
            userProfile: args.userProfile,
            hallOfFame: args.hallOfFame,
          ),
        );

      case AppRoutes.editProfile:
        final args = settings.arguments! as EditProfileArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => EditProfileScreen(
            userProfile: args.userProfile,
            hallOfFame: args.hallOfFame,
          ),
        );

      case AppRoutes.appearance:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const AppearanceScreen(),
        );

      case AppRoutes.notifications:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const NotificationsScreen(),
        );

      case AppRoutes.integrations:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const IntegrationsScreen(),
        );

      case AppRoutes.info:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const InfoScreen(),
        );

      case AppRoutes.homeAppearance:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const HomeAppearanceScreen(),
        );

      case AppRoutes.infoTabAppearance:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const InfoTabAppearanceScreen(),
        );

      case AppRoutes.achievements:
        final args = settings.arguments! as AchievementsArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => AchievementsScreen(
            userId: args.userId,
            initialXp: args.initialXp,
          ),
        );

      case AppRoutes.achievementGames:
        final args = settings.arguments! as AchievementGamesArgs;
        return MaterialPageRoute<T>(
          settings: settings,
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

      case AppRoutes.groupGames:
        final args = settings.arguments! as GroupGamesArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => GroupGamesScreen(
            title: args.title,
            collectionId: args.collectionId,
            isFranchise: args.isFranchise,
            isCompany: args.isCompany,
          ),
        );

      case AppRoutes.hallOfFameSelector:
        final args = settings.arguments! as HallOfFameSelectorArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => HallOfFameSelectorScreen(pinOrder: args.pinOrder),
        );

      case AppRoutes.login:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );

      case AppRoutes.register:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const RegisterScreen(),
        );

      case AppRoutes.steamImportProgress:
        final args = settings.arguments! as SteamImportProgressArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => SteamImportProgressScreen(
            minPlaytimeMinutes: args.minPlaytimeMinutes,
          ),
        );

      case AppRoutes.importPreview:
        final args = settings.arguments! as ImportPreviewArgs;
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => ImportPreviewScreen(rows: args.rows),
        );

      case AppRoutes.design:
        return MaterialPageRoute<T>(
          settings: settings,
          builder: (_) => const DesignScreen(),
        );

      default:
        throw FlutterError('Ruta no registrada: ${settings.name}');
    }
  }
}

// ── Extensión de navegación ────────────────────────────────────────────────────

extension CorpusNavigation on BuildContext {
  Future<T?> pushRoute<T>(String name, {Object? arguments}) {
    return Navigator.push<T>(
      this,
      CorpusRouter.route<T>(RouteSettings(name: name, arguments: arguments)),
    );
  }

  Future<T?> pushReplacementRoute<T, TO>(String name, {Object? arguments}) {
    return Navigator.pushReplacement<T, TO>(
      this,
      CorpusRouter.route<T>(RouteSettings(name: name, arguments: arguments)),
    );
  }

  Future<T?> pushGameDetails<T>(
    Map<String, dynamic> gameData, {
    bool autoOpenReview = false,
    ScrollController? scrollController,
  }) {
    return pushRoute<T>(
      AppRoutes.gameDetails,
      arguments: GameDetailsArgs(
        gameData: gameData,
        autoOpenReview: autoOpenReview,
        scrollController: scrollController,
      ),
    );
  }

  Future<T?> pushReviewDetails<T>(
    Map<String, dynamic> gameData,
    Map<String, dynamic>? userData,
    Map<String, dynamic> reviewData, {
    bool focusComment = false,
  }) {
    return pushRoute<T>(
      AppRoutes.reviewDetails,
      arguments: ReviewDetailsArgs(
        gameData: gameData,
        userData: userData,
        reviewData: reviewData,
        focusComment: focusComment,
      ),
    );
  }

  Future<T?> pushProfile<T>({String? userId}) {
    return pushRoute<T>(
      AppRoutes.profile,
      arguments: userId != null ? ProfileArgs(userId: userId) : null,
    );
  }

  Future<T?> pushSearch<T>({
    String? initialQuery,
    bool isSelectionMode = false,
  }) {
    return pushRoute<T>(
      AppRoutes.search,
      arguments: SearchArgs(
        initialQuery: initialQuery,
        isSelectionMode: isSelectionMode,
      ),
    );
  }

  Future<T?> pushFriends<T>() => pushRoute<T>(AppRoutes.friends);

  Future<T?> pushSettings<T>(
    Map<String, dynamic> userProfile,
    List<Map<String, dynamic>?> hallOfFame,
  ) {
    return pushRoute<T>(
      AppRoutes.settings,
      arguments: SettingsArgs(
        userProfile: userProfile,
        hallOfFame: hallOfFame,
      ),
    );
  }

  Future<T?> pushEditProfile<T>(
    Map<String, dynamic> userProfile,
    List<Map<String, dynamic>?> hallOfFame,
  ) {
    return pushRoute<T>(
      AppRoutes.editProfile,
      arguments: EditProfileArgs(
        userProfile: userProfile,
        hallOfFame: hallOfFame,
      ),
    );
  }

  Future<T?> pushAppearance<T>() => pushRoute<T>(AppRoutes.appearance);

  Future<T?> pushNotifications<T>() => pushRoute<T>(AppRoutes.notifications);

  Future<T?> pushIntegrations<T>() => pushRoute<T>(AppRoutes.integrations);

  Future<T?> pushInfo<T>() => pushRoute<T>(AppRoutes.info);

  Future<T?> pushHomeAppearance<T>() => pushRoute<T>(AppRoutes.homeAppearance);

  Future<T?> pushInfoTabAppearance<T>() =>
      pushRoute<T>(AppRoutes.infoTabAppearance);

  Future<T?> pushAchievements<T>(String userId, int initialXp) {
    return pushRoute<T>(
      AppRoutes.achievements,
      arguments: AchievementsArgs(userId: userId, initialXp: initialXp),
    );
  }

  Future<T?> pushAchievementGames<T>(AchievementGamesArgs args) {
    return pushRoute<T>(AppRoutes.achievementGames, arguments: args);
  }

  Future<T?> pushGroupGames<T>(
    String title,
    int collectionId, {
    bool isFranchise = false,
    bool isCompany = false,
  }) {
    return pushRoute<T>(
      AppRoutes.groupGames,
      arguments: GroupGamesArgs(
        title: title,
        collectionId: collectionId,
        isFranchise: isFranchise,
        isCompany: isCompany,
      ),
    );
  }

  Future<T?> pushHallOfFameSelector<T>(int pinOrder) {
    return pushRoute<T>(
      AppRoutes.hallOfFameSelector,
      arguments: HallOfFameSelectorArgs(pinOrder: pinOrder),
    );
  }

  Future<T?> pushLogin<T>() => pushRoute<T>(AppRoutes.login);

  Future<T?> pushRegister<T>() => pushRoute<T>(AppRoutes.register);

  Future<T?> pushSteamImportProgress<T>(int minPlaytimeMinutes) {
    return pushRoute<T>(
      AppRoutes.steamImportProgress,
      arguments: SteamImportProgressArgs(minPlaytimeMinutes: minPlaytimeMinutes),
    );
  }

  Future<T?> pushReplacementSteamImportProgress<T, TO>(
    int minPlaytimeMinutes,
  ) {
    return pushReplacementRoute<T, TO>(
      AppRoutes.steamImportProgress,
      arguments: SteamImportProgressArgs(minPlaytimeMinutes: minPlaytimeMinutes),
    );
  }

  Future<T?> pushImportPreview<T>(List<CsvGameRow> rows) {
    return pushRoute<T>(
      AppRoutes.importPreview,
      arguments: ImportPreviewArgs(rows: rows),
    );
  }

  Future<T?> pushDesign<T>() => pushRoute<T>(AppRoutes.design);
}
