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
import 'package:image_picker/image_picker.dart';
import '../../../repositories/review_repository.dart';
import '../../../models/models.dart';
import '../../../services/igdb_service.dart';
import '../../../services/duracionde_service.dart';

class GameDetailsController extends ChangeNotifier {
  GameDetailsController({required this.gameData}) : _repo = ReviewRepository();

  final Map<String, dynamic> gameData; // TODO(B-A1): reemplazar por GameModel
  final ReviewRepository _repo;

  bool _disposed = false;

  bool get isGuest => _repo.client.auth.currentUser == null;
  String? get currentUserId => _repo.client.auth.currentUser?.id;

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
  List<UserProfile> partnersData = [];
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
  int? metacriticUserRatingCount;
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

  /// Llamada segura a notifyListeners que no explota si el controller ya fue disposed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Sustituye a la lógica repartida en initState (líneas 131-180).
  /// Dispara todos los fetch iniciales y escucha cambios de sesión.
  ///
  /// Los fetches se agrupan en dos batches paralelos con [Future.wait]:
  /// - Batch "usuario": datos propios + reseñas + stash + amigos.
  /// - Batch "juego":  IGDB enrich + Metacritic + HLTB + relacionados.
  /// Esto reduce el tiempo de carga total al coste del fetch más lento
  /// de cada grupo, en lugar de la suma de todos.
  ///
  /// [onUserDataLoaded] se invoca después de fetchUserData para que el screen
  /// pueda actualizar TextEditingControllers u otros widgets propios.
  /// [onScreenshotsEnriched] se invoca cuando enrichGameData trae nuevos
  /// screenshots, para que el screen reinicie el carrusel.
  void init({
    VoidCallback? onUserDataLoaded,
    void Function(List enrichedScreenshots, bool forceInitialSwap)?
    onScreenshotsEnriched,
  }) {
    // ── Prefs (local, rápido, no bloquea) ──────────────────────────────────
    loadPreferences();

    // ── Batch "juego": no depende de auth ──────────────────────────────────
    Future.wait([
      enrichGameData(onScreenshotsEnriched: onScreenshotsEnriched),
      fetchMetacritic(),
      fetchTimeToBeat(),
      fetchRelatedGames(),
    ]);

    // ── Batch "usuario": solo si está autenticado ──────────────────────────
    if (isGuest) {
      isLoadingUserData = false;
      isLoadingStashReviews = false;
      isLoadingStashStats = false;
      _notify();
    } else {
      _fetchUserBatch(onUserDataLoaded: onUserDataLoaded);
    }

    // ── Listener de cambios de sesión ──────────────────────────────────────
    _authSub = _repo.client.auth.onAuthStateChange.listen((_) {
      if (_disposed || _repo.client.auth.currentUser == null) return;
      if (isLoadingUserData || userData != null) return;
      isLoadingUserData = true;
      isLoadingStashReviews = true;
      isLoadingStashStats = true;
      _notify();
      _fetchUserBatch(onUserDataLoaded: onUserDataLoaded);
    });
  }

  /// Lanza en paralelo todos los fetches que dependen del usuario autenticado.
  /// StashStats va con un delay de 400 ms para no saturar el Edge Function.
  Future<void> _fetchUserBatch({VoidCallback? onUserDataLoaded}) async {
    await Future.wait([
      fetchUserData().then((_) => onUserDataLoaded?.call()),
      fetchReviews(),
      fetchStashReviews(),
      fetchFriendsWithGame(),
    ]);
    // StashStats después: el Edge Function de Stash es sensible a la carga
    // simultánea y conviene darle un respiro mínimo.
    if (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_disposed) fetchStashStats();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Métodos de solo lectura (fetches)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Origen: _fetchMetacritic, líneas 190-251.
  Future<void> fetchMetacritic() async {
    final gameModel = Game.fromMap({...gameData, ...enrichedData});

    if (gameModel.hasRecentMetacriticData) {
      metacriticScore = gameModel.metacriticScore;
      metacriticUrl = gameModel.metacriticUrl;
      metacriticUserScore = gameModel.metacriticUserScore;
      _notify();
      return;
    }

    final title = gameModel.title;
    if (title.isEmpty) return;

    final gameId = gameData['id']?.toString();
    final cachedSlug =
        gameData['metacritic_slug'] ?? enrichedData['metacritic_slug'];

    isLoadingMetacritic = true;
    _notify();

    try {
      final payload = <String, dynamic>{'gameTitle': title.toString()};
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
        metacriticUserRatingCount = data['user_rating_count'] as int?;
      } else {
        debugPrint('[Metacritic] Error de la Edge Function: ${response.data}');
      }
    } catch (e) {
      debugPrint('[Metacritic] Excepción: $e');
    } finally {
      isLoadingMetacritic = false;
      _notify();
    }
  }

