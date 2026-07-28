import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../globals.dart';
import '../library/game_details_screen.dart';

class HeroShowcase extends StatefulWidget {
  final List<Map<String, dynamic>> playingGames;
  final String userName;
  final Duration switchDuration;

  const HeroShowcase({
    super.key,
    required this.playingGames,
    required this.userName,
    this.switchDuration = const Duration(seconds: 10),
  });

  @override
  State<HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<HeroShowcase>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _currentGameIndex = 0;

  Map<String, dynamic>? _previousGame;
  String? _previousScreenshotUrl;
  double _previousPanValue = 1.0;

  Map<String, dynamic>? _currentGame;
  String? _currentScreenshotUrl;

  final Random _random = Random();

  late AnimationController _panController;
  late Animation<double> _fadeAnimation;
  late AnimationController _initialFadeController;

  late String _randomPrefix;

  static const List<String> _prefixes = [
    '¿Qué tal con ',
    '¿Cómo llevas ',
    '¿Queda mucho de ',
    '¿Te está molando ',
    '¿Por dónde vas en ',
  ];

  @override
  void initState() {
    super.initState();
    _randomPrefix = _prefixes[_random.nextInt(_prefixes.length)];
    _panController = AnimationController(
      vsync: this,
      duration: widget.switchDuration,
    );

    _initialFadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _panController,
        // Crossfade during the first 20% of the duration (2 seconds)
        curve: const Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );

