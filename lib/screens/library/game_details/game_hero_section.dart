import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'game_details_controller.dart';
import 'game_reviews_card.dart';
import '../group_games_screen.dart';
import '../../activity/review_details_screen.dart';
import '../../../models/models.dart';
import '../../../services/igdb_service.dart';
import '../../../repositories/review_repository.dart';
import '../../../widgets/full_screen_gallery.dart';
import '../../../theme/corpus_theme_extension.dart';

class GameHeroSection extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final GameDetailsController controller;
  final bool isDesktop;

  final bool inLibrary;
  final String status;
  final List<Review> reviews;
  final UserProfile? userData;
  final UserProfile? partnerData;
  final List<Map<String, dynamic>> friendsWithGame;
  final bool isGuest;
  final Map<String, dynamic> enrichedData;

  final VoidCallback onShowReviewModal;
  final void Function(Review review) onEditReview;
  final void Function(Review review) onDeleteReview;

  final Widget tabsSliver;
  final Widget tabContentSliver;

  const GameHeroSection({
    super.key,
    required this.gameData,
    required this.controller,
    required this.isDesktop,
    required this.inLibrary,
    required this.status,
    required this.reviews,
    required this.userData,
    required this.partnerData,
    required this.friendsWithGame,
    required this.isGuest,
    required this.enrichedData,
    required this.onShowReviewModal,
    required this.onEditReview,
    required this.onDeleteReview,
    required this.tabsSliver,
    required this.tabContentSliver,
  });

  @override
  State<GameHeroSection> createState() => _GameHeroSectionState();
}

class _GameHeroSectionState extends State<GameHeroSection> {
  String? _selectedScreenshotUrl;
  Timer? _carouselTimer;

  // Función auxiliar para extraer las capturas priorizando siempre gameData pero cayendo en enrichedData
  List _getScreenshots(
    Map<String, dynamic> game,
    Map<String, dynamic> enriched,
  ) {
    return (game['screenshots'] as List?)?.isNotEmpty == true
        ? game['screenshots']!
        : (enriched['screenshots'] as List? ?? []);
  }

  @override
  void initState() {
    super.initState();
    _startCarousel(_getScreenshots(widget.gameData, widget.enrichedData));
  }