  /// Origen: _loadPreferences, líneas 253-296.
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
    _notify();
  }

  /// Origen: _fetchTimeToBeat, líneas 298-334.
  /// Incluye fallback de duracionde → IGDB si el primero no encuentra datos.
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

      if (ttb == null || ttb['found'] == false) {
        // Fallback silencioso a IGDB
        final igdbTtb = await IGDBService.getTimeToBeat(id);
        if (igdbTtb != null) {
          ttb = {...igdbTtb, '_source': 'igdb_fallback'};
        } else {
          ttb = null;
        }
      } else {
        ttb = {...ttb, '_source': 'duracionde'};
      }
    } else {
      final igdbTtb = await IGDBService.getTimeToBeat(id);
      if (igdbTtb != null) {
        ttb = {...igdbTtb, '_source': 'igdb'};
      }
    }

    if (ttb != null) {
      timeToBeat = ttb;
      _notify();
    }
  }

  /// Origen: _fetchRelatedGames, líneas 336-355.
  Future<void> fetchRelatedGames() async {
    final igdbId = gameData['igdb_id'] ?? gameData['id'];
    if (igdbId == null) {
      isLoadingRelated = false;
      _notify();
      return;
    }
    try {
      final results = await IGDBService.getRelatedGames(
        igdbId is int ? igdbId : int.parse(igdbId.toString()),
      );
      relatedGames = results;
    } catch (_) {
      // Silenciar error — los relacionados son opcionales
    } finally {
      isLoadingRelated = false;
      _notify();
    }
  }

  /// Origen: _fetchFriendsWithGame, líneas 358-373.
  Future<void> fetchFriendsWithGame() async {
    final gameId = gameData['igdb_id'] ?? gameData['id'];
    if (gameId == null) return;
    final myId = currentUserId;
    if (myId == null) return;

    try {
      final friends = await _repo.fetchFriendsWithGame(
        myId: myId,
        gameId: gameId,
      );
      friendsWithGame = friends;
      _notify();
    } catch (e) {
      debugPrint('[GameDetails] Error cargando amigos con el juego: $e');
    }
  }

  /// Origen: _enrichGameData, líneas 609-809.
  /// Llama a IGDB para completar campos que faltan (summary, developer, screenshots, etc.)
  /// y hace backfill a la tabla `games` si se resuelve un cover que faltaba.
  ///
  /// [onScreenshotsEnriched] se invoca con la lista de screenshots y si se
  /// debe forzar el swap inicial — el screen lo usa para reiniciar el carrusel.
  Future<void> enrichGameData({
    void Function(List enrichedScreenshots, bool forceInitialSwap)?
    onScreenshotsEnriched,
  }) async {
    final hasSummary =
        gameData['summary'] != null &&
        gameData['summary'].toString() != 'null' &&
        gameData['summary'].toString().isNotEmpty;
    final hasDeveloper =
        gameData['developer'] != null &&
        gameData['developer'] != 'Desconocido' &&
        gameData['developer'] != 'Desarrollador desconocido';
    final hasCategory = gameData['category'] != null;
    final hasScreenshots =
        (gameData['screenshots'] as List?)?.isNotEmpty == true;

    final hasGameEngines =
        (gameData['game_engines'] as List?)
            ?.where(
              (e) =>
                  e != null &&
                  e.toString() != 'null' &&
                  e.toString().isNotEmpty,
            )
            .isNotEmpty ==
        true;
    final hasCollection =
        gameData['collection'] != null &&
        gameData['collection'].toString() != 'null' &&
        gameData['collection'].toString().isNotEmpty;
    final hasFranchises =
        (gameData['franchises'] as List?)
            ?.where(
              (f) =>
                  f != null &&
                  f.toString() != 'null' &&
                  f.toString().isNotEmpty,
            )
            .isNotEmpty ==
        true;

    // Solo omitir la llamada si tenemos TODOS los datos (primarios + secundarios)
    if (hasSummary &&
        hasDeveloper &&
        hasCategory &&
        hasScreenshots &&
        hasGameEngines &&
        hasCollection &&
        hasFranchises) {
      isEnriching = false;
      _notify();
      return;
    }

    final igdbId = gameData['igdb_id'] ?? gameData['id'];
    if (igdbId == null) {
      isEnriching = false;
      _notify();
      return;
    }

    try {
      final game = await IGDBService.getGameById(
        igdbId is int ? igdbId : int.parse(igdbId.toString()),
      );
      if (game != null && !_disposed) {
        // Extraer desarrollador
        String? developer;
        int? developerId;
        // Extraer publisher (principal)
        String? publisher;
        int? publisherId;
        if (game['involved_companies'] != null &&
            (game['involved_companies'] as List).isNotEmpty) {
          final companies = game['involved_companies'] as List;
          try {
            final dev = companies.firstWhere((c) => c['developer'] == true);
            developer = dev['company']['name'];
            developerId = dev['company']['id'];
          } catch (_) {
            try {
              developer = companies[0]['company']['name'];
              developerId = companies[0]['company']['id'];
            } catch (_) {}
          }
          try {
            final pub = companies.firstWhere((c) => c['publisher'] == true);
            publisher = pub['company']['name'];
            publisherId = pub['company']['id'];
          } catch (_) {
            // No hay publisher marcado explícitamente: lo dejamos vacío en
            // lugar de asumir uno, para no mostrar datos incorrectos.
          }
          // Si el publisher coincide con el developer, no lo mostramos aparte
          // (evita duplicar "Nintendo · Nintendo" en la UI).
          if (publisher != null &&
              developer != null &&
              publisher.toString().trim().toLowerCase() ==
                  developer.toString().trim().toLowerCase()) {
            publisher = null;
            publisherId = null;
          }
        }

        // Poblar enrichedData con TODOS los campos de IGDB.
        enrichedData = {
          if (game['summary'] != null) 'summary': game['summary'],
          'developer': developer,
          'developer_id': developerId,
          'publisher': publisher,
          'publisher_id': publisherId,
          if (game['name'] != null) 'title': game['name'],
          if (game['cover'] != null)
            'cover_url': IGDBService.getCoverUrl(game['cover']['image_id']),
          if (game['first_release_date'] != null)
            'release_date': DateTime.fromMillisecondsSinceEpoch(
              game['first_release_date'] * 1000,
            ).toIso8601String(),
          if (game['category'] != null) 'category': game['category'],
          if (game['game_type'] != null) 'game_type': game['game_type'],
          if (game['parent_game'] != null) 'parent_game': game['parent_game'],
          if (game['version_parent'] != null)
            'version_parent': game['version_parent'],
          if (game['remake_of'] != null) 'remake_of': game['remake_of'],
          if (game['remaster_of'] != null) 'remaster_of': game['remaster_of'],
          if (game['aggregated_rating'] != null)
            'aggregated_rating': game['aggregated_rating'],
          'platforms': game['platforms'] != null
              ? (game['platforms'] as List).map((p) => p['name']).toList()
              : [],
          'genres': game['genres'] != null
              ? (game['genres'] as List).map((g) => g['name']).toList()
              : [],
          'screenshots': game['screenshots'] != null
              ? (game['screenshots'] as List).map((s) => s['image_id']).toList()
              : [],
          'artworks': game['artworks'] != null
              ? (game['artworks'] as List).map((a) => a['image_id']).toList()
              : [],
          'videos': game['videos'] != null
              ? (game['videos'] as List).map((v) => v['video_id']).toList()
              : [],
          'themes': game['themes'] != null
              ? (game['themes'] as List).map((t) => t['name']).toList()
              : [],
          'game_modes': game['game_modes'] != null
              ? (game['game_modes'] as List).map((m) => m['name']).toList()
              : [],
          'player_perspectives': game['player_perspectives'] != null
              ? (game['player_perspectives'] as List)
                    .map((p) => p['name'])
                    .toList()
              : [],
          'websites': game['websites'] != null
              ? (game['websites'] as List)
                    .map(
                      (w) => {
                        'url': w['url'],
                        'category': w['type'] ?? w['category'],
                      },
                    )
                    .toList()
              : [],
          if (game['collection'] != null)
            'collection': {
              'id': game['collection']['id'],
              'name': game['collection']['name'],
            },
          'franchises': game['franchises'] != null
              ? (game['franchises'] as List)
                    .map((f) => {'id': f['id'], 'name': f['name']})
                    .toList()
              : [],
          'game_engines': game['game_engines'] != null
              ? (game['game_engines'] as List).map((e) => e['name']).toList()
              : [],
        };
        _notify();

        // Backfill perezoso: si la fila de `games` no tenía cover_url (u otros
        // campos clave) y ahora los hemos resuelto vía IGDB, los persistimos
        // para que listas y carruseles dejen de mostrar el placeholder.
        final bool missingCoverInDb =
            gameData['cover_url'] == null ||
            gameData['cover_url'].toString().isEmpty;

        if (missingCoverInDb && enrichedData['cover_url'] != null) {
          try {
            await Supabase.instance.client
                .from('games')
                .update({
                  'cover_url': enrichedData['cover_url'],
                  if (enrichedData['summary'] != null)
                    'summary': enrichedData['summary'],
                  if (enrichedData['developer'] != null)
                    'developer': enrichedData['developer'],
                })
                .eq('igdb_id', igdbId);
          } catch (e) {
            debugPrint('[CORPUS DEBUG] Error en backfill de cover_url: $e');
          }
        }

        // Notificar al screen para que maneje el carrusel de screenshots
        final List enrichedScreenshots = enrichedData['screenshots'] ?? [];
        if (enrichedScreenshots.isNotEmpty) {
          onScreenshotsEnriched?.call(enrichedScreenshots, true);
        }
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error enriching game data: $e');
    } finally {
      isEnriching = false;
      _notify();
    }
  }

  /// Origen: _fetchUserData, líneas 1009-1049.
  /// Carga el estado del juego en la biblioteca del usuario (status, rating, etc.)
  ///
  /// Nota: el screen debe reaccionar a los cambios para actualizar
  /// TextEditingControllers (_commentController, _ratingController) ya que esos
  /// son objetos de UI que no pertenecen al controller.
  Future<void> fetchUserData() async {
    final userId = currentUserId;
    if (userId == null) return;
    final igdbId = gameData['igdb_id'] ?? gameData['id'];

    try {
      final response = await _repo.fetchUserGame(
        userId: userId,
        gameId: igdbId,
      );

      if (response != null && !_disposed) {
        inLibrary = true;
        status = response['status'] ?? 'wishlist';
        rating = (response['rating'] ?? 0).toDouble();
        ratingGameplay = (response['rating_gameplay'] ?? 0).toDouble();
        ratingNarrative = (response['rating_narrative'] ?? 0).toDouble();
        ratingSoundtrack = (response['rating_soundtrack'] ?? 0).toDouble();
        ratingVisuals = (response['rating_visuals'] ?? 0).toDouble();
        if (response['users'] != null) {
          userData = UserProfile.fromMap(response['users']);
        }
        if (response['partners'] != null && response['partners'] is List) {
          partnersData = (response['partners'] as List)
              .whereType<Map<String, dynamic>>()
              .map((p) => UserProfile.fromMap(p))
              .toList();
        }
      } else if (!_disposed) {
        final userResp = await _repo.fetchUserProfile(userId);
        userData = userResp;
      }
    } catch (e) {
      debugPrint('[CORPUS] ERROR en fetchUserData: $e');
    } finally {
      isLoadingUserData = false;
      _notify();
    }
  }

  /// Origen: _fetchReviews, líneas 1051-1061.
  Future<void> fetchReviews() async {
    final userId = currentUserId;
    if (userId == null) return;
    final igdbId = gameData['igdb_id'] ?? gameData['id'];

    try {
      final result = await _repo.fetchReviews(userId: userId, gameId: igdbId);
      reviews = result;
      _notify();
    } catch (e) {
      debugPrint('[CORPUS] Error fetching reviews: $e');
    }
  }

  /// Origen: _fetchStashReviews, líneas 1063-1089.
  Future<void> fetchStashReviews() async {
    final igdbId = gameData['igdb_id'] ?? gameData['id'];
    if (igdbId == null) return;

    try {
      final local = await _repo.fetchStashReviewsLocal(igdbId);
      stashReviews = local.reviews;
      isLoadingStashReviews = local.needsFetch;
      _notify();

      if (local.needsFetch) {
        final updated = await _repo.refreshStashReviews(igdbId);
        if (updated != null) stashReviews = updated;
        isLoadingStashReviews = false;
        _notify();
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error fetching stash reviews: $e');
      isLoadingStashReviews = false;
      _notify();
    }
  }

  /// Origen: _fetchStashStats, líneas 1091-1117.
  Future<void> fetchStashStats() async {
    final igdbId = gameData['igdb_id'] ?? gameData['id'];
    if (igdbId == null) return;

    try {
      final local = await _repo.fetchStashStatsLocal(igdbId);
      stashStats = local.stats;
      isLoadingStashStats = local.needsFetch;
      _notify();

      if (local.needsFetch) {
        final updated = await _repo.refreshStashStats(igdbId);
        if (updated != null) stashStats = updated;
        isLoadingStashStats = false;
        _notify();
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error fetching stash stats: $e');
      isLoadingStashStats = false;
      _notify();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Métodos de escritura (mutación de BD)
  // ═══════════════════════════════════════════════════════════════════════════
  // TODO(B-C2 Fase 4): Portar saveReview, deleteFromLibrary, deleteReview
  // desde game_details_screen.dart una vez que los fetches estén estabilizados
  // y testeados. Los métodos de escritura van últimos porque son los que más
  // riesgo tienen de romper datos.

  /// Origen: parte lógica (sin el modal) de _saveReview, líneas 1140-1350+.
  Future<SaveReviewResult> saveReview({
    String? reviewId,
    required double rating,
    required double ratingGameplay,
    required double ratingNarrative,
    required double ratingSoundtrack,
    required double ratingVisuals,
    required String comment,
    required String status,
    required String completionType,
    required bool isReplay,
    required int? replayNumber,
    required String? platform,
    required double? playTimeHours,
    required DateTime? playedFrom,
    required DateTime? playedUntil,
    required int? progressPercent,
    required DateTime? reviewDate,
    required List<XFile> newImages,
    required List<String> existingImages,
    required List<String> partnerIds,
  }) async {
    if (isSaving) throw Exception('Already saving');
    isSaving = true;
    _notify();

    final userId = currentUserId;
    if (userId == null) {
      isSaving = false;
      _notify();
      throw Exception('Not logged in');
    }
    final igdbId = gameData['igdb_id'] ?? gameData['id'];

    try {
      final result = await _repo.saveReview(
        userId: userId,
        igdbId: igdbId,
        gameData: gameData,
        enrichedData: enrichedData,
        reviewId: reviewId,
        rating: rating,
        ratingGameplay: ratingGameplay,
        ratingNarrative: ratingNarrative,
        ratingSoundtrack: ratingSoundtrack,
        ratingVisuals: ratingVisuals,
        comment: comment,
        status: status,
        completionType: completionType,
        isReplay: isReplay,
        replayNumber: replayNumber,
        platform: platform,
        playTimeHours: playTimeHours,
        playedFrom: playedFrom,
        playedUntil: playedUntil,
        progressPercent: progressPercent,
        reviewDate: reviewDate,
        newImages: newImages,
        existingImages: existingImages,
        partnerIds: partnerIds,
      );

      inLibrary = true;
      this.status = status;
      this.rating = rating;
      this.ratingGameplay = ratingGameplay;
      this.ratingNarrative = ratingNarrative;
      this.ratingSoundtrack = ratingSoundtrack;
      this.ratingVisuals = ratingVisuals;

      // Fetch reviews without awaiting, as in the screen logic
      fetchReviews();

      return result;
    } finally {
      isSaving = false;
      _notify();
    }
  }

  Future<void> deleteFromLibrary() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final igdbId = gameData['igdb_id'] ?? gameData['id'];

    await _repo.deleteFromLibrary(userId: userId, gameId: igdbId);

    reviews.clear();
    inLibrary = false;
    status = 'wishlist';
    rating = 0;
    ratingGameplay = 0;
    ratingNarrative = 0;
    ratingSoundtrack = 0;
    ratingVisuals = 0;
    _notify();
  }

  Future<bool> deleteReview(Review review) async {
    final gameId = gameData['igdb_id'] ?? gameData['id'];
    final removedFromLibrary = await _repo.deleteReview(
      reviewId: review.id,
      reviewData: review,
      gameId: gameId,
    );

    reviews.removeWhere((r) => r.id == review.id);
    if (removedFromLibrary) inLibrary = false;
    _notify();
    return removedFromLibrary;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers de UI del tab Info
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reordena las secciones del tab Info y persiste el orden.
  Future<void> reorderInfoTab(List<String> newOrder) async {
    infoTabOrder = newOrder;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('info_tab_order', newOrder);
  }

  /// Alterna la visibilidad de una sección del tab Info y persiste.
  Future<void> toggleInfoSection(String key) async {
    if (!infoTabHidden.add(key)) infoTabHidden.remove(key);
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('info_tab_hidden', infoTabHidden.toList());
  }
}
