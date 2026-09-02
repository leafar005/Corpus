import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/igdb_service.dart';

// ─── Modelos de datos por fase ──────────────────────────────────────────────

/// Datos que llegan rápido: Supabase del usuario + SharedPreferences.
class HomePhaseOneData {
  const HomePhaseOneData({
    required this.games,
    required this.displayName,
    required this.sectionsOrder,
    required this.sectionsHidden,
    required this.anticipatedCountdownStyle,
    required this.wishlistCountdownStyle,
    required this.bundlesEndingSoonDays,
  });

  final List<Map<String, dynamic>> games;
  final String displayName;
  final List<String> sectionsOrder;
  final Set<String> sectionsHidden;
  final String anticipatedCountdownStyle;
  final String wishlistCountdownStyle;
  final int bundlesEndingSoonDays;
}

/// Datos que tardan más: IGDB + reseñas globales + wishlist anticipated.
class HomePhaseTwoData {
  const HomePhaseTwoData({
    required this.anticipatedGames,
    required this.latestReviews,
    required this.wishlistAnticipatedGames,
    required this.bundlesEndingSoon,
  });

  final List<dynamic> anticipatedGames;
  final List<Map<String, dynamic>> latestReviews;
  final List<dynamic> wishlistAnticipatedGames;
  final List<Map<String, dynamic>> bundlesEndingSoon;
}

// ────────────────────────────────────────────────────────────────────────────

/// Controller para [HomeScreen].
///
/// Encapsula `_fetchPhaseOne` y `_fetchPhaseTwo`, que antes vivían directamente
/// en `_HomeScreenState`. La pantalla se queda solo con los `ScrollController`
/// y los `ValueNotifier` de scroll arrows (estado puramente de UI).
///
/// Expone las dos fases como [phaseOneFuture] (para el FutureBuilder existente)
/// y las propiedades [phaseTwoData] / [phaseTwoLoaded] que se actualizan con
/// `notifyListeners` cuando la fase 2 termina.
class HomeController extends ChangeNotifier {
  HomeController();

  final _client = Supabase.instance.client;
  bool _disposed = false;

  // ── Estado público ─────────────────────────────────────────────────────────

  /// Future que resuelve cuando la Fase 1 completa. Se reemplaza en [reload].
  late Future<HomePhaseOneData> phaseOneFuture;

  HomePhaseTwoData? phaseTwoData;
  bool phaseTwoLoaded = false;

  bool get isGuest => _client.auth.currentUser == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Ciclo de carga ─────────────────────────────────────────────────────────

  /// Inicia (o reinicia) la carga de ambas fases.
  void reload() {
    phaseTwoData = null;
    phaseTwoLoaded = false;
    phaseOneFuture = _fetchPhaseOne();

    // La Fase 2 se lanza en paralelo; cuando termina, notifica a la UI.
    _fetchPhaseTwo().then((data) {
      if (_disposed) return;
      phaseTwoData = data;
      phaseTwoLoaded = true;
      _notify();
    });

    _notify();
  }

  // ── FASE 1 ─────────────────────────────────────────────────────────────────

  Future<HomePhaseOneData> _fetchPhaseOne() async {
    final currentUser = _client.auth.currentUser;
    final prefsFuture = SharedPreferences.getInstance();

    String displayName = '';
    List<Map<String, dynamic>> games = [];

    if (currentUser != null) {
      final userId = currentUser.id;

      final results =
          await Future.wait<dynamic>([
            _client
                .from('users')
                .select('display_name, username')
                .eq('id', userId)
                .maybeSingle(),
            _client
                .from('user_games')
                .select('*, games(*)')
                .eq('user_id', userId)
                .eq('status', 'playing'),
            _client
                .from('reviews')
                .select('game_id')
                .eq('user_id', userId)
                .eq('status', 'playing')
                .eq('completion_type', 'on_hold'),
          ]).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'HomeController: timeout al cargar datos del usuario (>20s)',
            ),
          );

      final userResp = results[0] as Map<String, dynamic>?;
      displayName = (userResp?['display_name'] as String?)?.isNotEmpty == true
          ? userResp!['display_name'] as String
          : (userResp?['username'] as String?)?.isNotEmpty == true
          ? userResp!['username'] as String
          : (currentUser.email?.split('@').first ?? 'tu');

