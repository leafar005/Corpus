import 'package:flutter/material.dart';
import 'game_details/game_details_controller.dart';
import 'game_details/game_links_tab.dart';
import 'game_details/game_related_tab.dart';
import 'game_details/game_media_tab.dart';
import 'game_details/game_stash_tab.dart';
import 'game_details/game_info_tab.dart';
import 'game_details/game_hero_section.dart';
import 'dart:async';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:corpus/globals.dart';
import '../../services/igdb_service.dart';
import '../../utils/igdb_constants.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../library/review_modal.dart';
import '../../widgets/achievement_toast.dart';
import '../../models/models.dart';
import '../../utils/format_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final ScrollController? scrollController;
  final bool autoOpenReview;

  const GameDetailsScreen({
    super.key,
    required this.gameData,
    this.scrollController,
    this.autoOpenReview = false,
  });

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  late final GameDetailsController _controller;
  bool _isSaving = false;
  String? _selectedScreenshotUrl;
  int _selectedMainTabIndex = 0;

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();

  Timer? _carouselTimer;
  late final ScrollController _scrollController;
  double _scrollOffset = 0.0;

  // Delegate getters & setters to _controller for UI backwards compatibility
  bool get _isGuest => _controller.isGuest;
  bool get _inLibrary => _controller.inLibrary;
  String get _status => _controller.status;
  double get _rating => _controller.rating;
  double get _ratingGameplay => _controller.ratingGameplay;
  double get _ratingNarrative => _controller.ratingNarrative;
  double get _ratingSoundtrack => _controller.ratingSoundtrack;
  double get _ratingVisuals => _controller.ratingVisuals;

  UserProfile? get _userData => _controller.userData;
  List<UserProfile> get _partnersData => _controller.partnersData;
  List<Review> get _reviews => _controller.reviews;
  bool get _isEnriching => _controller.isEnriching;
  Map<String, dynamic> get _enrichedData => _controller.enrichedData;
  Map<String, dynamic>? get _timeToBeat => _controller.timeToBeat;
  int? get _metacriticScore => _controller.metacriticScore;
  String? get _metacriticUrl => _controller.metacriticUrl;
  double? get _metacriticUserScore => _controller.metacriticUserScore;
  int? get _metacriticCriticCount => _controller.metacriticCriticCount;
  int? get _metacriticUserRatingCount => _controller.metacriticUserRatingCount;
  bool get _isLoadingMetacritic => _controller.isLoadingMetacritic;
  List<dynamic> get _relatedGames => _controller.relatedGames;
  List<Map<String, dynamic>> get _stashReviews => _controller.stashReviews;
  bool get _isLoadingStashReviews => _controller.isLoadingStashReviews;
  Map<String, dynamic>? get _stashStats => _controller.stashStats;
  bool get _isLoadingStashStats => _controller.isLoadingStashStats;
  List<Map<String, dynamic>> get _friendsWithGame =>
      _controller.friendsWithGame;
  List<String> get _infoTabOrder => _controller.infoTabOrder;
  Set<String> get _infoTabHidden => _controller.infoTabHidden;

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    if ((offset - _scrollOffset).abs() > 2.0) {
      setState(() {
        _scrollOffset = offset;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = GameDetailsController(gameData: widget.gameData);
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);

    _controller.init(
      onUserDataLoaded: () {
        if (!mounted) return;
        if (_controller.rating > 0) {
          _ratingController.text = formatRating(_controller.rating);
        }
        if (widget.autoOpenReview && mounted) {
          _showReviewModal();
        }
      },
      onScreenshotsEnriched: (screenshots, forceSwap) {
        if (!mounted) return;
        if (_selectedScreenshotUrl == null || _carouselTimer == null) {
          _startCarousel(screenshots, forceInitialSwap: forceSwap);
        } else if (screenshots.length > 1) {
          _startCarousel(screenshots, forceInitialSwap: false);
        }
      },
    );

    _startCarousel(widget.gameData['screenshots']);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _carouselTimer?.cancel();
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  // Widget "¿Quién lo tiene?" — avatares de amigos que tienen este juego

  /// Muestra una screenshot aleatoria cada vez que se entra a la ventana del juego
  void _selectRandomScreenshot(dynamic screenshotsData) {
    if (screenshotsData != null &&
        screenshotsData is List &&
        screenshotsData.isNotEmpty) {
      final randomItem =
          screenshotsData[Random().nextInt(screenshotsData.length)];
      String imageId = '';
      if (randomItem is Map) {
        imageId = randomItem['image_id']?.toString() ?? '';
      } else {
        imageId = randomItem.toString();
      }

      if (imageId.isNotEmpty) {
        final url = IGDBService.getScreenshotUrl(imageId);
        if (mounted) {
          setState(() {
            _selectedScreenshotUrl = url;
          });
        }
      }
    }
  }

  void _startCarousel(dynamic screenshotsData, {bool forceInitialSwap = true}) {
    if (screenshotsData != null &&
        screenshotsData is List &&
        screenshotsData.isNotEmpty) {
      if (forceInitialSwap) {
        _selectRandomScreenshot(screenshotsData);
      }
      if (kDisableCarouselForTests) {
        return; // Evitar que pumpAndSettle quede esperando frames infinitos
      }
      if (screenshotsData.length > 1) {
        _carouselTimer?.cancel();
        _carouselTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _selectRandomScreenshot(screenshotsData);
        });
      }
    }
  }

  // _showImageGallery implementation removed in favor of full_screen_gallery.dart

  /// Obtiene el ID y nombre del juego original (si existe) desde parent_game, version_parent, etc.
  ({int id, String? name})? _getOriginalGameInfo() {
    final candidates = [
      widget.gameData['parent_game'],
      _enrichedData['parent_game'],
      widget.gameData['version_parent'],
      _enrichedData['version_parent'],
      widget.gameData['remake_of'],
      _enrichedData['remake_of'],
      widget.gameData['remaster_of'],
      _enrichedData['remaster_of'],
    ];

    for (final candidate in candidates) {
      if (candidate == null ||
          candidate.toString() == 'null' ||
          candidate.toString().isEmpty) {
        continue;
      }

      int? id;
      String? name;

      if (candidate is Map) {
        final idRaw = candidate['id'] ?? candidate['igdb_id'];
        id = (idRaw is num)
            ? idRaw.toInt()
            : int.tryParse(idRaw?.toString() ?? '');
        name = candidate['name']?.toString() ?? candidate['title']?.toString();
      } else if (candidate is List && candidate.isNotEmpty) {
        final first = candidate.first;
        if (first is Map) {
          final idRaw = first['id'] ?? first['igdb_id'];
          id = (idRaw is num)
              ? idRaw.toInt()
              : int.tryParse(idRaw?.toString() ?? '');
          name = first['name']?.toString() ?? first['title']?.toString();
        } else {
          id = (first is num)
              ? first.toInt()
              : int.tryParse(first?.toString() ?? '');
        }
      } else {
        id = (candidate is num)
            ? candidate.toInt()
            : int.tryParse(candidate.toString());
      }

      if (id != null && id > 0) {
        // Si IGDB solo devolvió el ID sin el nombre, intentamos buscar el título en juegos relacionados
        if (name == null && _relatedGames.isNotEmpty) {
          try {
            final match = _relatedGames.firstWhere(
              (g) => (g is Map) && ((g['id'] == id) || (g['igdb_id'] == id)),
            );
            if (match is Map) {
              name = match['name']?.toString() ?? match['title']?.toString();
            }
          } catch (e) {
            debugPrint(
              '[GameDetails] Error buscando juego en _relatedGames (getOriginalGame): $e',
            );
          }
        }
        return (id: id, name: name);
      }
    }
    return null;
  }

  /// Navega al juego original de forma INSTANTÁNEA precargando su carátula y datos desde la RAM o base de datos local
  Future<void> _navigateToOriginalGame(int id, String? name) async {
    final cleanData = <String, dynamic>{'igdb_id': id, 'id': id};
    if (name != null) {
      cleanData['title'] = name;
    }

    // 1. BÚSQUEDA INSTANTÁNEA EN RAM (_relatedGames)
    // En el 90% de los casos, tu pestaña "Relacionado" ya descargó este juego con su carátula en segundo plano.
    bool foundInRam = false;
    if (_relatedGames.isNotEmpty) {
      try {
        final match = _relatedGames.firstWhere(
          (g) => (g is Map) && ((g['id'] == id) || (g['igdb_id'] == id)),
        );
        if (match is Map) {
          final matchMap = Map<String, dynamic>.from(match);
          cleanData.addAll(matchMap);
          if (matchMap['name'] != null) cleanData['title'] = matchMap['name'];
          final coverMap = matchMap['cover'] as Map?;
          final coverId = coverMap?['image_id'] as String?;
          if (coverId != null) {
            cleanData['cover_url'] = IGDBService.getCoverUrl(coverId);
          }
          if (matchMap['first_release_date'] != null) {
            cleanData['release_date'] = DateTime.fromMillisecondsSinceEpoch(
              (matchMap['first_release_date'] as int) * 1000,
            ).toIso8601String();
          }
          if (matchMap['genres'] != null && matchMap['genres'] is List) {
            cleanData['genres'] = (matchMap['genres'] as List)
                .map((gen) => gen is Map ? gen['name'] : gen)
                .toList();
          }
          foundInRam = true;
        }
      } catch (e) {
        debugPrint(
          '[GameDetails] Error buscando juego en _relatedGames (RAM): $e',
        );
      }
    }

    // 2. BÚSQUEDA RÁPIDA EN SUPABASE (Si no estaba en RAM o le falta la carátula)
    final hasCover =
        cleanData['cover_url'] != null &&
        (cleanData['cover_url'] as String).isNotEmpty;
    if (!foundInRam || !hasCover) {
      bool showingSpinner = false;
      try {
        // Hacemos una consulta ultra-rápida a tu tabla local (tarda unos 50ms, imperceptible para el ojo humano)
        final localDbGame = await Supabase.instance.client
            .from('games')
            .select()
            .eq('igdb_id', id)
            .maybeSingle();

        if (localDbGame != null) {
          cleanData.addAll(localDbGame);
        } else {
          // 3. FALLBACK A IGDB (Solo si es un juego jamás visto ni cacheado por ningún usuario de la app)
          showingSpinner = true;
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          final igdbGame = await IGDBService.getGameById(id);
          if (showingSpinner && mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            showingSpinner = false;
          }
          if (igdbGame != null) {
            cleanData['title'] = igdbGame['name'] ?? cleanData['title'];
            if (igdbGame['cover'] != null) {
              final newCoverUrl = IGDBService.getCoverUrl(
                igdbGame['cover']['image_id'],
              );
              cleanData['cover_url'] = newCoverUrl;
              // Persistir la portada en BD para que el feed y el perfil
              // la muestren correctamente sin volver a consultar IGDB.
              Supabase.instance.client
                  .from('games')
                  .update({'cover_url': newCoverUrl})
                  .eq('igdb_id', id)
                  .isFilter('cover_url', null) // solo si aún es NULL
                  .then((_) {})
                  .catchError((_) {}); // fire-and-forget, no bloqueante
            }
            if (igdbGame['summary'] != null) {
              cleanData['summary'] = igdbGame['summary'];
            }
            if (igdbGame['first_release_date'] != null) {
              cleanData['release_date'] = DateTime.fromMillisecondsSinceEpoch(
                (igdbGame['first_release_date'] as int) * 1000,
              ).toIso8601String();
            }
            if (igdbGame['genres'] != null && igdbGame['genres'] is List) {
              cleanData['genres'] = (igdbGame['genres'] as List)
                  .map((gen) => gen is Map ? gen['name'] : gen)
                  .toList();
            }
          }
        }
      } catch (e) {
        debugPrint(
          '[GameDetails] Error enriqueciendo datos desde IGDB/Supabase: $e',
        );
        if (showingSpinner && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) return;

    // Abrimos la pantalla con el 100% de los datos listos
    if (MediaQuery.of(context).size.width >= 800) {
      context.pushGameDetails(cleanData);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        enableDrag: true,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          snap: true,
          builder: (context, scrollController) => GameDetailsScreen(
            gameData: cleanData,
            scrollController: scrollController,
          ),
        ),
      );
    }
  }

  /// Abre el bottom sheet de creación/edición de reseña.
  /// La lógica del formulario vive en [ReviewModal] (review_modal.dart).
  void _showReviewModal({Review? existingReview}) {
    ReviewModal.show(
      context: context,
      gameData: widget.gameData,
      enrichedData: _enrichedData,
      existingReview: existingReview,
      currentPartnerIds: _partnersData.map((e) => e.id).toList(),
      isSaving: _isSaving,
      currentRating: _rating,
      currentRatingGameplay: _ratingGameplay,
      currentRatingNarrative: _ratingNarrative,
      currentRatingSoundtrack: _ratingSoundtrack,
      currentRatingVisuals: _ratingVisuals,
      currentStatus: _status,
      initialComment: _commentController.text,
      onSave: _saveReview,
      inLibrary: _inLibrary,
    );
  }

  Future<void> _saveReview({
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
    try {
      final result = await _controller.saveReview(
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

      // Mostrar toasts de logros recién desbloqueados
      if (mounted && result.newAchievementDetails.isNotEmpty) {
        AchievementToast.showFromList(
          context,
          result.newAchievementDetails,
          isMounted: () => mounted,
        );
      }

      if (mounted) {
        libraryUpdateNotifier.value++;
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[CORPUS] Error saving review: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar reseña: $e')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers de UI extraídos del build() para mantenerlo legible
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedMainTabIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedMainTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar({
    required bool isDesktop,
    required int infoTabIdx,
    required int communityTabIdx,
    required int mediaTabIdx,
    required int relatedTabIdx,
    required int linksTabIdx,
    required bool hasMedia,
    required bool hasRelated,
    required bool hasLinks,
  }) {
    return Container(
      margin: EdgeInsets.only(
        top: 0,
        left: isDesktop ? 0 : 24,
        right: isDesktop ? 0 : 24,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(infoTabIdx, 'Información'),
            _buildTabButton(communityTabIdx, 'Comunidad'),
            if (hasMedia) _buildTabButton(mediaTabIdx, 'Media'),
            if (hasRelated) _buildTabButton(relatedTabIdx, 'Relacionado'),
            if (hasLinks) _buildTabButton(linksTabIdx, 'Links'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final title =
        widget.gameData['title'] ??
        _enrichedData['title'] ??
        (_isEnriching ? 'Cargando...' : 'Desconocido');

    // Datos con fallback a _enrichedData (para cuando venimos de la biblioteca)
    final summary = widget.gameData['summary'] ?? _enrichedData['summary'];
    final originalGame = _getOriginalGameInfo();
    final hasParentGame = originalGame != null;

    // Resolver categoría usando IgdbConstants (centralizado)
    // Fix #3: Lectura segura del tipo numérico (puede llegar como int, double o num desde JSON/Supabase)
    final dynamic rawCat =
        widget.gameData['game_type'] ??
        widget.gameData['category'] ??
        _enrichedData['game_type'] ??
        _enrichedData['category'];
    final int? categoryId = (rawCat is num)
        ? rawCat.toInt()
        : int.tryParse(rawCat?.toString() ?? '');

    final int? resolvedCategory = IgdbConstants.resolveCategory(
      categoryId,
      title,
      hasParentGame: hasParentGame,
      summary:
          widget.gameData['summary']?.toString() ??
          _enrichedData['summary']?.toString(),
    );
    final String? categoryLabel =
        resolvedCategory != null && !IgdbConstants.isMainGame(resolvedCategory)
        ? IgdbConstants.getCategoryName(resolvedCategory)
        : null;
    // catColor: delegado a GameInfoTab vía IgdbConstants

    final List<dynamic> genresList =
        (widget.gameData['genres'] as List?)?.isNotEmpty == true
        ? widget.gameData['genres']
        : (_enrichedData['genres'] as List? ?? []);
    final List<dynamic> platformsList =
        (widget.gameData['platforms'] as List?)?.isNotEmpty == true
        ? widget.gameData['platforms']
        : (_enrichedData['platforms'] as List? ?? []);
    final List<dynamic> themesList =
        (widget.gameData['themes'] as List?)?.isNotEmpty == true
        ? widget.gameData['themes']
        : (_enrichedData['themes'] as List? ?? []);
    // --- LECTURA INTELIGENTE DE COLECCIÓN Y FRANQUICIAS ---
    int? collectionId;
    String? collectionName;
    final dynamic enrichedCol = _enrichedData['collection'];
    final dynamic fallbackCol = widget.gameData['collection'];
    final dynamic rawCol = (enrichedCol != null && enrichedCol is Map)
        ? enrichedCol
        : fallbackCol;

    if (rawCol is Map) {
      collectionId = (rawCol['id'] is num)
          ? (rawCol['id'] as num).toInt()
          : int.tryParse(rawCol['id']?.toString() ?? '');
      collectionName = rawCol['name']?.toString();
    } else if (rawCol != null &&
        rawCol.toString() != 'null' &&
        rawCol.toString().isNotEmpty) {
      collectionName = rawCol.toString();
    }

    final List<Map<String, dynamic>> franchisesData = [];

    // ─── franchises (plural array — campo moderno) ────────────────────────────
    final List<dynamic> rawFranchises =
        (_enrichedData['franchises'] as List?)?.isNotEmpty == true
        ? (_enrichedData['franchises'] as List)
        : ((widget.gameData['franchises'] as List?) ?? []);

    for (final f in rawFranchises) {
      if (f is Map && f['name'] != null) {
        final int? fId = (f['id'] is num)
            ? (f['id'] as num).toInt()
            : int.tryParse(f['id']?.toString() ?? '');
        franchisesData.add({'id': fId, 'name': f['name']});
      } else if (f != null &&
          f.toString() != 'null' &&
          f.toString().isNotEmpty) {
        franchisesData.add({'name': f.toString()});
      }
    }

    // ─── franchise (singular — campo legacy, juegos pre-2015) ─────────────────
    // Algunos juegos (ej. Mario Kart DS, Wii, 7) solo tienen este campo en IGDB.
    // Si ya está cubierto por franchises[], lo ignoramos; si no, lo añadimos.
    final dynamic singularFranchise =
        _enrichedData['franchise'] ?? widget.gameData['franchise'];
    if (singularFranchise is Map && singularFranchise['name'] != null) {
      final int? sfId = (singularFranchise['id'] is num)
          ? (singularFranchise['id'] as num).toInt()
          : int.tryParse(singularFranchise['id']?.toString() ?? '');
      final bool alreadyIn = franchisesData.any(
        (f) => f['id'] != null && f['id'] == sfId,
      );
      if (!alreadyIn) {
        franchisesData.add({'id': sfId, 'name': singularFranchise['name']});
      }
    }

    final List<dynamic> rawEngines =
        (widget.gameData['game_engines'] as List?)
            ?.where(
              (e) =>
                  e != null &&
                  e.toString() != 'null' &&
                  e.toString().isNotEmpty,
            )
            .toList() ??
        [];
    final List<dynamic> gameEnginesList = rawEngines.isNotEmpty
        ? rawEngines
        : (_enrichedData['game_engines'] as List? ?? []);

    final List screenshotsList =
        (widget.gameData['screenshots'] as List?)?.isNotEmpty == true
        ? widget.gameData['screenshots']
        : (_enrichedData['screenshots'] as List? ?? []);
    final List artworksList =
        (widget.gameData['artworks'] as List?)?.isNotEmpty == true
        ? widget.gameData['artworks']
        : (_enrichedData['artworks'] as List? ?? []);
    final List videosList =
        (widget.gameData['videos'] as List?)?.isNotEmpty == true
        ? widget.gameData['videos']
        : (_enrichedData['videos'] as List? ?? []);
    final List baseWebsitesList =
        (widget.gameData['websites'] as List?)?.isNotEmpty == true
        ? widget.gameData['websites']
        : (_enrichedData['websites'] as List? ?? []);
    final String? igdbUrl = _enrichedData['url'] ?? widget.gameData['url'];
    final List websitesList = List.from(baseWebsitesList);
    if (igdbUrl != null && !websitesList.any((w) => w['url'] == igdbUrl)) {
      websitesList.add({'url': igdbUrl, 'category': 1000});
    }
    final bool hasMedia =
        screenshotsList.isNotEmpty ||
        artworksList.isNotEmpty ||
        videosList.isNotEmpty;
    final bool hasLinks = websitesList.isNotEmpty;

    // buildInfoTab → extracted to _buildInfoTab(...)

    // buildMediaTab → extracted to _buildMediaTab(...)

    // Group related games by game_type

    // Mostrar siempre la pestaña Relacionado
    // ignore: prefer_const_declarations
    final bool hasRelated = true;

    // Asignar índices dinámicamente para evitar huecos
    int tabIdx = 0;
    final int infoTabIdx = tabIdx++;
    final int communityTabIdx = tabIdx++;
    final int mediaTabIdx = hasMedia ? tabIdx++ : -1;
    final int relatedTabIdx = tabIdx++;
    final int linksTabIdx = hasLinks ? tabIdx++ : -1;

    Widget buildCurrentTabContent() {
      if (_selectedMainTabIndex == infoTabIdx) {
        return GameInfoTab(
          gameData: widget.gameData,
          enrichedData: _enrichedData,
          summary: summary,
          collectionName: collectionName,
          collectionId: collectionId,
          franchisesData: franchisesData,
          genresList: genresList,
          themesList: themesList,
          platformsList: platformsList,
          gameEnginesList: gameEnginesList,
          infoTabOrder: _infoTabOrder,
          infoTabHidden: _infoTabHidden,
          isLoadingMetacritic: _isLoadingMetacritic,
          metacriticScore: _metacriticScore,
          metacriticUserScore: _metacriticUserScore,
          metacriticCriticCount: _metacriticCriticCount,
          metacriticUserRatingCount: _metacriticUserRatingCount,
          metacriticUrl: _metacriticUrl,
          isLoadingStashStats: _isLoadingStashStats,
          stashStats: _stashStats,
          timeToBeat: _timeToBeat,
        );
      } else if (_selectedMainTabIndex == communityTabIdx) {
        return GameStashTab(
          isGuest: _isGuest,
          isLoadingStashReviews: _isLoadingStashReviews,
          stashReviews: _stashReviews,
        );
      } else if (hasMedia && _selectedMainTabIndex == mediaTabIdx) {
        return GameMediaTab(
          screenshotsList: screenshotsList,
          artworksList: artworksList,
          videosList: videosList,
        );
      } else if (_selectedMainTabIndex == relatedTabIdx) {
        return GameRelatedTab(
          controller: _controller,
          onNavigateToGame: (id, name) => _navigateToOriginalGame(id, name),
        );
      } else if (hasLinks && _selectedMainTabIndex == linksTabIdx) {
        return GameLinksTab(
          websitesList: websitesList,
          localizeLinks: _controller.localizeLinks,
        );
      }
      return const SizedBox.shrink();
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              GameHeroSection(
                gameData: widget.gameData,
                controller: _controller,
                isDesktop: isDesktop,
                inLibrary: _inLibrary,
                status: _status,
                reviews: _reviews,
                userData: _userData,
                partnersData: _partnersData,
                friendsWithGame: _friendsWithGame,
                isGuest: _isGuest,
                enrichedData: _enrichedData,
                resolvedCategory: resolvedCategory,
                categoryLabel: categoryLabel,
                originalGame: originalGame,
                onNavigateToGame: (game) =>
                    _navigateToOriginalGame(game.id, game.name),
                onShowReviewModal: () => _showReviewModal(),
                onEditReview: (review) =>
                    _showReviewModal(existingReview: review),
                onDeleteReview: _controller.deleteReview,
                tabsSliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _GameDetailsTabBarDelegate(
                    height: 56.0,
                    child: _buildNavBar(
                      isDesktop: isDesktop,
                      infoTabIdx: infoTabIdx,
                      communityTabIdx: communityTabIdx,
                      mediaTabIdx: mediaTabIdx,
                      relatedTabIdx: relatedTabIdx,
                      linksTabIdx: linksTabIdx,
                      hasMedia: hasMedia,
                      hasRelated: hasRelated,
                      hasLinks: hasLinks,
                    ),
                  ),
                ),
                tabContentSliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 0 : 24.0,
                      24.0,
                      isDesktop ? 0 : 24.0,
                      0,
                    ),
                    child: buildCurrentTabContent(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        );
      },
    );
  }
}

class _GameDetailsTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _GameDetailsTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _GameDetailsTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
