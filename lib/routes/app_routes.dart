/// Rutas nombradas de la aplicación.
abstract final class AppRoutes {
  // Pestañas principales (navegadores anidados en MainScreen)
  static const tabHome = '/tab/home';
  static const tabSearch = '/tab/search';
  static const tabActivity = '/tab/activity';
  static const tabBundles = '/tab/bundles';
  static const tabProfile = '/tab/profile';

  // Rutas públicas en la URL del navegador (web)
  static const publicHome = '/inicio';
  static const publicSearch = '/buscar';
  static const publicActivity = '/actividad';
  static const publicBundles = '/bundles';
  static const publicProfile = '/perfil';

  /// Índice de pestaña → path público para la barra de direcciones.
  static String publicPathForTab(int index) {
    return switch (index) {
      0 => publicHome,
      1 => publicSearch,
      2 => publicActivity,
      3 => publicBundles,
      4 => publicProfile,
      _ => publicHome,
    };
  }

  /// Path público → índice de pestaña. Devuelve null si no es una pestaña.
  static int? tabIndexFromPublicPath(String pathname) {
    final segments = _pathSegments(pathname);
    final segment = segments.isEmpty ? '' : segments.first;

    return switch (segment) {
      '' || 'inicio' => 0,
      'buscar' => 1,
      'actividad' => 2,
      'bundles' => 3,
      'perfil' => 4,
      _ => null,
    };
  }

  /// Segmentos del path posteriores a la raíz de la pestaña, es decir, la
  /// sub-ruta dentro de esa pestaña (ficha de juego, perfil, reseña...).
  /// Para `/buscar/1942` devuelve `['1942']`; para `/buscar` o `/` devuelve
  /// `[]`. Ver lib/routes/tab_deep_route.dart para cómo se interpretan.
  static List<String> subSegmentsFromPublicPath(String pathname) {
    final segments = _pathSegments(pathname);
    return segments.length > 1 ? segments.sublist(1) : const [];
  }

  static List<String> _pathSegments(String pathname) {
    return pathname
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // Pantallas de la app
  static const gameDetails = '/game-details';
  static const reviewDetails = '/review-details';
  static const profile = '/profile';
  static const search = '/search';
  static const friends = '/friends';
  static const settings = '/settings';
  static const editProfile = '/edit-profile';
  static const appearance = '/appearance';
  static const notifications = '/notifications';
  static const notificationsFeed = '/notifications-feed';
  static const integrations = '/integrations';
  static const info = '/info';
  static const homeAppearance = '/home-appearance';
  static const infoTabAppearance = '/info-tab-appearance';
  static const achievements = '/achievements';
  static const achievementGames = '/achievement-games';
  static const groupGames = '/group-games';
  static const hallOfFameSelector = '/hall-of-fame-selector';
  static const login = '/login';
  static const register = '/register';
  static const steamImportProgress = '/steam-import-progress';
  static const importPreview = '/import-preview';
  static const design = '/design';
}