      games = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);

      final onHoldReviews = results[2] as List<dynamic>;
      if (onHoldReviews.isNotEmpty) {
        final onHoldGameIds = onHoldReviews
            .map((r) => (r['game_id'] as num).toInt())
            .toSet();
        games.removeWhere(
          (g) => onHoldGameIds.contains((g['game_id'] as num).toInt()),
        );
      }

      // Screenshots: batch único de IGDB
      final igdbIds = games.map((g) => g['game_id'] as int).toList();
      if (igdbIds.isNotEmpty) {
        try {
          final igdbData = await IGDBService.getGamesByIds(igdbIds);
          final screenshotsMap = <int, List<String>>{};
          for (final item in igdbData) {
            final id = item['id'] as int;
            final screenshots = item['screenshots'] as List<dynamic>? ?? [];
            screenshotsMap[id] = screenshots
                .map(
                  (s) => IGDBService.getScreenshotUrl(s['image_id'] as String?),
                )
                .where((url) => url.isNotEmpty)
                .toList();
          }
          for (final game in games) {
            final id = game['game_id'] as int;
            game['screenshots_list'] = screenshotsMap[id] ?? [];
          }
        } catch (e) {
          debugPrint(
            '[HomeController] Error obteniendo capturas para inicio: $e',
          );
        }
      }
    }

    final prefs = await prefsFuture;
    final savedOrder =
        prefs.getStringList('home_sections_order') ??
        ['hero', 'stash_activity', 'anticipated_games'];
    final savedHidden = prefs.getStringList('home_sections_hidden') ?? [];
    final anticipatedCountdownStyle =
        prefs.getString('anticipated_countdown_style') ?? 'days_only';
    final wishlistCountdownStyle =
        prefs.getString('wishlist_countdown_style') ??
        prefs.getString('anticipated_countdown_style') ??
        'days_only';
    final bundlesEndingSoonDays =
        prefs.getInt('home_bundles_ending_soon_days') ?? 3;

    const defaultOrder = [
      'hero',
      'bundles_ending_soon',
      'stash_activity',
      'wishlist_anticipated',
      'anticipated_games',
    ];
    List<String> loadedOrder = List<String>.from(savedOrder);
    for (int i = 0; i < defaultOrder.length; i++) {
      if (!loadedOrder.contains(defaultOrder[i])) {
        loadedOrder.insert(i.clamp(0, loadedOrder.length), defaultOrder[i]);
      }
    }
    loadedOrder.removeWhere((key) => !defaultOrder.contains(key));

    return HomePhaseOneData(
      games: games,
      displayName: displayName,
      sectionsOrder: loadedOrder,
      sectionsHidden: savedHidden.toSet(),
      anticipatedCountdownStyle: anticipatedCountdownStyle,
      wishlistCountdownStyle: wishlistCountdownStyle,
      bundlesEndingSoonDays: bundlesEndingSoonDays,
    );
  }

  // ── FASE 2 ─────────────────────────────────────────────────────────────────

  Future<HomePhaseTwoData> _fetchPhaseTwo() async {
    final currentUser = _client.auth.currentUser;

    final anticipatedFuture = IGDBService.getMostAnticipatedGames().catchError((
      e,
    ) {
      debugPrint('[HomeController] Error anticipated games: $e');
      return <dynamic>[];
    });

    final reviewsFuture = currentUser != null
        ? _client
              .from('stash_community_reviews')
              .select('*, games(title, cover_url)')
              .eq('source_context', 'recent_activity_feed')
              .order('stash_created_at', ascending: false)
              .limit(25)
              .then((r) => List<Map<String, dynamic>>.from(r))
              .catchError((e) {
                debugPrint('[HomeController] Error reseñas globales: $e');
                return <Map<String, dynamic>>[];
              })
        : Future.value(<Map<String, dynamic>>[]);

    Future<List<dynamic>> wishlistFuture() async {
      if (currentUser == null) return [];
      try {
        final wishlistResp = await _client
            .from('user_games')
            .select('game_id')
            .eq('user_id', currentUser.id)
            .eq('status', 'wishlist');
        final wishlistGameIds = List<Map<String, dynamic>>.from(
          wishlistResp,
        ).map((g) => g['game_id'] as int).toList();
        if (wishlistGameIds.isEmpty) return [];
        return await IGDBService.getUpcomingGamesByIds(wishlistGameIds);
      } catch (e) {
        debugPrint('[HomeController] Error wishlist anticipados: $e');
        return [];
      }
    }

    Future<List<Map<String, dynamic>>> bundlesFuture() async {
      try {
        // Necesitamos bundlesEndingSoonDays de la Fase 1.
        final p1 = await phaseOneFuture;
        if (p1.sectionsHidden.contains('bundles_ending_soon')) return [];

        final limitDate = DateTime.now().add(
          Duration(days: p1.bundlesEndingSoonDays),
        );
        final resp = await _client
            .from('active_bundles')
            .select()
            .gte('end_date', DateTime.now().toIso8601String())
            .lte('end_date', limitDate.toIso8601String())
            .order('end_date', ascending: true);
        return List<Map<String, dynamic>>.from(resp);
      } catch (e) {
        debugPrint('[HomeController] Error bundles por terminar: $e');
        return [];
      }
    }

    List<dynamic> anticipatedResult = [];
    List<Map<String, dynamic>> reviewsResult = [];
    List<dynamic> wishlistResult = [];
    List<Map<String, dynamic>> bundlesResult = [];

    await Future.wait([
      anticipatedFuture.then((v) => anticipatedResult = v),
      reviewsFuture.then((v) => reviewsResult = v),
      wishlistFuture().then((v) => wishlistResult = v),
      bundlesFuture().then((v) => bundlesResult = v),
    ]);

    return HomePhaseTwoData(
      anticipatedGames: anticipatedResult,
      latestReviews: reviewsResult,
      wishlistAnticipatedGames: wishlistResult,
      bundlesEndingSoon: bundlesResult,
    );
  }
}