  @override
  void didUpdateWidget(covariant GameHeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldSc = _getScreenshots(oldWidget.gameData, oldWidget.enrichedData);
    final newSc = _getScreenshots(widget.gameData, widget.enrichedData);

    // Si las capturas cambian (por ejemplo, cuando _enrichGameData termina de cargar), reiniciamos el carrusel
    if (oldSc.toString() != newSc.toString()) {
      _startCarousel(newSc);
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

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
      if (screenshotsData.length > 1) {
        _carouselTimer?.cancel();
        _carouselTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _selectRandomScreenshot(screenshotsData);
        });
      }
    }
  }

  Future<void> _showFriendGameActivity(
    Map<String, dynamic> user,
    String status,
  ) async {
    final friendId = user['id'];
    if (friendId == null) return;

    final igdbId = widget.gameData['igdb_id'] ?? widget.gameData['id'];
    if (igdbId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ReviewRepository();
      final data = await repo.fetchFriendActivityForGame(
        userId: friendId,
        gameId: igdbId,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (data.review != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewDetailsScreen(
              gameData: widget.gameData,
              userData: user,
              reviewData: data.review!,
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

  Color _friendStatusColor(String status) {
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

  IconData _friendStatusIcon(String status) {
    switch (status) {
      case 'beaten':
        return Icons.check_circle;
      case 'playing':
        return Icons.sports_esports;
      case 'wishlist':
        return Icons.bookmark;
      case 'abandoned':
        return Icons.cancel;
      case 'on_hold':
        return Icons.pause_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _friendStatusLabel(String status) {
    switch (status) {
      case 'beaten':
        return 'Terminado';
      case 'playing':
        return 'Jugando';
      case 'wishlist':
        return 'Lo quiere';
      case 'abandoned':
        return 'Abandonado';
      case 'on_hold':
        return 'En pausa';
      default:
        return 'Desconocido';
    }
  }

  Widget _buildFriendsWithGame(BuildContext context) {
    if (widget.friendsWithGame.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          bottom: 8,
          left: widget.isDesktop ? 0 : 24,
          right: widget.isDesktop ? 0 : 24,
        ),
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
              children: widget.friendsWithGame.map((f) {
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
      ),
    );
  }

  Widget _buildStatusButton() {
    if (widget.isGuest) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: Text('Iniciar sesión para registrar'),
        ),
      );
    }

    final color = widget.inLibrary
        ? _friendStatusColor(widget.status)
        : Theme.of(context).colorScheme.primary;

    String btnText = 'Añadir a Biblioteca';
    if (widget.inLibrary) {
      switch (widget.status) {
        case 'beaten':
          btnText = 'Terminado';
          break;
        case 'playing':
          btnText = 'Jugando';
          break;
        case 'wishlist':
          btnText = 'Quiero';
          break;
        case 'abandoned':
          btnText = 'Abandonado';
          break;
        case 'on_hold':
          btnText = 'En Pausa';
          break;
      }
    }

    final icon = widget.inLibrary
        ? _friendStatusIcon(widget.status)
        : Icons.add;
    final textColor = color == Theme.of(context).colorScheme.secondary
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.white;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.inLibrary) {
                  widget.onEditReview(
                    widget.reviews.isNotEmpty
                        ? widget.reviews.first
                        : Review(
                            id: '',
                            userId: widget.userData!.id,
                            gameId: (widget.gameData['id'] as num).toInt(),
                            rating: 0,
                            ratingGameplay: 0,
                            ratingNarrative: 0,
                            ratingSoundtrack: 0,
                            ratingVisuals: 0,
                            status: GameStatus.values.firstWhere(
                              (e) => e.name == widget.status,
                              orElse: () => GameStatus.wishlist,
                            ),
                            completionType: '',
                            isReplay: false,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                  );
                } else {
                  widget.onShowReviewModal();
                }
              },
              icon: Icon(icon, color: textColor),
              label: Text(
                btnText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusMedium,
                ),
                elevation: widget.inLibrary ? 0 : 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CORRECCIÓN: Usar fallbacks para la carátula (DB -> IGDB API anidada -> Enriched Data)
    final String? coverUrl =
        widget.gameData['cover_url'] ??
        widget.enrichedData['cover_url'] ??
        (widget.gameData['cover']?['image_id'] != null
            ? IGDBService.getCoverUrl(widget.gameData['cover']['image_id'])
            : null);

    // CORRECCIÓN: Usar fallbacks para el título (DB 'title' -> IGDB API 'name' -> Enriched Data)
    final String name =
        widget.gameData['title'] ??
        widget.gameData['name'] ??
        widget.enrichedData['title'] ??
        widget.enrichedData['name'] ??
        'Desconocido';

    final hasDeveloper =
        widget.gameData['developer'] != null &&
        widget.gameData['developer'] != 'Desconocido' &&
        widget.gameData['developer'] != 'Desarrollador desconocido';
    final developer = hasDeveloper
        ? widget.gameData['developer']
        : (widget.enrichedData['developer'] ?? 'Desconocido');
    final developerId =
        widget.gameData['developer_id'] ?? widget.enrichedData['developer_id'];

    String releaseDate = 'Fecha desconocida';
    final rawReleaseDate =
        widget.gameData['release_date'] ?? widget.enrichedData['release_date'];
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
    final coverArtWidget = Container(
      decoration: BoxDecoration(
        borderRadius: ext.radiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ext.radiusMedium,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: coverUrl != null
              ? Image.network(coverUrl, fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.videogame_asset, size: 50),
                ),
        ),
      ),
    );

    final headerInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        InkWell(
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
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    developer,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              releaseDate,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ],
    );

    final interactiveWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusButton(),
        GameReviewsCard(
          reviews: widget.reviews,
          gameData: widget.gameData,
          userData: widget.userData,
          partnerData: widget.partnerData,
          isDesktop: widget.isDesktop,
          onEditReview: widget.onEditReview,
          onDeleteReview: widget.onDeleteReview,
          onShowFullScreenGallery: (context, urls, index) =>
              showFullScreenGallery(context, urls, index),
        ),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _GameDetailsHeaderDelegate(
            topPadding: MediaQuery.of(context).padding.top,
            backgroundColor: theme.scaffoldBackgroundColor,
            title: name,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            background: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    child: _selectedScreenshotUrl != null
                        ? Image.network(
                            _selectedScreenshotUrl!,
                            key: ValueKey(_selectedScreenshotUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : (coverUrl != null
                              ? Image.network(
                                  coverUrl.replaceAll('t_cover_big', 't_1080p'),
                                  key: ValueKey(coverUrl),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  alignment: Alignment.topCenter,
                                )
                              : Container(
                                  key: const ValueKey('placeholder'),
                                  color: theme.scaffoldBackgroundColor,
                                )),
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
                Positioned(
                  top: -2,
                  bottom: -2,
                  left: 0,
                  right: 0,
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
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.3),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.15),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.isDesktop)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 24.0,
            ),
            sliver: SliverCrossAxisGroup(
              slivers: [
                SliverConstrainedCrossAxis(
                  maxExtent: 280,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            coverArtWidget,
                            const SizedBox(height: 24),
                            interactiveWidget,
                          ],
                        ),
                      ),
                      _buildFriendsWithGame(context),
                    ],
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
                      widget.tabsSliver,
                      widget.tabContentSliver,
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SliverMainAxisGroup(
            slivers: [
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
                    ],
                  ),
                ),
              ),
              _buildFriendsWithGame(context),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              widget.tabsSliver,
              widget.tabContentSliver,
            ],
          ),
      ],
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

    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -shrinkOffset * 0.5,
            left: 0,
            right: 0,
            height: maxExtent,
            child: background,
          ),
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: 56.0,
            child: Container(
              color: backgroundColor.withValues(alpha: titleOpacity * 0.9),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _GameDetailsHeaderDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        background != oldDelegate.background ||
        leading != oldDelegate.leading ||
        title != oldDelegate.title ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
