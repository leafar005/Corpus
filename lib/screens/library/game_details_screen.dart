import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../globals.dart';
import '../../services/igdb_service.dart';
import '../../utils/igdb_constants.dart';
import '../activity/review_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'group_games_screen.dart';
import '../../widgets/achievement_toast.dart';
import '../../widgets/coop_badge.dart';
import 'review_modal.dart';
import '../../repositories/review_repository.dart';
import '../../widgets/guest_login_prompt.dart';
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
  bool _isSaving = false;
  String? _selectedScreenshotUrl;
  bool _isLoadingUserData = true;
  bool _isEnriching = true;
  int _selectedMainTabIndex = 0;
  int _selectedMediaTabIndex = 0;

  // Si es false, el usuario no tiene este juego en su biblioteca
  bool _inLibrary = false;

  String _status = 'wishlist';
  double _rating = 0;
  double _ratingGameplay = 0;
  double _ratingNarrative = 0;
  double _ratingSoundtrack = 0;
  double _ratingVisuals = 0;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _partnerData;

  // Datos enriquecidos desde IGDB (para cuando venimos de la biblioteca y faltan summary/developer)
  Map<String, dynamic> _enrichedData = {};

  // Tiempo de juego estimado (HowLongToBeat)
  Map<String, dynamic>? _timeToBeat;

  // Metacritic (Steam only / fallback)
  int? _metacriticScore;
  String? _metacriticUrl;
  bool _isTrueMetacritic = false;
  bool _isLoadingMetacritic = false;

  // Juegos relacionados (DLCs, remakes, ports, etc.)
  List<dynamic> _relatedGames = [];
  bool _isLoadingRelated = true;

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();

  // Reviews from the reviews table
  List<Map<String, dynamic>> _reviews = [];
  Timer? _carouselTimer;

  // Stash Community Reviews
  List<Map<String, dynamic>> _stashReviews = [];
  bool _isLoadingStashReviews = true;
  int _stashReviewLimit = 5;

  // Stash Game Stats (Críticas, Quiero, Jugado, Reseñas)
  Map<String, dynamic>? _stashStats;
  bool _isLoadingStashStats = true;

  // ¿Quién lo tiene? - amigos con este juego en la biblioteca
  List<Map<String, dynamic>> _friendsWithGame = [];
  bool _localizeLinks = true;

  StreamSubscription<AuthState>? _authSub;

  bool get _isGuest => _repo.client.auth.currentUser == null;

  @override
  void initState() {
    super.initState();

    if (_isGuest) {
      _isLoadingUserData = false;
      _isLoadingStashReviews = false;
      _isLoadingStashStats = false;
    } else {
      _fetchUserData().then((_) {
        if (widget.autoOpenReview && mounted) {
          _showReviewModal();
        }
      });
      _fetchReviews();
      _fetchStashReviews();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _fetchStashStats();
      });
      _fetchFriendsWithGame();
    }

    _authSub = _repo.client.auth.onAuthStateChange.listen((_) {
      if (!mounted || _repo.client.auth.currentUser == null) return;
      if (_isLoadingUserData || _userData != null) {
        return;
      }
      setState(() {
        _isLoadingUserData = true;
        _isLoadingStashReviews = true;
        _isLoadingStashStats = true;
      });
      _fetchUserData();
      _fetchReviews();
      _fetchStashReviews();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _fetchStashStats();
      });
      _fetchFriendsWithGame();
    });

    _loadPreferences();
    _startCarousel(widget.gameData['screenshots']);
    _enrichGameData().then((_) => _fetchMetacritic());
    _fetchTimeToBeat();
    _fetchRelatedGames();
  }

  Future<void> _fetchMetacritic() async {
    // Attempt to read from gameData directly (if backfilled previously)
    final initialScore = widget.gameData['metacritic_score'] ?? _enrichedData['metacritic_score'] ?? widget.gameData['aggregated_rating'] ?? _enrichedData['aggregated_rating'];
    
    // Look for metacritic url in websites
    String? mcUrl = widget.gameData['metacritic_url'] ?? _enrichedData['metacritic_url'];
    if (mcUrl == null) {
      final websites = _enrichedData['websites'] as List<dynamic>? ?? [];
      for (final w in websites) {
        if (w['category'] == 14) { // 14 is metacritic in IGDB
          mcUrl = w['url'];
          break;
        }
      }
    }

    // Try to get exact Metacritic score & URL from Steam if available
    String? steamUrl;
    final websites = _enrichedData['websites'] as List<dynamic>? ?? [];
    for (final w in websites) {
      if (w['category'] == 13) { // 13 is Steam
        steamUrl = w['url'];
        break;
      }
    }

    if (steamUrl != null) {
      final regex = RegExp(r'app/(\d+)');
      final match = regex.firstMatch(steamUrl);
      if (match != null) {
        final appId = match.group(1);
        if (appId != null) {
          try {
            final res = await http.get(Uri.parse('https://store.steampowered.com/api/appdetails?appids=$appId&l=spanish'));
            if (res.statusCode == 200) {
              final json = jsonDecode(res.body);
              final appData = json[appId];
              if (appData != null && appData['success'] == true) {
                final metacritic = appData['data']['metacritic'];
                if (metacritic != null) {
                  if (mounted) {
                    setState(() {
                      _metacriticScore = metacritic['score'];
                      _metacriticUrl = metacritic['url'];
                      _isTrueMetacritic = true;
                    });
                  }
                  return; // Successfully fetched from Steam
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching Metacritic from Steam: $e');
          }
        }
      }
    }

    // Fallback to IGDB / existing data if Steam fetch failed or game is not on Steam
    if (mounted) {
      setState(() {
        _metacriticScore = initialScore is num ? initialScore.toInt() : null;
        _metacriticUrl = mcUrl;
        // If it came from our DB's metacritic_score, it's a true Metacritic score
        _isTrueMetacritic = (widget.gameData['metacritic_score'] != null || _enrichedData['metacritic_score'] != null);
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localizeLinks = prefs.getBool('localize_links') ?? true;
      });
    }
  }

  Future<void> _fetchTimeToBeat() async {
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) return;

    final ttb = await IGDBService.getTimeToBeat(
      igdbId is int ? igdbId : int.parse(igdbId.toString()),
    );
    if (mounted && ttb != null) {
      setState(() {
        _timeToBeat = ttb;
      });
    }
  }

  Future<void> _fetchRelatedGames() async {
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) {
      if (mounted) setState(() => _isLoadingRelated = false);
      return;
    }
    try {
      final results = await IGDBService.getRelatedGames(
        igdbId is int ? igdbId : int.parse(igdbId.toString()),
      );
      if (mounted) {
        setState(() {
          _relatedGames = results;
          _isLoadingRelated = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  /// Carga los amigos que tienen este juego en su biblioteca.
  Future<void> _fetchFriendsWithGame() async {
    final gameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (gameId == null) return;
    final myId = _repo.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final friends = await _repo.fetchFriendsWithGame(
        myId: myId,
        gameId: gameId,
      );
      if (mounted) setState(() => _friendsWithGame = friends);
    } catch (e) {
      debugPrint('[GameDetails] Error cargando amigos con el juego: $e');
    }
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
        return Icons.emoji_events;
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
          Text(
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

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _commentController.dispose();
    _ratingController.dispose();
    _authSub?.cancel();
    super.dispose();
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

  void _showImageGallery(List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        final PageController pageController = PageController(
          initialPage: initialIndex,
        );
        int currentIndex = initialIndex;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (MediaQuery.of(context).size.width > 800 &&
                      imageUrls.length > 1) ...[
                    if (currentIndex > 0)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (currentIndex < imageUrls.length - 1)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Enriquece los datos del juego llamando a IGDB si faltan campos importantes
  Future<void> _enrichGameData() async {
    final hasSummary =
        widget.gameData['summary'] != null &&
        widget.gameData['summary'].toString() != 'null' &&
        widget.gameData['summary'].toString().isNotEmpty;
    final hasDeveloper =
        widget.gameData['developer'] != null &&
        widget.gameData['developer'] != 'Desconocido' &&
        widget.gameData['developer'] != 'Desarrollador desconocido';
    final hasCategory = widget.gameData['category'] != null;
    final hasScreenshots =
        (widget.gameData['screenshots'] as List?)?.isNotEmpty == true;

    // Validación estricta para no ignorar campos vacíos provenientes de Supabase
    final hasGameEngines =
        (widget.gameData['game_engines'] as List?)
            ?.where(
              (e) =>
                  e != null &&
                  e.toString() != 'null' &&
                  e.toString().isNotEmpty,
            )
            .isNotEmpty ==
        true;
    final hasCollection =
        widget.gameData['collection'] != null &&
        widget.gameData['collection'].toString() != 'null' &&
        widget.gameData['collection'].toString().isNotEmpty;
    final hasFranchises =
        (widget.gameData['franchises'] as List?)
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
      if (mounted) setState(() => _isEnriching = false);
      return;
    }

    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) {
      if (mounted) setState(() => _isEnriching = false);
      return;
    }

    try {
      final game = await IGDBService.getGameById(
        igdbId is int ? igdbId : int.parse(igdbId.toString()),
      );
      if (game != null && mounted) {
        // Extraer desarrollador
        String? developer;
        int? developerId;
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
        }

        // Siempre poblar _enrichedData con TODOS los campos de IGDB.
        // El código de display usa widget.gameData primero y _enrichedData como fallback,
        // así que esto no sobreescribe datos correctos que ya vengan del buscador.
        setState(() {
          _enrichedData = {
            if (game['summary'] != null) 'summary': game['summary'],
            'developer': developer,
            'developer_id': developerId,
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
            if (game['aggregated_rating'] != null) 'aggregated_rating': game['aggregated_rating'],
            'platforms': game['platforms'] != null
                ? (game['platforms'] as List).map((p) => p['name']).toList()
                : [],
            'genres': game['genres'] != null
                ? (game['genres'] as List).map((g) => g['name']).toList()
                : [],
            'screenshots': game['screenshots'] != null
                ? (game['screenshots'] as List)
                      .map((s) => s['image_id'])
                      .toList()
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
        });

        final List enrichedScreenshots = _enrichedData['screenshots'] ?? [];
        if (enrichedScreenshots.isNotEmpty) {
          if (_selectedScreenshotUrl == null || _carouselTimer == null) {
            _startCarousel(enrichedScreenshots, forceInitialSwap: true);
          } else if (enrichedScreenshots.length > 1) {
            _startCarousel(
              enrichedScreenshots,
              forceInitialSwap: false,
            ); // Restart with enriched data
          }
        }
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error enriching game data: $e');
    } finally {
      if (mounted) setState(() => _isEnriching = false);
    }
  }

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
    final isDesktop = MediaQuery.of(context).size.width > 800;
    if (isDesktop) {
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

  Future<void> _fetchUserData() async {
    final userId = _repo.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      final response = await _repo.fetchUserGame(
        userId: userId,
        gameId: igdbId,
      );

      if (response != null && mounted) {
        setState(() {
          _inLibrary = true;
          _status = response['status'] ?? 'wishlist';
          _rating = (response['rating'] ?? 0).toDouble();
          _ratingGameplay = (response['rating_gameplay'] ?? 0).toDouble();
          _ratingNarrative = (response['rating_narrative'] ?? 0).toDouble();
          _ratingSoundtrack = (response['rating_soundtrack'] ?? 0).toDouble();
          _ratingVisuals = (response['rating_visuals'] ?? 0).toDouble();
          _commentController.text = response['comment'] ?? '';
          _userData = response['users'];
          _partnerData = response['partner'];
          if (_rating > 0) _ratingController.text = _rating.toStringAsFixed(1);
        });
      } else {
        final userResp = await _repo.fetchUserProfile(userId);
        if (mounted) setState(() => _userData = userResp);
      }
    } catch (e) {
      debugPrint('[CORPUS] ERROR en _fetchUserData: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _fetchReviews() async {
    final userId = _repo.client.auth.currentUser!.id;
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    try {
      final reviews = await _repo.fetchReviews(userId: userId, gameId: igdbId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (e) {
      debugPrint('[CORPUS] Error fetching reviews: $e');
    }
  }

  Future<void> _fetchStashReviews() async {
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) return;

    try {
      final local = await _repo.fetchStashReviewsLocal(igdbId);
      if (mounted) {
        setState(() {
          _stashReviews = local.reviews;
          _isLoadingStashReviews = local.needsFetch;
        });
      }

      if (local.needsFetch) {
        final updated = await _repo.refreshStashReviews(igdbId);
        if (mounted) {
          setState(() {
            if (updated != null) _stashReviews = updated;
            _isLoadingStashReviews = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error fetching stash reviews: $e');
      if (mounted) setState(() => _isLoadingStashReviews = false);
    }
  }

  Future<void> _fetchStashStats() async {
    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) return;

    try {
      final local = await _repo.fetchStashStatsLocal(igdbId);
      if (mounted) {
        setState(() {
          _stashStats = local.stats;
          _isLoadingStashStats = local.needsFetch;
        });
      }

      if (local.needsFetch) {
        final updated = await _repo.refreshStashStats(igdbId);
        if (mounted) {
          setState(() {
            if (updated != null) _stashStats = updated;
            _isLoadingStashStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error fetching stash stats: $e');
      if (mounted) setState(() => _isLoadingStashStats = false);
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[month - 1];
  }

  String _formatDateRange(String? from, String? until) {
    if (from == null) return '';
    try {
      final f = DateTime.parse(from);
      final fs = '${f.day} ${_getMonthAbbr(f.month)}';
      if (until == null) return '$fs ${f.year}';
      final u = DateTime.parse(until);
      final us = '${u.day} ${_getMonthAbbr(u.month)} ${u.year}';
      return f.year == u.year ? '$fs - $us' : '$fs ${f.year} - $us';
    } catch (_) {
      return '';
    }
  }

  String _getCompletionTypeText(String type) {
    switch (type) {
      case 'story':
        return 'Historia';
      case 'story_extras':
        return 'Historia + Extras';
      case '100_percent':
        return '100%';
      case 'endless':
        return 'Sin Fin';
      case 'on_hold':
        return 'En Pausa';
      default:
        return type;
    }
  }

  IconData _getCompletionTypeIcon(String type) {
    switch (type) {
      case 'story':
        return Icons.auto_stories;
      case 'story_extras':
        return Icons.extension;
      case '100_percent':
        return Icons.stars;
      case 'endless':
        return Icons.all_inclusive;
      case 'on_hold':
        return Icons.pause;
      default:
        return Icons.flag;
    }
  }

  Widget _buildInfoBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStashReviewsList() {
    if (_isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: GuestLoginPrompt(
          icon: Icons.reviews_outlined,
          message: 'Inicia sesión para ver las reseñas de la comunidad.',
        ),
      );
    }

    if (_isLoadingStashReviews && _stashReviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_stashReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'No hay reseñas de la comunidad.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final visibleReviews = _stashReviews.take(_stashReviewLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...visibleReviews.map((review) {
          final rating = (review['rating'] ?? 0).toDouble();
          final comment = review['comment'] ?? '';
          final displayName = review['stash_user_display_name'] ?? 'Usuario';
          final avatarUrl = review['stash_user_avatar_url'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (rating > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        if (_stashReviews.length > _stashReviewLimit)
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _stashReviewLimit += 5;
                });
              },
              icon: const Icon(Icons.expand_more),
              label: const Text('Ver más reseñas'),
            ),
          ),
      ],
    );
  }

  /// Abre el bottom sheet de creación/edición de reseña.
  /// La lógica del formulario vive en [ReviewModal] (review_modal.dart).
  void _showReviewModal({Map<String, dynamic>? existingReview}) {
    ReviewModal.show(
      context: context,
      gameData: widget.gameData,
      enrichedData: _enrichedData,
      existingReview: existingReview,
      currentPartnerId: _partnerData?['id'],
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
    required List<XFile> newImages,
    required List<String> existingImages,
    required String? partnerId,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final userId = _repo.client.auth.currentUser!.id;
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
        newImages: newImages,
        existingImages: existingImages,
        partnerId: partnerId,
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
        setState(() => _inLibrary = true);
        libraryUpdateNotifier.value++;
        Navigator.pop(context);
        await Future.wait([_fetchUserData(), _fetchReviews()]);
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

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
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
      return "${date.day} de ${months[date.month - 1]} de ${date.year}";
    } catch (e) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'beaten':
        return Theme.of(context).colorScheme.secondary;
      case 'playing':
        return Colors.blueAccent;
      case 'wishlist':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'beaten':
        return 'Terminado';
      case 'playing':
        return 'Jugando';
      case 'wishlist':
        return 'Quiero';
      case 'abandoned':
        return 'Abandonado';
      case 'on_hold':
        return 'En Pausa';
      default:
        return 'Desconocido';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'beaten':
        return Icons.emoji_events;
      case 'playing':
        return Icons.videogame_asset;
      case 'wishlist':
        return Icons.favorite;
      case 'abandoned':
        return Icons.cancel_outlined;
      case 'on_hold':
        return Icons.pause_circle_outline;
      default:
        return Icons.flag;
    }
  }

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

    final userId = _repo.client.auth.currentUser!.id;
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

  Future<void> _deleteReview(String reviewId) async {
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
      final review = _reviews.firstWhere(
        (r) => r['id'] == reviewId,
        orElse: () => <String, dynamic>{},
      );
      final gameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
      final removedFromLibrary = await _repo.deleteReview(
        reviewId: reviewId,
        reviewData: review,
        gameId: gameId,
      );

      if (mounted) {
        setState(() {
          _reviews.removeWhere((r) => r['id'] == reviewId);
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
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showReviewModal(
                existingReview: _reviews.isNotEmpty ? _reviews.first : null,
              ),
              icon: Icon(icon, color: textColor),
              label: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

  Widget _buildMetacriticSection() {
    if (_isLoadingMetacritic && _metacriticScore == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_metacriticScore == null) return const SizedBox.shrink();

    final Color scoreColor = _metacriticScore! >= 75
        ? Colors.green
        : _metacriticScore! >= 50
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTrueMetacritic ? 'Metacritic' : 'Nota Crítica (IGDB)',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _metacriticUrl != null
                ? () => launchUrl(Uri.parse(_metacriticUrl!))
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scoreColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scoreColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _metacriticScore.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isTrueMetacritic ? 'Metacritic Score' : 'Media de Críticas',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_metacriticUrl != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStashStatsSection() {
    if (_isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: GuestLoginPrompt(
          icon: Icons.groups_outlined,
          message: 'Inicia sesión para ver las estadísticas de la comunidad.',
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    if (_isLoadingStashStats && _stashStats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_stashStats == null) return const SizedBox.shrink();

    final rating = (_stashStats!['stash_rating'] as num?)?.toDouble();
    final want = _stashStats!['want_count'] as int?;
    final playing = _stashStats!['playing_count'] as int?;
    final played = _stashStats!['played_count'] as int?;
    final reviewsTotal = _stashStats!['reviews_count'] as int?;

    if (rating == null &&
        want == null &&
        playing == null &&
        played == null &&
        reviewsTotal == null) {
      return const SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget statCard(IconData icon, String value, String label, Color color) {
      return Container(
        constraints: BoxConstraints(minWidth: isDesktop ? 88 : 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isDesktop ? 18 : 16, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 15 : 14,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estadísticas de la Comunidad (Stash)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (rating != null)
              statCard(
                Icons.emoji_events,
                rating.toStringAsFixed(1),
                'Críticas',
                Colors.amber,
              ),
            if (want != null)
              statCard(
                Icons.favorite,
                want.toString(),
                'Quiero',
                Theme.of(context).colorScheme.primary,
              ),
            if (playing != null)
              statCard(
                Icons.gamepad,
                playing.toString(),
                'Jugando',
                Colors.green,
              ),
            if (played != null)
              statCard(
                Icons.videogame_asset,
                played.toString(),
                'Jugado',
                Colors.blueAccent,
              ),
            if (reviewsTotal != null)
              statCard(
                Icons.forum,
                reviewsTotal.toString(),
                'Reseñas',
                Colors.purpleAccent,
              ),
          ],
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSubRatingBadge(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _reviews.map((review) {
        final rating = (review['rating'] ?? 0).toDouble();
        final comment = review['comment'] ?? '';
        final completionType = review['completion_type'] ?? 'story';
        final isReplay = review['is_replay'] ?? false;
        final replayNumber = review['replay_number'];
        final rPlatform = review['platform'];
        final playTime = (review['play_time_hours'] ?? 0).toDouble();
        final playedFrom = review['played_from'];
        final playedUntil = review['played_until'];
        final progress = review['progress_percent'];
        final createdAt = review['created_at'];
        final rGameplay = (review['rating_gameplay'] ?? 0).toDouble();
        final rNarrative = (review['rating_narrative'] ?? 0).toDouble();
        final rSoundtrack = (review['rating_soundtrack'] ?? 0).toDouble();
        final rVisuals = (review['rating_visuals'] ?? 0).toDouble();
        final List<dynamic> imageUrls = review['image_urls'] ?? [];
        final dateStr = createdAt != null ? _formatDate(createdAt) : '';
        final rStatus = review['status'] ?? 'wishlist';
        String statusText;
        switch (rStatus) {
          case 'playing':
            statusText = 'Jugando';
            break;
          case 'beaten':
            statusText = 'Terminado';
            break;
          case 'abandoned':
            statusText = 'Abandonado';
            break;
          case 'on_hold':
            statusText = 'En Pausa';
            break;
          case 'wishlist':
            statusText = 'Quiero';
            break;
          default:
            statusText = 'Desconocido';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewDetailsScreen(
                  gameData: widget.gameData,
                  userData: _userData,
                  reviewData: review,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (completionType != 'none')
                            _buildInfoBadge(
                              _getCompletionTypeText(completionType),
                              _getCompletionTypeIcon(completionType),
                              Theme.of(context).colorScheme.primary,
                            ),
                          if (isReplay)
                            _buildInfoBadge(
                              'Rejugada${replayNumber != null ? ' #$replayNumber' : ''}',
                              Icons.replay,
                              Colors.orangeAccent,
                            ),
                          if (rPlatform != null)
                            _buildInfoBadge(
                              rPlatform,
                              Icons.devices,
                              Colors.blueGrey,
                            ),
                        ],
                      ),
                    ),
                    if (review['id'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            padding: const EdgeInsets.only(right: 12),
                            constraints: const BoxConstraints(),
                            tooltip: 'Editar reseña',
                            onPressed: () =>
                                _showReviewModal(existingReview: review),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Eliminar reseña',
                            onPressed: () => _deleteReview(review['id']),
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 24),
                if (_partnerData != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CoopBadge(
                      username: _partnerData!['username'] ?? 'Usuario',
                      avatarUrl: _partnerData!['avatar_url'],
                      size: 20,
                      status: rStatus,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (rating > 0) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (rGameplay > 0 ||
                    rNarrative > 0 ||
                    rSoundtrack > 0 ||
                    rVisuals > 0) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (rGameplay > 0)
                        _buildSubRatingBadge('Gameplay', rGameplay),
                      if (rNarrative > 0)
                        _buildSubRatingBadge('Narrativa', rNarrative),
                      if (rSoundtrack > 0)
                        _buildSubRatingBadge('Música', rSoundtrack),
                      if (rVisuals > 0)
                        _buildSubRatingBadge('Gráficos', rVisuals),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (comment.isNotEmpty)
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _showImageGallery(
                              List<String>.from(imageUrls),
                              idx,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrls[idx],
                                height: 100,
                                fit: BoxFit.fitHeight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (playTime > 0 || playedFrom != null || progress != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (playTime > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playTime.toStringAsFixed(1)}h',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (playedFrom != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateRange(playedFrom, playedUntil),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      if (progress != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$progress%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeToBeatCard(
    String title,
    int? seconds,
    Color color,
    IconData icon,
  ) {
    String timeText = '--';
    if (seconds != null && seconds > 0) {
      timeText =
          '${(seconds / 3600).toStringAsFixed(1).replaceAll('.0', '')} h';
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeText,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeToBeatRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeToBeatCard(
          'Principal',
          _timeToBeat?['hastily'],
          Colors.blueAccent,
          Icons.speed,
        ),
        const SizedBox(width: 8),
        _buildTimeToBeatCard(
          'Extras',
          _timeToBeat?['normally'],
          Colors.purpleAccent,
          Icons.explore,
        ),
        const SizedBox(width: 8),
        _buildTimeToBeatCard(
          'Completista',
          _timeToBeat?['completely'],
          Colors.amber,
          Icons.emoji_events,
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
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

  /// Convierte URLs internacionales a su versión de España.
  String _localizeUrlToSpain(String rawUrl) {
    if (!_localizeLinks) return rawUrl;
    String url = rawUrl;
    final lower = url.toLowerCase();
    if (lower.contains('store.steampowered.com')) {
      final separator = url.contains('?') ? '&' : '?';
      if (!lower.contains('l=spanish') && !lower.contains('cc=es')) {
        return '$url${separator}l=spanish&cc=es';
      }
    }
    if (lower.contains('store.playstation.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-z]{2}/',
          caseSensitive: false,
        ),
        '/es-es/',
      );
    }
    if (lower.contains('xbox.com') || lower.contains('microsoft.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-z]{2}/',
          caseSensitive: false,
        ),
        '/es-es/',
      );
    }
    if (lower.contains('store.epicgames.com') ||
        lower.contains('epicgames.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-zA-Z]{2}/',
          caseSensitive: false,
        ),
        '/es-ES/',
      );
    }
    if (lower.contains('nintendo.com')) {
      return url.replaceAll(
        RegExp(r'/(en-us|en-gb|us|uk)/', caseSensitive: false),
        '/es-es/',
      );
    }
    if (lower.contains('apps.apple.com')) {
      return url.replaceAll(
        RegExp(r'/apps\.apple\.com/[a-z]{2}/', caseSensitive: false),
        '/apps.apple.com/es/',
      );
    }
    if (lower.contains('gog.com')) {
      return url.replaceAll(
        RegExp(r'/gog\.com/(en|de|fr|pl|ru|zh)/', caseSensitive: false),
        '/gog.com/es/',
      );
    }
    return url;
  }

  Widget _buildRelatedTab() {
    if (_isLoadingRelated) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_relatedGames.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No hay contenido relacionado.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    String gameTypeLabel(int? t) {
      switch (t) {
        case 1:
          return 'DLCs';
        case 2:
          return 'Expansiones';
        case 3:
          return 'Bundles';
        case 4:
          return 'Expansiones Standalone';
        case 5:
          return 'Mods';
        case 6:
          return 'Episodios';
        case 7:
          return 'Temporadas';
        case 8:
          return 'Remakes';
        case 9:
          return 'Remasters';
        case 10:
          return 'Ediciones Expandidas';
        case 11:
          return 'Ports';
        case 12:
          return 'Forks';
        case 13:
          return 'Packs';
        case 14:
          return 'Actualizaciones';
        default:
          return 'Relacionados';
      }
    }

    const typeOrder = [8, 9, 4, 2, 1, 10, 11, 14, 3, 13, 6, 7, 12, 5, 0];
    final Map<int?, List<dynamic>> grouped = {};
    for (final g in _relatedGames) {
      final key = (g['game_type'] is num)
          ? (g['game_type'] as num).toInt()
          : g['game_type'] as int?;
      grouped.putIfAbsent(key, () => []).add(g);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = typeOrder.indexOf(a ?? -1);
        final bi = typeOrder.indexOf(b ?? -1);
        return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in sortedKeys) ...[
          Text(
            '${gameTypeLabel(type)} (${grouped[type]!.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: grouped[type]!.length,
            itemBuilder: (context, i) {
              final g = grouped[type]![i];
              final coverMap = g['cover'] as Map?;
              final coverId = coverMap?['image_id'] as String?;
              final coverUrl = IGDBService.getCoverUrl(coverId);
              int? releaseYear;
              if (g['first_release_date'] != null) {
                releaseYear = DateTime.fromMillisecondsSinceEpoch(
                  (g['first_release_date'] as int) * 1000,
                ).year;
              }
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final cleanData = Map<String, dynamic>.from(g as Map);
                  cleanData['igdb_id'] = g['id'];
                  cleanData['title'] = g['name'];
                  cleanData['cover_url'] = coverUrl;
                  if (g['genres'] != null && g['genres'] is List) {
                    cleanData['genres'] = (g['genres'] as List)
                        .map((gen) => gen is Map ? gen['name'] : gen)
                        .toList();
                  }
                  final isDesktop = MediaQuery.of(context).size.width > 800;
                  if (isDesktop) {
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
                        builder: (context, scrollController) {
                          return GameDetailsScreen(
                            gameData: cleanData,
                            scrollController: scrollController,
                          );
                        },
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: coverUrl.isNotEmpty
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Icons.videogame_asset,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    size: 36,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: Text(
                        releaseYear != null
                            ? '${g['name']} ($releaseYear)'
                            : g['name'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildLinksTab() {
    final List websitesList =
        (widget.gameData['websites'] as List?)?.isNotEmpty == true
        ? widget.gameData['websites']
        : (_enrichedData['websites'] as List? ?? []);

    if (websitesList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No hay enlaces disponibles.'),
        ),
      );
    }

    int getCategory(dynamic w) {
      if (w is Map && w['category'] != null) {
        final c = w['category'];
        if (c is int) return c;
        if (c is String) return int.tryParse(c) ?? 0;
        if (c is num) return c.toInt();
      }
      return 0;
    }

    bool isConsoleStore(dynamic w) {
      if (w is Map && w['url'] != null) {
        final url = w['url'].toString().toLowerCase();
        return url.contains('playstation.com') ||
            url.contains('xbox.com') ||
            url.contains('nintendo.com');
      }
      return false;
    }

    final stores = websitesList
        .where(
          (w) => [13, 15, 16, 17].contains(getCategory(w)) || isConsoleStore(w),
        )
        .toList();
    final socials = websitesList
        .where((w) => [4, 5, 6, 8, 9, 14, 18].contains(getCategory(w)))
        .toList();
    final official = websitesList
        .where((w) => [1, 2, 3].contains(getCategory(w)))
        .toList();
    final mobile = websitesList
        .where((w) => [10, 11, 12].contains(getCategory(w)))
        .toList();
    final others = websitesList
        .where(
          (w) =>
              ![
                1,
                2,
                3,
                4,
                5,
                6,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
              ].contains(getCategory(w)) &&
              !isConsoleStore(w),
        )
        .toList();

    Widget buildLinkSection(String title, List links, IconData icon) {
      if (links.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...links.map((link) {
            String name = 'Enlace';
            IconData itemIcon = Icons.link;
            final cat = getCategory(link);
            switch (cat) {
              case 1:
                name = 'Sitio Oficial';
                itemIcon = Icons.language;
                break;
              case 2:
                name = 'Wikia';
                itemIcon = Icons.menu_book;
                break;
              case 3:
                name = 'Wikipedia';
                itemIcon = Icons.menu_book;
                break;
              case 4:
                name = 'Facebook';
                itemIcon = Icons.facebook;
                break;
              case 5:
                name = 'Twitter';
                itemIcon = Icons.alternate_email;
                break;
              case 6:
                name = 'Twitch';
                itemIcon = Icons.live_tv;
                break;
              case 8:
                name = 'Instagram';
                itemIcon = Icons.camera_alt;
                break;
              case 9:
                name = 'YouTube';
                itemIcon = Icons.video_library;
                break;
              case 10:
                name = 'iPhone';
                itemIcon = Icons.phone_iphone;
                break;
              case 11:
                name = 'iPad';
                itemIcon = Icons.tablet_mac;
                break;
              case 12:
                name = 'Android';
                itemIcon = Icons.phone_android;
                break;
              case 13:
                name = 'Steam';
                itemIcon = Icons.computer;
                break;
              case 14:
                name = 'Reddit';
                itemIcon = Icons.forum;
                break;
              case 15:
                name = 'Itch.io';
                itemIcon = Icons.gamepad;
                break;
              case 16:
                name = 'Epic Games';
                itemIcon = Icons.computer;
                break;
              case 17:
                name = 'GOG';
                itemIcon = Icons.computer;
                break;
              case 18:
                name = 'Discord';
                itemIcon = Icons.chat;
                break;
              default:
                final urlString = link['url'].toString().toLowerCase();
                if (urlString.contains('playstation.com')) {
                  name = 'PlayStation Store';
                  itemIcon = Icons.gamepad;
                } else if (urlString.contains('xbox.com')) {
                  name = 'Xbox Store';
                  itemIcon = Icons.sports_esports;
                } else if (urlString.contains('nintendo.com')) {
                  name = 'Nintendo eShop';
                  itemIcon = Icons.videogame_asset;
                } else {
                  try {
                    final uri = Uri.parse(link['url'].toString());
                    name = uri.host.replaceFirst('www.', '');
                  } catch (_) {}
                }
            }
            // 1. Helper local para blindar la extracción del dominio incluso si falta "https://"
            String extractDomain(String rawUrl) {
              String url = rawUrl.trim();
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://$url';
              }
              return Uri.tryParse(url)?.host ?? '';
            }

            final domain = extractDomain(link['url'].toString());

            return ListTile(
              leading: Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    // 2. Usamos Google Favicons en PNG (100% compatible con Flutter y sin fallos CORS)
                    'https://www.google.com/s2/favicons?domain=$domain&sz=64',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(itemIcon, size: 18),
                  ),
                ),
              ),
              title: Text(name),
              subtitle: Text(
                _localizeUrlToSpain(link['url'].toString()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => launchUrl(
                Uri.parse(_localizeUrlToSpain(link['url'].toString())),
                mode: LaunchMode.externalApplication,
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildLinkSection('Tiendas', stores, Icons.store),
        buildLinkSection('Sociales y Comunidad', socials, Icons.people),
        buildLinkSection('Información Oficial', official, Icons.info),
        buildLinkSection('Móvil', mobile, Icons.smartphone),
        buildLinkSection('Otros', others, Icons.link),
      ],
    );
  }

  Widget _buildInfoTab({
    required String? summary,
    required String? collectionName,
    required int? collectionId,
    required List<Map<String, dynamic>> franchisesData,
    required List genresList,
    required List themesList,
    required List platformsList,
    required List gameEnginesList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (collectionName != null || franchisesData.isNotEmpty) ...[
          const Text(
            'Franquicia / Colección',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (collectionName != null)
                ActionChip(
                  label: Text(
                    collectionName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    if (collectionId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupGamesScreen(
                            title: collectionName,
                            collectionId: collectionId,
                            isFranchise: false,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SearchScreen(initialQuery: collectionName),
                        ),
                      );
                    }
                  },
                ),
              ...franchisesData
                  .where((f) => f['name'] != collectionName)
                  .map(
                    (f) => ActionChip(
                      label: Text(
                        f['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: () {
                        if (f['id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupGamesScreen(
                                title: f['name'].toString(),
                                collectionId: f['id'] as int,
                                isFranchise: true,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchScreen(
                                initialQuery: f['name'].toString(),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        if (genresList.isNotEmpty || themesList.isNotEmpty) ...[
          const Text(
            'Géneros y temáticas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...genresList.map((g) {
                final gName = g is Map ? g['name'].toString() : g.toString();
                return Chip(
                  label: Text(
                    IgdbConstants.formatGenreWithEmoji(gName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
              ...themesList.map((t) {
                final tName = t is Map ? t['name'].toString() : t.toString();
                return Chip(
                  label: Text(
                    IgdbConstants.formatThemeWithEmoji(tName),
                    style: const TextStyle(fontSize: 13),
                  ),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 28),
        ],
        if (platformsList.isNotEmpty) ...[
          const Text(
            'Plataformas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platformsList.map((p) {
              final style = IgdbConstants.getPlatformStyle(p.toString());
              return Chip(
                avatar: style['icon'] != null
                    ? Image.asset(
                        style['icon'],
                        height: 20,
                        fit: BoxFit.contain,
                      )
                    : null,
                label: Text(
                  p.toString(),
                  style: TextStyle(
                    color: style['textColor'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: style['color'],
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
        ],
        _buildMetacriticSection(),
        _buildStashStatsSection(),
        if (summary != null) ...[
          const Text(
            'Sinopsis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(summary, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 28),
        ],
        const Text(
          'Tiempo Estimado (HLTB)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildTimeToBeatRow(),
        if (gameEnginesList.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(
                Icons.memory,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Motor Gráfico: ${gameEnginesList.join(', ')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMediaTab({
    required List screenshotsList,
    required List artworksList,
    required List videosList,
  }) {
    final List<Map<String, dynamic>> availableTabs = [];
    if (screenshotsList.isNotEmpty) {
      availableTabs.add({
        'id': 0,
        'label': 'Capturas',
        'icon': Icons.screenshot_monitor,
      });
    }
    if (videosList.isNotEmpty) {
      availableTabs.add({
        'id': 1,
        'label': 'Tráilers',
        'icon': Icons.video_library,
      });
    }
    if (artworksList.isNotEmpty) {
      availableTabs.add({'id': 2, 'label': 'Artworks', 'icon': Icons.brush});
    }

    if (availableTabs.isEmpty) return const SizedBox.shrink();

    final int activeTabId =
        availableTabs.any((t) => t['id'] == _selectedMediaTabIndex)
        ? _selectedMediaTabIndex
        : availableTabs.first['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (availableTabs.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableTabs.map((tab) {
                final isSelected = tab['id'] == activeTabId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tab['label']),
                    showCheckmark: false,
                    avatar: Icon(
                      tab['icon'],
                      size: 18,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedMediaTabIndex = tab['id']);
                      }
                    },
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (activeTabId == 0)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: screenshotsList.length,
            itemBuilder: (context, index) {
              final url = IGDBService.getScreenshotUrl(
                screenshotsList[index].toString(),
              );
              return InkWell(
                onTap: () {
                  final List<String> urls = screenshotsList
                      .map((id) => IGDBService.getScreenshotUrl(id.toString()))
                      .toList();
                  _showImageGallery(urls, index);
                },
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
        if (activeTabId == 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: videosList.length,
            itemBuilder: (context, index) {
              final videoId = videosList[index].toString();
              final thumbUrl = IGDBService.getVideoThumbnailUrl(videoId);
              final videoUrl = IGDBService.getVideoUrl(videoId);
              return InkWell(
                onTap: () => launchUrl(
                  Uri.parse(videoUrl),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(thumbUrl, fit: BoxFit.cover),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (activeTabId == 2)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: artworksList.length,
            itemBuilder: (context, index) {
              final url = IGDBService.getArtworkUrl(
                artworksList[index].toString(),
              );
              return InkWell(
                onTap: () {
                  final List<String> urls = artworksList
                      .map((id) => IGDBService.getArtworkUrl(id.toString()))
                      .toList();
                  _showImageGallery(urls, index);
                },
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
      ],
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
    if (singularFranchise is Map &&
        singularFranchise['name'] != null) {
      final int? sfId = (singularFranchise['id'] is num)
          ? (singularFranchise['id'] as num).toInt()
          : int.tryParse(singularFranchise['id']?.toString() ?? '');
      final bool alreadyIn =
          franchisesData.any((f) => f['id'] != null && f['id'] == sfId);
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

    final Widget coverArtWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
            children: [_buildStatusButton(), _buildReviewsList()],
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

    final Widget tabsAndContentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
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
        ),
        if (_selectedMainTabIndex == infoTabIdx)
          _buildInfoTab(
            summary: summary,
            collectionName: collectionName,
            collectionId: collectionId,
            franchisesData: franchisesData,
            genresList: genresList,
            themesList: themesList,
            platformsList: platformsList,
            gameEnginesList: gameEnginesList,
          )
        else if (_selectedMainTabIndex == communityTabIdx)
          _buildStashReviewsList()
        else if (hasMedia && _selectedMainTabIndex == mediaTabIdx)
          _buildMediaTab(
            screenshotsList: screenshotsList,
            artworksList: artworksList,
            videosList: videosList,
          )
        else if (_selectedMainTabIndex == relatedTabIdx)
          _buildRelatedTab()
        else if (hasLinks && _selectedMainTabIndex == linksTabIdx)
          _buildLinksTab(),
      ],
    );

    return SelectionArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            CustomScrollView(
              controller: widget.scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: highResCoverUrl.isNotEmpty
                        ? Stack(
                            clipBehavior: Clip.none,
                            fit: StackFit.expand,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(seconds: 1),
                                transitionBuilder:
                                    (
                                      Widget child,
                                      Animation<double> animation,
                                    ) {
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
                                              key: ValueKey('empty'),
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
                                bottom:
                                    -2, // Se extiende 2px por debajo para tapar la costura
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
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.9),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.7),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.45),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.25),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.1),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.03),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ), // Close Positioned
                            ],
                          )
                        : Container(color: Theme.of(context).primaryColorDark),
                  ),
                ),

                SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth > 800;

                      if (isDesktop) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40.0,
                            vertical: 24.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 280,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    coverArtWidget,
                                    const SizedBox(height: 24),
                                    interactiveWidget,
                                    if (isDesktop)
                                      _buildFriendsWithGame(context),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 40),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    headerInfoWidget,
                                    const SizedBox(height: 12),
                                    tabsAndContentWidget,
                                    const SizedBox(height: 60),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Padding(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [headerInfoWidget],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              interactiveWidget,
                              if (!isDesktop) _buildFriendsWithGame(context),
                              const SizedBox(height: 12),
                              tabsAndContentWidget,
                              const SizedBox(height: 60),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.of(context).size.width < 600 ? 30.0 : 5.0,
              left: 8.0,
              child: const BackButton(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
