import 'package:flutter/material.dart';
import 'game_details/game_details_controller.dart';
import 'game_details/game_links_tab.dart';
import 'game_details/game_related_tab.dart';
import 'game_details/game_media_tab.dart';
import 'game_details/game_stash_tab.dart';
import 'game_details/game_info_tab.dart';
import 'game_details/game_reviews_card.dart';
import 'dart:async';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../../utils/igdb_constants.dart';
import '../activity/review_details_screen.dart';

import 'group_games_screen.dart';
import '../../widgets/achievement_toast.dart';
import '../../theme/corpus_theme_extension.dart';
import 'review_modal.dart';
import '../../repositories/review_repository.dart';
import '../../models/models.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../utils/format_utils.dart';
import '../../widgets/corpus_primary_button.dart';
import '../../widgets/full_screen_gallery.dart';
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
  final _repo = ReviewRepository();
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
  set _inLibrary(bool v) => _controller.inLibrary = v;
  String get _status => _controller.status;
  set _status(String v) => _controller.status = v;
  double get _rating => _controller.rating;
  set _rating(double v) => _controller.rating = v;
  double get _ratingGameplay => _controller.ratingGameplay;
  set _ratingGameplay(double v) => _controller.ratingGameplay = v;
  double get _ratingNarrative => _controller.ratingNarrative;
  set _ratingNarrative(double v) => _controller.ratingNarrative = v;
  double get _ratingSoundtrack => _controller.ratingSoundtrack;
  set _ratingSoundtrack(double v) => _controller.ratingSoundtrack = v;
  double get _ratingVisuals => _controller.ratingVisuals;
  set _ratingVisuals(double v) => _controller.ratingVisuals = v;
  bool get _isLoadingUserData => _controller.isLoadingUserData;
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

  Color _friendStatusColor(String status) {
    switch (status) {
      case 'playing':
        return Colors.blue;
      case 'beaten':
        return Colors.green;
      case 'abandoned':
        return Colors.red;
      case 'on_hold':
        return Colors.orange;
      case 'wishlist':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _friendStatusIcon(String status) {
    switch (status) {
      case 'playing':
        return Icons.sports_esports;
      case 'beaten':
        return Icons.check_circle;
      case 'abandoned':
        return Icons.close;
      case 'on_hold':
        return Icons.pause;
      case 'wishlist':
        return Icons.bookmark;
      default:
        return Icons.flag;
    }
  }

  String _friendStatusLabel(String status) {
    switch (status) {
      case 'playing':
        return 'Jugando';
      case 'beaten':
        return 'Completado';
      case 'abandoned':
        return 'Abandonado';
      case 'on_hold':
        return 'En pausa';
      case 'wishlist':
        return 'En wishlist';
      default:
        return 'Desconocido';
    }
  }

  Future<void> _showFriendGameActivity(
    Map<String, dynamic> user,
    String currentStatus,
  ) async {
    final gameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (gameId == null) return;
    final userId = user['id'];
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _repo.fetchFriendActivityForGame(
        userId: userId,
        gameId: gameId,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result.review != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewDetailsScreen(
              gameData: widget.gameData,
              userData: user,
              reviewData: result.review!,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este estado no tiene una reseña asociada.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la actividad: $e')),
      );
    }
  }

  // Widget "¿Quién lo tiene?" — avatares de amigos que tienen este juego
  Widget _buildFriendsWithGame(BuildContext context) {
    if (_friendsWithGame.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Quién lo tiene?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _friendsWithGame.map((f) {
              final user = f['users'] as Map<String, dynamic>? ?? {};
              final avatarUrl = user['avatar_url'] as String?;
              final displayName =
                  user['display_name'] as String? ??
                  user['username'] as String? ??
                  '?';
              final status = f['status'] as String? ?? 'wishlist';
              final statusColor = _friendStatusColor(status);
              final statusIcon = _friendStatusIcon(status);
              return GestureDetector(
                onTap: () => _showFriendGameActivity(user, status),
                child: Tooltip(
                  message: '$displayName · ${_friendStatusLabel(status)}',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person, size: 34)
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

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
          } catch (_) {}
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
      } catch (_) {}
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
              cleanData['cover_url'] = IGDBService.getCoverUrl(
                igdbGame['cover']['image_id'],
              );
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
      } catch (_) {
        if (showingSpinner && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) return;

    // Abrimos la pantalla con el 100% de los datos listos
    if (MediaQuery.of(context).size.width >= 800) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameDetailsScreen(gameData: cleanData),
        ),
      );
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
      commentController: _commentController,
      onSave: _saveReview,
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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final userId = _repo.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      final result = await _repo.saveReview(
        userId: userId,
        igdbId: igdbId,
        gameData: widget.gameData,
        enrichedData: _enrichedData,
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
        int toastDelay = 300;
        for (final ach in result.newAchievementDetails) {
          final String aId = ach['id'] as String;
          final String title = ach['name'] as String? ?? 'Logro desbloqueado';
          final String rarity =
              (ach['rarity'] as String?)?.toLowerCase() ?? 'comun';
          final int xpReward = ach['xp_reward'] as int? ?? 0;

          String subtitle = 'Logro desbloqueado';
          Color color = const Color(0xFFFFD700);

          if (title.contains('(Maestro)') ||
              title.contains('(Nivel 3)') ||
              aId.endsWith('_all')) {
            subtitle = 'Maestro de saga';
            color = const Color(0xFFFFD700);
          } else if (title.contains('(Nivel 2)')) {
            subtitle = 'Hito alcanzado';
            color = const Color(0xFFC0C0C0);
          } else if (title.contains('(Nivel 1)')) {
            subtitle = 'Logro desbloqueado';
            color = const Color(0xFFCD7F32);
          } else {
            if (rarity == 'legendario' ||
                rarity == 'platino' ||
                rarity == 'épico' ||
                rarity == 'epico') {
              subtitle = 'Hazaña legendaria';
              color = Colors.cyanAccent;
            } else if (rarity == 'difícil' ||
                rarity == 'dificil' ||
                rarity == 'medio') {
              subtitle = 'Logro desbloqueado';
              color = Colors.blueAccent;
            } else {
              subtitle = 'Logro desbloqueado';
              color = Colors.green;
            }
          }

          Future.delayed(Duration(milliseconds: toastDelay), () {
            if (mounted) {
              AchievementToast.show(
                context,
                title: title,
                subtitle: subtitle,
                xpReward: xpReward,
                icon: Icons.workspace_premium,
                color: color,
              );
            }
          });
          toastDelay += 3700;
        }
      }

      if (mounted) {
        setState(() {
          _inLibrary = true;
          _status = status;
          _rating = rating;
          _ratingGameplay = ratingGameplay;
          _ratingNarrative = ratingNarrative;
          _ratingSoundtrack = ratingSoundtrack;
          _ratingVisuals = ratingVisuals;
          // Fetch reviews to get the updated review list.
          // We don't fetch user data here to avoid race conditions with the DB trigger,
          // since we already updated the local state variables above.
          _controller.fetchReviews();
        });
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

  Color _getStatusColor(String status) =>
      GameStatus.colorForString(context, status);

  String _getStatusText(String status) => GameStatus.labelForString(status);

  IconData _getStatusIcon(String status) => GameStatus.iconForString(status);

  Future<void> _deleteFromLibrary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar de biblioteca'),
        content: const Text(
          '¿Seguro que quieres eliminar este juego de tu biblioteca? Se borrará tu reseña y nota.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final userId = _repo.client.auth.currentUser?.id;
    if (userId == null) return;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      await _repo.deleteFromLibrary(userId: userId, gameId: igdbId);

      if (mounted) {
        setState(() {
          _reviews.clear();
          _inLibrary = false;
          _status = 'wishlist';
          _rating = 0;
          _ratingGameplay = 0;
          _ratingNarrative = 0;
          _ratingSoundtrack = 0;
          _ratingVisuals = 0;
          _commentController.clear();
          _ratingController.clear();
        });
        libraryUpdateNotifier.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Juego eliminado de tu biblioteca')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _deleteReview(Review review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: const Text('¿Seguro que quieres eliminar esta reseña?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final gameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
      final removedFromLibrary = await _repo.deleteReview(
        reviewId: review.id,
        reviewData: review,
        gameId: gameId,
      );

      if (mounted) {
        setState(() {
          _reviews.removeWhere((r) => r.id == review.id);
          if (removedFromLibrary) _inLibrary = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reseña eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar reseña: $e')));
      }
    }
  }

  Widget _buildStatusButton() {
    if (_isGuest) {
      return const SizedBox(
        width: double.infinity,
        child: GuestLoginButton(label: 'Iniciar sesión para registrar'),
      );
    }

    final color = _inLibrary
        ? _getStatusColor(_status)
        : Theme.of(context).colorScheme.primary;
    final text = _inLibrary ? _getStatusText(_status) : 'Añadir a Biblioteca';
    final icon = _inLibrary ? _getStatusIcon(_status) : Icons.add;
    final textColor = color == Theme.of(context).colorScheme.secondary
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.white;

    return Row(
      children: [
        Expanded(
          child: CorpusPrimaryButton(
            onPressed: () {
              if (_inLibrary) {
                _showReviewModal(
                  existingReview: _reviews.isNotEmpty ? _reviews.first : null,
                );
              } else {
                _showReviewModal();
              }
            },
            icon: icon,
            label: text,
            backgroundColor: color,
            foregroundColor: textColor,
            expand: true,
            height: 50,
            elevation: _inLibrary ? 0 : 2,
          ),
        ),
        if (_inLibrary) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusSmall,
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: Theme.of(
                    context,
                  ).extension<CorpusThemeExtension>()!.radiusMedium,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showReviewModal(
                      existingReview: _reviews.isNotEmpty
                          ? _reviews.first
                          : null,
                    );
                  } else if (value == 'review') {
                    _showReviewModal();
                  } else if (value == 'delete') {
                    _deleteFromLibrary();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'review',
                    child: Row(
                      children: [
                        Icon(Icons.rate_review, size: 20),
                        SizedBox(width: 12),
                        Text('Añadir Reseña'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar de biblioteca',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers de UI extraídos del build() para mantenerlo legible
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFadeInImage(String url, {Key? key}) {
    return SizedBox.expand(
      key: key,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }

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
        left: isDesktop ? 0 : 16,
        right: isDesktop ? 0 : 16,
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
    final title =
        widget.gameData['title'] ??
        _enrichedData['title'] ??
        (_isEnriching ? 'Cargando...' : 'Desconocido');
    final coverUrl =
        widget.gameData['cover_url'] ?? _enrichedData['cover_url'] ?? '';
    final highResCoverUrl = coverUrl.replaceAll('t_cover_big', 't_1080p');

    // Datos con fallback a _enrichedData (para cuando venimos de la biblioteca)
    final summary = widget.gameData['summary'] ?? _enrichedData['summary'];
    final developer =
        (widget.gameData['developer'] != null &&
            widget.gameData['developer'] != 'Desconocido' &&
            widget.gameData['developer'] != 'Desarrollador desconocido')
        ? widget.gameData['developer']
        : _enrichedData['developer'];
    final developerId =
        widget.gameData['developer_id'] ?? _enrichedData['developer_id'];
    final originalGame = _getOriginalGameInfo();
    final hasParentGame = originalGame != null;

    // Resolver categoría usando IgdbConstants (centralizado)
    // Fix #3: Lectura segura del tipo numérico (puede llegar como int, double o num desde JSON/Supabase)
    final dynamic rawCat =
        widget.gameData['category'] ??
        widget.gameData['game_type'] ??
        _enrichedData['category'] ??
        _enrichedData['game_type'];
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
    final Color catColor = resolvedCategory != null
        ? IgdbConstants.getCategoryColor(
            resolvedCategory,
            themeSecondary: Theme.of(context).colorScheme.secondary,
          )
        : Theme.of(context).colorScheme.onSurfaceVariant;

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

    // Formatear fecha de lanzamiento
    String? releaseDate;
    final rawReleaseDate =
        widget.gameData['release_date'] ?? _enrichedData['release_date'];
    if (rawReleaseDate != null) {
      try {
        final date = DateTime.parse(rawReleaseDate.toString());
        const months = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre',
        ];
        releaseDate =
            '${date.day} de ${months[date.month - 1]} de ${date.year}';
      } catch (_) {}
    }

    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final Widget coverArtWidget = Container(
      decoration: BoxDecoration(
        borderRadius: ext.radiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ext.radiusMedium,
        child: highResCoverUrl.isNotEmpty
            ? Image.network(highResCoverUrl, fit: BoxFit.cover)
            : Container(color: Theme.of(context).primaryColorDark, height: 350),
      ),
    );

    final Widget headerInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        if (developer != null &&
            developer != 'Desconocido' &&
            developer != 'Desarrollador desconocido')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: developerId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupGamesScreen(
                            title: developer.toString(),
                            collectionId: developerId as int,
                            isCompany: true,
                          ),
                        ),
                      );
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.business,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        developer,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (releaseDate != null || categoryLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (releaseDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        releaseDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                if (categoryLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.2),
                      borderRadius: ext.radiusMedium,
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      categoryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: catColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // --- BOTÓN DE JUEGO ORIGINAL ---
        if (_getOriginalGameInfo() case final originalGame?)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: ActionChip(
              avatar: Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Juego original',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(borderRadius: ext.radiusLarge),
              onPressed: () =>
                  _navigateToOriginalGame(originalGame.id, originalGame.name),
            ),
          ),
      ],
    );

    final Widget interactiveWidget = _isLoadingUserData
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusButton(),
              GameReviewsCard(
                reviews: _reviews,
                gameData: widget.gameData,
                userData: _userData,
                partnersData: _partnersData,
                isDesktop: MediaQuery.of(context).size.width >= 800,
                onEditReview: (review) =>
                    _showReviewModal(existingReview: review),
                onDeleteReview: (review) => _deleteReview(review),
                onShowFullScreenGallery: (context, urls, index) =>
                    showFullScreenGallery(context, urls, index),
              ),
            ],
          );

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
    final List websitesList =
        (widget.gameData['websites'] as List?)?.isNotEmpty == true
        ? widget.gameData['websites']
        : (_enrichedData['websites'] as List? ?? []);
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
    final double topPadding = MediaQueryData.fromView(
      View.of(context),
    ).padding.top;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _GameDetailsHeaderDelegate(
                  topPadding: topPadding,
                  title: title,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  leading: const BackButton(color: Colors.white),
                  background: highResCoverUrl.isNotEmpty
                      ? Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(seconds: 1),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                              child: _selectedScreenshotUrl != null
                                  ? _buildFadeInImage(
                                      _selectedScreenshotUrl!,
                                      key: ValueKey(_selectedScreenshotUrl),
                                    )
                                  : (!_isEnriching
                                        ? _buildFadeInImage(
                                            highResCoverUrl,
                                            key: ValueKey(highResCoverUrl),
                                          )
                                        : Container(
                                            key: const ValueKey('empty'),
                                            color: Theme.of(
                                              context,
                                            ).primaryColorDark,
                                          )),
                            ),

                            Container(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              bottom: -2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    stops: const [
                                      0.0,
                                      0.12,
                                      0.22,
                                      0.35,
                                      0.5,
                                      0.65,
                                      0.8,
                                      1.0,
                                    ],
                                    colors: [
                                      Theme.of(context).scaffoldBackgroundColor,
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.9),
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.7),
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.5),
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.3),
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.15),
                                      Theme.of(context).scaffoldBackgroundColor
                                          .withValues(alpha: 0.05),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(color: Theme.of(context).primaryColorDark),
                ),
              ),

              if (isDesktop)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 24.0,
                  ),
                  sliver: SliverCrossAxisGroup(
                    slivers: [
                      SliverConstrainedCrossAxis(
                        maxExtent: 280,
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              coverArtWidget,
                              const SizedBox(height: 24),
                              interactiveWidget,
                              _buildFriendsWithGame(context),
                            ],
                          ),
                        ),
                      ),
                      const SliverConstrainedCrossAxis(
                        maxExtent: 40,
                        sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                      ),
                      SliverCrossAxisExpanded(
                        flex: 1,
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  headerInfoWidget,
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _GameDetailsTabBarDelegate(
                                height: 56.0,
                                child: _buildNavBar(
                                  isDesktop: true,
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
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 24.0),
                                child: buildCurrentTabContent(),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 120, child: coverArtWidget),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [headerInfoWidget],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        interactiveWidget,
                        _buildFriendsWithGame(context),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _GameDetailsTabBarDelegate(
                    height: 56.0,
                    child: _buildNavBar(
                      isDesktop: false,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: buildCurrentTabContent(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GameDetailsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final Widget background;
  final Widget leading;
  final String title;
  final Color backgroundColor;

  _GameDetailsHeaderDelegate({
    required this.topPadding,
    required this.background,
    required this.leading,
    required this.title,
    required this.backgroundColor,
  });

  @override
  double get minExtent => 56.0 + topPadding;

  @override
  double get maxExtent => 250.0 + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double maxShrink = maxExtent - minExtent;
    final double progress = maxShrink > 0
        ? (shrinkOffset / maxShrink).clamp(0.0, 1.0)
        : 0.0;
    final double titleOpacity = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Imagen de fondo
        Opacity(opacity: (1.0 - progress).clamp(0.0, 1.0), child: background),
        // 2. Fondo sólido al colapsar
        Opacity(
          opacity: progress,
          child: Container(color: backgroundColor),
        ),
        // 3. Barra fija exactamente debajo de topPadding (notch)
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          height: 56.0,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Opacity(
                  opacity: titleOpacity,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _GameDetailsHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.background != background ||
        oldDelegate.title != title ||
        oldDelegate.backgroundColor != backgroundColor;
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
