import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../globals.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/corpus_primary_button.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/typewriter_text.dart';
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

  static Duration get defaultSwitchDuration =>
      kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 10);

  @override
  State<HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<HeroShowcase>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _currentGameIndex = 0;
  bool _titleTyped = false;

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

  Widget _buildShowcaseLayer(
    Map<String, dynamic> game,
    String? screenshotUrl,
    double panValue,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (screenshotUrl != null)
          _buildPanningImageLayer(
            NetworkImage(screenshotUrl),
            panValue,
            MediaQuery.sizeOf(context).width,
          )
        else
          Container(color: Colors.black),
        Container(color: Colors.black.withValues(alpha: 0.7)),
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

    // La UI de texto (carátula, título, botón...) se pasa como `child` del
    // AnimatedBuilder exterior para no reconstruirse en cada frame del paneo.
    // Las barras de progreso se envuelven en su propio AnimatedBuilder para que
    // se animen y llenen gradualmente al ritmo de _panController.
    final staticOverlay = Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: AnimatedBuilder(
                  animation: _panController,
                  builder: (context, _) => _buildProgressBars(),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return FadeTransition(
      opacity: _initialFadeController,
      child: AnimatedBuilder(
        animation: _panController,
        // child NO se reconstruye en cada frame: contiene el overlay estático
        child: staticOverlay,
        builder: (context, child) {
          final gameData = _currentGame!['games'] ?? {};
          final coverUrl = gameData['cover_url'] as String? ?? '';
          final title = gameData['title'] as String? ?? 'Desconocido';

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

              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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

              const _BottomFadeGradient(),

              RepaintBoundary(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isPortrait =
                          constraints.maxHeight > constraints.maxWidth;

                      final textSection = Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CorpusHeroTitle(
                            prefix: 'Bienvenido,',
                            highlight: widget.userName,
                            animated: true,
                            instant: _titleTyped,
                            onAnimationComplete: () {
                              if (!_titleTyped && mounted) {
                                setState(() => _titleTyped = true);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: isPortrait ? 56 : null,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _navigateToGameDetails(
                                    gameData,
                                    coverUrl,
                                    false,
                                  ),
                                  child: TypewriterText(
                                    baseCharDuration: const Duration(
                                      milliseconds: 15,
                                    ),
                                    instant: false,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isPortrait ? 22 : 24,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    spans: [
                                      TextSpan(
                                        text: _randomPrefix,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
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
                          const SizedBox(height: 24),
                          CorpusPrimaryButton(
                            onPressed: () => _navigateToGameDetails(gameData, coverUrl, true),
                            icon: Icons.edit,
                            label: 'Editar reseña',
                          ),
                        ],
                      );

                      final coverSection = AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        child: MouseRegion(
                          key: ValueKey(coverUrl),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _navigateToGameDetails(
                              gameData,
                              coverUrl,
                              false,
                            ),
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
                                borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusLarge,
                                child: coverUrl.isNotEmpty
                                    ? Image.network(
                                        coverUrl,
                                        fit: BoxFit.cover,
                                        width: isPortrait
                                            ? constraints.maxWidth * 0.38
                                            : 240,
                                      )
                                    : Container(
                                        width: isPortrait ? constraints.maxWidth * 0.38 : 240,
                                        height: isPortrait ? (constraints.maxWidth * 0.38) * 1.4 : 340,
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      );

                      if (isPortrait) {
                        return Stack(
                          children: [
                            Positioned(
                              top: constraints.maxHeight * 0.10,
                              left: 24,
                              right: 24,
                              child: textSection,
                            ),
                            Positioned(
                              bottom: 32,
                              right: 16,
                              child: coverSection,
                            ),
                          ],
                        );
                      } else {
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
              ),
              ?child,
            ],
          );
        },
      ),
    );
  }
}

/// Versión del hero para la pantalla de Inicio en modo invitado.
///
/// Visualmente casi idéntica al HeroShowcase real (mismo crossfade + paneo
/// lento de fondo), pero:
/// - No es interactiva: sin zonas táctiles para pasar de captura, sin carátula.
/// - Sin barra de progreso arriba.
/// - Las capturas son fijas, de un puñado de juegos conocidos (no dependen
///   de la biblioteca del usuario, porque no hay usuario).
/// - En vez del "Bienvenido, X" muestra el mensaje + botón de login.
class GuestHeroShowcase extends StatefulWidget {
  final Duration switchDuration;

  const GuestHeroShowcase({
    super.key,
    this.switchDuration = const Duration(seconds: 10),
  });

  static Duration get defaultSwitchDuration =>
      kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 10);

  @override
  State<GuestHeroShowcase> createState() => _GuestHeroShowcaseState();
}

class _GuestHeroShowcaseState extends State<GuestHeroShowcase>
    with TickerProviderStateMixin {
  // Capturas en alta resolución fijas (assets) para el fondo del modo invitado.
  static const List<String> _hardcodedImages = [
    'assets/guest_showcase/cyberpunk01.jpg',
    'assets/guest_showcase/rdr201.jpg',
    'assets/guest_showcase/eldenring01.jpg',
    'assets/guest_showcase/tlou201.jpg',
    'assets/guest_showcase/ghostoftsushima01.jpg',
    'assets/guest_showcase/deathstranding01.jpg',
    'assets/guest_showcase/godofwar01.jpg',

    'assets/guest_showcase/cyberpunk02.jpg',
    'assets/guest_showcase/rdr202.jpg',
    'assets/guest_showcase/eldenring02.jpg',
    'assets/guest_showcase/tlou202.jpg',
    'assets/guest_showcase/ghostoftsushima02.jpg',
    'assets/guest_showcase/deathstranding02.jpg',
    'assets/guest_showcase/godofwar02.jpg',

    'assets/guest_showcase/cyberpunk03.jpg',
    'assets/guest_showcase/rdr203.jpg',
    'assets/guest_showcase/eldenring03.jpg',
    'assets/guest_showcase/tlou203.jpg',
    'assets/guest_showcase/ghostoftsushima03.jpg',
    'assets/guest_showcase/deathstranding03.jpg',
    'assets/guest_showcase/godofwar03.jpg',
  ];

  Timer? _timer;
  int _nextIndex = 0;

  String? _previousScreenshotUrl;
  double _previousPanValue = 1.0;
  String? _currentScreenshotUrl;

  final Random _random = Random();

  late AnimationController _panController;
  late AnimationController _initialFadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
        curve: const Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );
    _loadShowcaseScreenshots();
  }

  void _loadShowcaseScreenshots() {
    final startIndex = _random.nextInt(_hardcodedImages.length);
    setState(() {
      _currentScreenshotUrl = _hardcodedImages[startIndex];
      _nextIndex = (startIndex + 1) % _hardcodedImages.length;
    });

    _initialFadeController.forward();
    _panController.forward(from: 0.0);

    if (!kDisableCarouselForTests) {
      _timer = Timer.periodic(widget.switchDuration, (timer) {
        _pickNextScreenshot();
      });
    }
  }

  void _pickNextScreenshot() {
    if (_hardcodedImages.isEmpty) return;

    setState(() {
      _previousScreenshotUrl = _currentScreenshotUrl;
      _previousPanValue = _panController.value;
      _currentScreenshotUrl = _hardcodedImages[_nextIndex];
    });

    _nextIndex = (_nextIndex + 1) % _hardcodedImages.length;
    _panController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _panController.dispose();
    _initialFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _initialFadeController,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo negro permanente para que el primer frameBuilder haga el fade de negro a la imagen
          Container(color: Colors.black),

          if (_currentScreenshotUrl != null)
            AnimatedBuilder(
              animation: _panController,
              builder: (context, child) {
                final sw = MediaQuery.sizeOf(context).width;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_previousScreenshotUrl != null)
                      _buildPanningImageLayer(
                        AssetImage(_previousScreenshotUrl!),
                        _previousPanValue,
                        sw,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      ),
                    Opacity(
                      opacity: _previousScreenshotUrl == null
                          ? 1.0
                          : _fadeAnimation.value,
                      child: _buildPanningImageLayer(
                        AssetImage(_currentScreenshotUrl!),
                        _panController.value,
                        sw,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      ),
                    ),
                  ],
                );
              },
            ),

          // Mismo oscurecido que usa el hero real para que el texto se lea bien.
          Container(color: Colors.black.withValues(alpha: 0.7)),

          // Degradado inferior para fundir a negro suavemente
          const _BottomFadeGradient(),

          RepaintBoundary(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isPortrait =
                      constraints.maxHeight > constraints.maxWidth;

                  final textSection = Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TypewriterText(
                        style: TextStyle(
                          fontFamily: Theme.of(context).extension<CorpusThemeExtension>()?.heroFontFamily,
                          fontWeight: Theme.of(context).extension<CorpusThemeExtension>()?.heroFontWeight ?? FontWeight.w900,
                          fontSize: isPortrait ? 42 : 48,
                          height: 1.1,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                        spans: [
                          const TextSpan(
                            text: 'Comienza a registrar\ntus juegos ',
                          ),
                          TextSpan(
                            text: 'ahora',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CorpusPrimaryButton(
                        onPressed: () => openLoginScreen(context),
                        icon: Icons.login,
                        label: 'Iniciar sesión',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ],
                  );

                  if (isPortrait) {
                    return Stack(
                      children: [
                        Positioned(
                          top: constraints.maxHeight * 0.10,
                          left: 24,
                          right: 24,
                          child: textSection,
                        ),
                      ],
                    );
                  } else {
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
                          Expanded(flex: 2, child: Container()),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildPanningImageLayer(
  ImageProvider provider,
  double panValue,
  double screenWidth, {
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  // El offsetX se calcula fuera del árbol de widgets — sin layout pass extra por frame
  final offsetX = (1.0 - (panValue * 2)) * (screenWidth * 0.04);

  return Transform.translate(
    offset: Offset(offsetX, 0),
    child: Transform.scale(
      scale: 1.08,
      child: Image(
        image: provider,
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
        errorBuilder: errorBuilder,
      ),
    ),
  );
}

class _BottomFadeGradient extends StatelessWidget {
  const _BottomFadeGradient();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: -1,
      left: 0,
      right: 0,
      height: 350,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 0.7, 1.0],
              colors: [
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.4),
                Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero para usuario logueado sin juegos en "Jugando".
/// Mismo lenguaje visual que GuestHeroShowcase (carrusel de fondo,
/// crossfade, degradado inferior) pero con mensaje y CTA de "añade
/// tu primer juego" en vez de login.
class EmptyPlayingHero extends StatefulWidget {
  final String userName;
  final VoidCallback onSearchPressed;
  final Duration switchDuration;

  const EmptyPlayingHero({
    super.key,
    required this.userName,
    required this.onSearchPressed,
    this.switchDuration = const Duration(seconds: 10),
  });

  static Duration get defaultSwitchDuration =>
      kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 10);

  @override
  State<EmptyPlayingHero> createState() => _EmptyPlayingHeroState();
}

class _EmptyPlayingHeroState extends State<EmptyPlayingHero>
    with TickerProviderStateMixin {
  static const List<String> _hardcodedImages = [
    'assets/guest_showcase/cyberpunk01.jpg',
    'assets/guest_showcase/rdr201.jpg',
    'assets/guest_showcase/eldenring01.jpg',
    'assets/guest_showcase/tlou201.jpg',
    'assets/guest_showcase/ghostoftsushima01.jpg',
    'assets/guest_showcase/deathstranding01.jpg',
    'assets/guest_showcase/godofwar01.jpg',
  ];

  Timer? _timer;
  int _nextIndex = 0;
  String? _previousScreenshotUrl;
  double _previousPanValue = 1.0;
  String? _currentScreenshotUrl;
  final Random _random = Random();

  late AnimationController _panController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _panController = AnimationController(
      vsync: this,
      duration: widget.switchDuration,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _panController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );

    final startIndex = _random.nextInt(_hardcodedImages.length);
    _currentScreenshotUrl = _hardcodedImages[startIndex];
    _nextIndex = (startIndex + 1) % _hardcodedImages.length;
    _panController.forward(from: 0.0);

    if (!kDisableCarouselForTests) {
      _timer = Timer.periodic(widget.switchDuration, (_) => _pickNext());
    }
  }

  void _pickNext() {
    setState(() {
      _previousScreenshotUrl = _currentScreenshotUrl;
      _previousPanValue = _panController.value;
      _currentScreenshotUrl = _hardcodedImages[_nextIndex];
    });
    _nextIndex = (_nextIndex + 1) % _hardcodedImages.length;
    _panController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_currentScreenshotUrl != null)
          AnimatedBuilder(
            animation: _panController,
            builder: (context, child) {
              final sw = MediaQuery.sizeOf(context).width;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (_previousScreenshotUrl != null)
                    _buildPanningImageLayer(
                      AssetImage(_previousScreenshotUrl!),
                      _previousPanValue,
                      sw,
                      errorBuilder: (_, _, _) => Container(color: Colors.black),
                    ),
                  Opacity(
                    opacity: _previousScreenshotUrl == null
                        ? 1.0
                        : _fadeAnimation.value,
                    child: _buildPanningImageLayer(
                      AssetImage(_currentScreenshotUrl!),
                      _panController.value,
                      sw,
                      errorBuilder: (_, _, _) => Container(color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          ),
        Container(
          color: Colors.black.withValues(alpha: 0.75),
        ), // un pelín más oscuro que el guest hero, aquí no hay foco en la imagen
        const _BottomFadeGradient(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPortrait = constraints.maxHeight > constraints.maxWidth;

              final textSection = Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CorpusHeroTitle(
                    prefix: 'Bienvenido,',
                    highlight: widget.userName,
                  ),
                  const SizedBox(height: 16),
                  TypewriterText(
                    baseCharDuration: const Duration(milliseconds: 15),
                    style: TextStyle(
                      fontFamily: Theme.of(context).extension<CorpusThemeExtension>()?.heroFontFamily,
                      fontSize: isPortrait ? 20 : 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                    spans: const [TextSpan(text: '¿Qué vas a jugar hoy?')],
                  ),
                  const SizedBox(height: 24),
                  CorpusPrimaryButton(
                    onPressed: widget.onSearchPressed,
                    icon: Icons.search,
                    label: 'Buscar un juego',
                  ),
                ],
              );

              if (isPortrait) {
                return Stack(
                  children: [
                    Positioned(
                      top: constraints.maxHeight * 0.10,
                      left: 24,
                      right: 24,
                      child: textSection,
                    ),
                  ],
                );
              }
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
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