    if (widget.playingGames.isNotEmpty) {
      _pickNextGame();
      _initialFadeController.forward();
      if (!kDisableCarouselForTests) {
        _timer = Timer.periodic(widget.switchDuration, (timer) {
          _pickNextGame();
        });
      }
    }
  }

  String? _getRandomScreenshot(Map<String, dynamic> game) {
    final screenshots = game['screenshots_list'] as List<String>? ?? [];
    if (screenshots.isEmpty) return null;
    return screenshots[_random.nextInt(screenshots.length)];
  }

  void _pickNextGame({bool manual = false}) {
    if (widget.playingGames.isEmpty) return;

    if (manual) {
      _timer?.cancel();
      if (!kDisableCarouselForTests) {
        _timer = Timer.periodic(widget.switchDuration, (timer) {
          _pickNextGame();
        });
      }
    }

    final nextGame = widget.playingGames[_currentGameIndex];
    final nextScreenshotUrl = _getRandomScreenshot(nextGame);

    setState(() {
      _previousGame = _currentGame;
      _previousScreenshotUrl = _currentScreenshotUrl;
      _previousPanValue = _panController.value;

      _currentGame = nextGame;
      _currentScreenshotUrl = nextScreenshotUrl;
    });

    _currentGameIndex = (_currentGameIndex + 1) % widget.playingGames.length;
    _panController.forward(from: 0.0);
  }

  void _pickPreviousGame() {
    if (widget.playingGames.isEmpty) return;

    _timer?.cancel();
    if (!kDisableCarouselForTests) {
      _timer = Timer.periodic(widget.switchDuration, (timer) {
        _pickNextGame();
      });
    }

    // The current playing index is (_currentGameIndex - 1)
    // The one before that is (_currentGameIndex - 2)
    // We want the new playing index to be (_currentGameIndex - 2)
    // Which means the *next* index (_currentGameIndex) should become (_currentGameIndex - 1)

    final currentPlayingIndex =
        (_currentGameIndex - 1 + widget.playingGames.length) %
        widget.playingGames.length;
    final previousPlayingIndex =
        (currentPlayingIndex - 1 + widget.playingGames.length) %
        widget.playingGames.length;

    final prevGame = widget.playingGames[previousPlayingIndex];
    final prevScreenshotUrl = _getRandomScreenshot(prevGame);

    setState(() {
      _previousGame = _currentGame;
      _previousScreenshotUrl = _currentScreenshotUrl;
      _previousPanValue = _panController.value;

      _currentGame = prevGame;
      _currentScreenshotUrl = prevScreenshotUrl;
    });

    // Update _currentGameIndex so the NEXT one points to the one after the previousPlayingIndex, which is currentPlayingIndex.
    _currentGameIndex = currentPlayingIndex;
    _panController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _panController.dispose();
    _initialFadeController.dispose();
    super.dispose();
  }

  void _navigateToGameDetails(
    Map<String, dynamic> gameData,
    String coverUrl,
    bool autoOpenReview,
  ) {
    final cleanData = Map<String, dynamic>.from(gameData);
    cleanData['cover_url'] = coverUrl;

    // Fallback release_date parsing just in case, similar to GameCard
    if (gameData['first_release_date'] != null) {
      cleanData['release_date'] = DateTime.fromMillisecondsSinceEpoch(
        gameData['first_release_date'] * 1000,
      ).toIso8601String();
    }

    if (gameData['genres'] != null && gameData['genres'] is List) {
      cleanData['genres'] = (gameData['genres'] as List)
          .map((g) => g is Map ? g['name'] : g)
          .toList();
    } else if (gameData['genres'] == null) {
      cleanData['genres'] = [];
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    if (isDesktop) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameDetailsScreen(
            gameData: cleanData,
            autoOpenReview: autoOpenReview,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        enableDrag: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          snap: true,
          builder: (context, scrollController) {
            return GameDetailsScreen(
              gameData: cleanData,
              scrollController: scrollController,
              autoOpenReview: autoOpenReview,
            );
          },
        ),
      );
    }
  }

  Widget _buildPanningImage(String url, double panValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // Paneo súper lento
        final offsetX = (1.0 - (panValue * 2)) * (screenWidth * 0.04);

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Transform.scale(
            scale: 1.08,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildShowcaseLayer(
    Map<String, dynamic> game,
    String? screenshotUrl,
    double panValue,
  ) {
    final gameData = game['games'] ?? {};
    final coverUrl = gameData['cover_url'] as String? ?? '';
    final title = gameData['title'] as String? ?? 'Desconocido';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (screenshotUrl != null)
          _buildPanningImage(screenshotUrl, panValue)
        else
          Container(color: Colors.black),

        Container(color: Colors.black.withValues(alpha: 0.7)),

        // Tap zones for previous and next game
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickPreviousGame,
                child: Container(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickNextGame(manual: true),
                child: Container(),
              ),
            ),
          ],
        ),

        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPortrait = constraints.maxHeight > constraints.maxWidth;

              final textSection = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize
                    .min, // El texto ocupa solo lo que necesita hacia abajo
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: isPortrait ? 42 : 48,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Bienvenido,\n',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: widget.userName,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: isPortrait ? 56 : null,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () =>
                              _navigateToGameDetails(gameData, coverUrl, false),
                          child: RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Helvetica',
                                fontSize: isPortrait ? 22 : 24,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: _randomPrefix,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                TextSpan(
                                  text: title,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text: '?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToGameDetails(gameData, coverUrl, true),
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text('Editar reseña'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              );

              final coverSection = MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      _navigateToGameDetails(gameData, coverUrl, false),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: coverUrl.isNotEmpty
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              width: isPortrait
                                  ? constraints.maxWidth * 0.5
                                  : 240,
                            )
                          : Container(
                              width: isPortrait
                                  ? constraints.maxWidth * 0.5
                                  : 240,
                              height: isPortrait
                                  ? (constraints.maxWidth * 0.5) * 1.4
                                  : 340,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                ),
              );

              if (isPortrait) {
                // Layout fijo para móvil: el texto anclado arriba y la carátula anclada abajo a la derecha
                return Stack(
                  children: [
                    Positioned(
                      top: constraints.maxHeight * 0.10, // Sube el texto
                      left: 24,
                      right: 24,
                      child: textSection,
                    ),
                    Positioned(
                      bottom: constraints.maxHeight * 0.15, // Sube la carátula
                      right: 16,
                      child: coverSection,
                    ),
                  ],
                );
              } else {
                // Layout de escritorio
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48.0,
                    vertical: 32.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: textSection,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: coverSection,
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBars() {
    final count = widget.playingGames.length;
    if (count <= 1) return const SizedBox.shrink();

    final currentIndex = (_currentGameIndex - 1 + count) % count;

    return Row(
      children: List.generate(count, (index) {
        double progress = 0.0;
        if (index < currentIndex) {
          progress = 1.0;
        } else if (index == currentIndex) {
          progress = _panController.value;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGame == null) {
      return Container(color: Colors.black);
    }

    return FadeTransition(
      opacity: _initialFadeController,
      child: AnimatedBuilder(
        animation: _panController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_previousGame != null)
                _buildShowcaseLayer(
                  _previousGame!,
                  _previousScreenshotUrl,
                  _previousPanValue,
                ),

              Opacity(
                opacity: _fadeAnimation.value,
                child: _buildShowcaseLayer(
                  _currentGame!,
                  _currentScreenshotUrl,
                  _panController.value,
                ),
              ),

              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: _buildProgressBars(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
