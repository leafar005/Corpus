// Fase 2 del refactor B-C2.
// Todo el estado remoto (fetches, ratings, prefs) y su lógica, sacado de
// _GameDetailsScreenState. Ningún método de aquí debe tocar BuildContext ni
// Navigator: eso se queda en game_details_screen.dart.
//
// Regla de migración: cada `setState(() { campo = valor; })` del original
// pasa a ser `campo = valor;` seguido de una única llamada a
// `notifyListeners()` al final del método (no una por campo).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../repositories/review_repository.dart';
import '../../../models/models.dart';
import '../../../services/igdb_service.dart';
import '../../../services/duracionde_service.dart';

class GameDetailsController extends ChangeNotifier {
  GameDetailsController({required this.gameData}) : _repo = ReviewRepository();

  final Map<String, dynamic> gameData; // TODO(B-A1): reemplazar por GameModel
  final ReviewRepository _repo;

  // Cache de metacritic eliminada a favor de GameModel

  bool get isGuest => _repo.client.auth.currentUser == null;

  // ---- Estado de biblioteca / review propia ----------------------------
  bool isSaving = false;
  bool inLibrary = false;
  String status = 'wishlist';
  double rating = 0;
  double ratingGameplay = 0;
  double ratingNarrative = 0;
  double ratingSoundtrack = 0;
  double ratingVisuals = 0;
  bool isLoadingUserData = true;
  UserProfile? userData;
  UserProfile? partnerData;
  List<Review> reviews = [];

  // ---- Datos enriquecidos desde IGDB ------------------------------------
  bool isEnriching = true;
  Map<String, dynamic> enrichedData = {};

  // ---- HowLongToBeat -----------------------------------------------------
  Map<String, dynamic>? timeToBeat;

  // ---- Metacritic ----------------------------------------------------------
  int? metacriticScore;
  String? metacriticUrl;
  double? metacriticUserScore;
  int? metacriticCriticCount;
  bool isLoadingMetacritic = false;

  // ---- Relacionados --------------------------------------------------------
  List<dynamic> relatedGames = [];
  bool isLoadingRelated = true;

  // ---- Stash (comunidad) ----------------------------------------------------
  List<Map<String, dynamic>> stashReviews = [];
  bool isLoadingStashReviews = true;
  int stashReviewLimit = 5;
  Map<String, dynamic>? stashStats;
  bool isLoadingStashStats = true;

  // ---- Amigos con el juego ---------------------------------------------------
  List<Map<String, dynamic>> friendsWithGame = [];

  // ---- Preferencias del tab Info --------------------------------------------
  bool localizeLinks = true;
  List<String> infoTabOrder = const [
    'genres_themes',
    'platforms',
    'metacritic',
    'stash_stats',
    'summary',
    'hltb',
    'engine',
  ];
  Set<String> infoTabHidden = {};

  StreamSubscription<AuthState>? _authSub;

  /// Sustituye a la lógica repartida en initState (líneas 131-180) que
  /// dispara todos los fetch iniciales y escucha cambios de sesión.
  void init({bool autoOpenReview = false, VoidCallback? onAutoOpenReview}) {
    // TODO: portar el cuerpo de initState (sin la parte de _scrollController
    // ni _startCarousel, que se quedan en GameHeroSection/screen).
    throw UnimplementedError();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Origen: _fetchMetacritic, líneas 186-272.
  Future<void> fetchMetacritic() async {
    final gameModel = Game.fromMap({...gameData, ...enrichedData});

    if (gameModel.hasRecentMetacriticData) {
      metacriticScore = gameModel.metacriticScore;
      metacriticUrl = gameModel.metacriticUrl;
      metacriticUserScore = gameModel.metacriticUserScore;
      notifyListeners();
      return;
    }

    final title = gameModel.title;
    if (title.isEmpty) return;

    final gameId = gameData['id']?.toString();
    final cachedSlug =
        gameData['metacritic_slug'] ?? enrichedData['metacritic_slug'];

    isLoadingMetacritic = true;
    notifyListeners();

    try {
      final payload = <String, dynamic>{'gameTitle': title};
      if (gameId != null) payload['gameId'] = gameId;
      if (cachedSlug != null) payload['metacriticSlug'] = cachedSlug.toString();

      final response = await _repo.client.functions.invoke(
        'get-metacritic-score',
        body: payload,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        metacriticScore = data['metascore'] as int?;
        metacriticUrl = data['url'] as String?;
        metacriticUserScore = data['user_score'] != null
            ? (data['user_score'] as num).toDouble()
            : null;
        metacriticCriticCount = data['critic_review_count'] as int?;
      }
    } catch (e) {
      debugPrint('[Metacritic] Excepción: $e');
    } finally {
      isLoadingMetacritic = false;
      notifyListeners();
    }
  }

  /// Origen: _loadPreferences, líneas 273-317.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('info_tab_order');
    final savedHidden = prefs.getStringList('info_tab_hidden') ?? [];

    const defaultOrder = [
      'franchise',
      'genres_themes',
      'platforms',
      'metacritic',
      'stash_stats',
      'summary',
      'hltb',
      'engine',
    ];

    List<String> loadedOrder = [];
    if (savedOrder != null && savedOrder.isNotEmpty) {
      loadedOrder = List<String>.from(savedOrder);
      for (int i = 0; i < defaultOrder.length; i++) {
        final key = defaultOrder[i];
        if (!loadedOrder.contains(key)) {
          loadedOrder.insert(i.clamp(0, loadedOrder.length), key);
        }
      }
      loadedOrder.removeWhere((key) => !defaultOrder.contains(key));
    } else {
      loadedOrder = List<String>.from(defaultOrder);
    }

    final newLocalize = prefs.getBool('localize_links') ?? true;
    final newHidden = savedHidden.toSet();

    localizeLinks = newLocalize;
    infoTabOrder = loadedOrder;
    infoTabHidden = newHidden;
    notifyListeners();
  }

  /// Origen: _fetchTimeToBeat, líneas 318-355.
  Future<void> fetchTimeToBeat() async {
    final igdbId = gameData['igdb_id'] ?? gameData['id'];
    if (igdbId == null) return;
    final id = igdbId is int ? igdbId : int.parse(igdbId.toString());

    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString('time_source_pref') ?? 'igdb';

    Map<String, dynamic>? ttb;

    if (source == 'duracionde') {
      final title = (gameData['title'] ?? gameData['name'] ?? '') as String;
      ttb = await DuracionDeService.getTimeToBeat(id, title: title);
    } else {
      ttb = await IGDBService.getTimeToBeat(id);
    }

    if (ttb != null) {
      timeToBeat = ttb;
      notifyListeners();
    }
  }

  /// Origen: _fetchRelatedGames, líneas 356-377.
  Future<void> fetchRelatedGames() async {
    throw UnimplementedError();
  }

  /// Origen: _fetchFriendsWithGame, líneas 378-428.
  Future<void> fetchFriendsWithGame() async {
    throw UnimplementedError();
  }

  /// Origen: _enrichGameData, líneas 629-872.
  Future<void> enrichGameData() async {
    throw UnimplementedError();
  }

  /// Origen: _fetchUserData, líneas 1002-1040.
  Future<void> fetchUserData() async {
    throw UnimplementedError();
  }

  /// Origen: _fetchReviews, líneas 1041-1052.
  Future<void> fetchReviews() async {
    throw UnimplementedError();
  }

  /// Origen: _fetchStashReviews, líneas 1053-1080.
  Future<void> fetchStashReviews() async {
    throw UnimplementedError();
  }

  /// Origen: _fetchStashStats, líneas 1081-1108.
  Future<void> fetchStashStats() async {
    throw UnimplementedError();
  }

  /// Origen: parte lógica (sin el modal) de _saveReview, líneas 1351-1555.
  Future<void> saveReview({
    required Review review, // TODO(B-A1): firma exacta según modelo tipado
  }) async {
    throw UnimplementedError();
  }

  /// Origen: _deleteFromLibrary, líneas 1556-1614.
  Future<void> deleteFromLibrary() async {
    throw UnimplementedError();
  }

  /// Origen: _deleteReview, líneas 1615-1663.
  Future<void> deleteReview(Review review) async {
    throw UnimplementedError();
  }

  /// Origen: reordenar dentro de _loadPreferences / UI del tab Info.
  void reorderInfoTab(List<String> newOrder) {
    infoTabOrder = newOrder;
    notifyListeners();
    // TODO: persistir con SharedPreferences igual que _loadPreferences.
  }

  void toggleInfoSection(String key) {
    if (!infoTabHidden.add(key)) infoTabHidden.remove(key);
    notifyListeners();
    // TODO: persistir con SharedPreferences.
  }
}
