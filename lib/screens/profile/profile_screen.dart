import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/corpus_network_image.dart';
import '../library/game_details_screen.dart';
import '../settings_screen.dart';
import 'achievements_screen.dart';
import '../../utils/level_calculator.dart';
import '../../widgets/game_card.dart';
import '../../models/models.dart';
import '../social/friends_screen.dart';
import 'profile_achievements_tab.dart';
import 'profile_journal_tab.dart';
import 'profile_reviews_tab.dart';
import 'profile_games_grid_tab.dart';
import 'currently_playing_badge.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../utils/format_utils.dart';

import 'profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  /// Si se proporciona, muestra el perfil de ese usuario. Si no, el propio.
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  int _selectedTab = 0;
  String? _juegosStatusFilter;

  bool get _isLoading => _controller.isLoading;
  Map<String, dynamic>? get _userProfile => _controller.userProfile;
  List<Map<String, dynamic>> get _wishlistGames => _controller.wishlistGames;
  List<Map<String, dynamic>> get _playingGames => _controller.playingGames;
  List<Map<String, dynamic>> get _beatenGames => _controller.beatenGames;
  List<Map<String, dynamic>> get _platinumGames => _controller.platinumGames;
  List<double> get _ratings => _controller.ratings;
  List<Map<String, dynamic>?> get _hallOfFame => _controller.hallOfFame;

  bool get _isOwnProfile => _controller.isOwnProfile;
  bool get _isGuestProfile => _controller.isGuestProfile;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _tabsKey = GlobalKey();

  void _scrollToTabs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isDesktop = MediaQuery.of(context).size.width >= 800;

      if (isDesktop) {
        if (_tabsKey.currentContext != null) {
          Scrollable.ensureVisible(
            _tabsKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.0,
          );
        }
      } else {
        if (_scrollController.hasClients) {
          // Banner es 150, más el colapso del header (~60-82).
          // 210 alinea exactamente la lista justo debajo de las tabs contraídas.
          _scrollController.animateTo(
            210.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(userId: widget.userId);
    if (!_controller.isGuestProfile) {
      libraryUpdateNotifier.addListener(_onLibraryUpdated);
    }
  }

  @override
  void dispose() {
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      _controller.fetchProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_isGuestProfile) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: GuestLoginPrompt(
                message: 'Inicia sesión para ver y personalizar tu perfil.',
              ),
            ),
          );
        }

        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_controller.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('No se pudo cargar el perfil.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      _controller.fetchProfileData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final isDesktop = MediaQuery.of(context).size.width > 800;

        final topPadding = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Scrollbar(
            controller: _scrollController,
            thumbVisibility: isDesktop,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (isDesktop) ...[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDesktop: true),
                        // Espacio para el overflow del avatar (radio 60+borde 4 = 64px sobresalto)
                        // La barra de nivel ya va DENTRO del header en el Positioned
                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                  // Línea separadora full-width entre la zona superior y el contenido
                  SliverToBoxAdapter(
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(
                        key: _tabsKey,
                        child: _buildNavBar(isDesktop: true),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        sliver: SliverCrossAxisGroup(
                          slivers: [
                            SliverConstrainedCrossAxis(
                              maxExtent: 300,
                              sliver: SliverToBoxAdapter(
                                child: Transform.translate(
                                  // Desplazamos la sidebar hacia arriba para que "Bio" se alinee visualmente
                                  // con el texto de las tabs, que tienen padding y ocupan 56px de alto
                                  offset: const Offset(0, -40),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [_buildSidebarInfo()],
                                  ),
                                ),
                              ),
                            ),
                            const SliverConstrainedCrossAxis(
                              maxExtent: 40,
                              sliver: SliverToBoxAdapter(
                                child: SizedBox.shrink(),
                              ),
                            ),
                            SliverCrossAxisExpanded(
                              flex: 1,
                              sliver: _buildCurrentTabContent(isMobile: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SliverToBoxAdapter(child: _buildMobileBanner()),
                  SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(child: SizedBox.shrink(key: _tabsKey)),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _MobileProfileHeaderDelegate(
                          topPadding: topPadding,
                          hasCurrentlyPlaying:
                              _userProfile?['currently_playing_appid'] != null,
                          profileBuilder: _buildMobileProfileRow,
                          tabBarBuilder: () => _buildNavBar(isDesktop: false),
                        ),
                      ),
                      _buildCurrentTabContent(isMobile: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBanner() {
    final bannerUrl = _userProfile?['banner_url'];
    final isMe =
        _userProfile?['id'] != null &&
        _userProfile!['id'] == Supabase.instance.client.auth.currentUser?.id;
    // Misma altura de layout y de imagen: no pintar fuera de la caja
    // (eso tapaba el avatar/nombre del header sticky).
    const bannerHeight = 150.0;
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          if (bannerUrl == null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade800, Colors.red.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            )
          else
            CorpusNetworkImage(
              url: bannerUrl.replaceAll('t_cover_big', 't_1080p'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade800, Colors.red.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 0.78, 1.0],
                  colors: [
                    Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                    Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.15),
                    Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.55),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
          if (Navigator.canPop(context))
            Positioned(
              top: topInset + 4.0,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          if (isMe)
            Positioned(
              top: topInset + 4.0,
              right: 4,
              child: Row(
                children: [
                  _FriendsBadgeButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendsScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            userProfile: _userProfile!,
                            hallOfFame: _hallOfFame,
                          ),
                        ),
                      ).then((_) => _controller.fetchProfileData());
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileProfileRow(double collapseProgress) {
    final username = _userProfile?['username'] ?? 'Jugador';
    final displayName = _userProfile?['display_name'] ?? username;
    final avatarUrl = _userProfile?['avatar_url'];
    final t = collapseProgress.clamp(0.0, 1.0);

    final nameFontSize = 22.0 - (4.0 * t);
    final handleFontSize = 13.0 - (1.0 * t);
    const nameHandleGap = 2.0;
    // Colapsado: misma altura que nombre + @.
    const expandedAvatarRadius = 40.0;
    final collapsedAvatarRadius =
        (nameFontSize * 1.1 + nameHandleGap + handleFontSize * 1.1) / 2;
    final avatarRadius =
        expandedAvatarRadius -
        (expandedAvatarRadius - collapsedAvatarRadius) * t;
    final showLevel = t < 0.5;
    final showPlaying = t < 0.35 && _userProfile != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8.0 - (2.0 * t), 16, 8.0 - (2.0 * t)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2.5 - (0.5 * t),
              ),
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: avatarRadius)
                  : null,
            ),
          ),
          SizedBox(width: 12.0 - (2.0 * t)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: nameHandleGap),
                Row(
                  children: [
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: handleFontSize,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                    if (showPlaying && _userProfile != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: CurrentlyPlayingBadge(
                          userId: _userProfile!['id'],
                          initialProfile: _userProfile!,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                ),
                if (showLevel) ...[
                  SizedBox(height: 4.0 - (1.0 * t)),
                  _buildInlineLevelProgress(compact: t > 0.25),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineLevelProgress({bool compact = false}) {
    final xp = (_userProfile?['xp'] as num?)?.toInt() ?? 0;
    final levelLabelSize = compact ? 13.0 : 15.0;
    final progressLabelSize = compact ? 12.0 : 13.0;
    final barHeight = compact ? 6.0 : 8.0;
    final spacing = compact ? 4.0 : 6.0;

    return InkWell(
      borderRadius: Theme.of(
        context,
      ).extension<CorpusThemeExtension>()!.radiusSmall,
      onTap: _isOwnProfile
          ? () {
              final userId =
                  _userProfile?['id'] ??
                  Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AchievementsScreen(userId: userId, initialXp: xp),
                ),
              ).then((_) => _controller.fetchProfileData());
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nivel ${LevelCalculator.getLevel(xp)}',
                style: TextStyle(
                  fontSize: levelLabelSize,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                LevelCalculator.getProgressString(xp),
                style: TextStyle(
                  fontSize: progressLabelSize,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          ClipRRect(
            borderRadius: Theme.of(
              context,
            ).extension<CorpusThemeExtension>()!.radiusSmall,
            child: LinearProgressIndicator(
              value: LevelCalculator.getProgressFraction(xp),
              minHeight: barHeight,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isDesktop}) {
    final username = _userProfile?['username'] ?? 'Jugador';
    final displayName = _userProfile?['display_name'] ?? username;
    final avatarUrl = _userProfile?['avatar_url'];
    final bannerUrl = _userProfile?['banner_url'];
    final isMe =
        _userProfile?['id'] != null &&
        _userProfile!['id'] == Supabase.instance.client.auth.currentUser?.id;

    // Altura de LAYOUT calculada para mantener siempre un aspecto 3:1
    // Limitamos la altura máxima en PC para que no ocupe media pantalla.
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = (screenWidth / 3).clamp(120.0, 340.0);

    // Altura VISUAL de la imagen igual al layout para que
    // el espacio y las proporciones sean consistentes en PC y móvil.
    final bannerImageHeight = bannerHeight;

    return SizedBox(
      height: bannerHeight + 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner — ahora Positioned con su propia altura, mayor que
          // la del SizedBox que lo contiene. El sobrante se pinta por
          // debajo, detrás del avatar y de la barra de nivel.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerImageHeight,
            child: bannerUrl == null
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade800,
                          Colors.red.shade900,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  )
                : CorpusNetworkImage(
                    url: bannerUrl.replaceAll('t_cover_big', 't_1080p'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade800,
                            Colors.red.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
          ),

          // Degradado inferior — misma altura que la imagen, para que
          // el fundido recorra todo el tramo añadido y llegue negro
          // del todo justo por la zona de la barra de nivel.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height:
                bannerImageHeight +
                2, // Se extiende 2px por debajo para tapar la costura
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 0.62, 0.72, 0.81, 0.89, 0.96, 1.0],
                    colors: [
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.08),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.22),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.42),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.65),
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.85),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back Button (if navigated from another screen)
          if (Navigator.canPop(context))
            Positioned(
              top:
                  MediaQuery.of(context).padding.top + (isDesktop ? 10.0 : 4.0),
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),

          // Buttons: Friends + Settings
          if (isMe)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top + (isDesktop ? 10.0 : 4.0),
              right: 4,
              child: Row(
                children: [
                  _FriendsBadgeButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendsScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            userProfile: _userProfile!,
                            hallOfFame: _hallOfFame,
                          ),
                        ),
                      ).then((_) => _controller.fetchProfileData());
                    },
                  ),
                ],
              ),
            ),

          Positioned(
            bottom: 20,
            left: isDesktop ? 40 : 16,
            right: isDesktop ? 40 : null, // en desktop ocupa todo el ancho
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).shadowColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: isDesktop ? 60 : 45,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Icon(Icons.person, size: isDesktop ? 60 : 40)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                if (isDesktop)
                  // En desktop: Column expandida con nombre, @+jugando y barra de nivel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(-1, -1),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1, -1),
                                color: Colors.black,
                              ),
                              Shadow(offset: Offset(1, 1), color: Colors.black),
                              Shadow(
                                offset: Offset(-1, 1),
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(-1, -1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(1, -1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(1, 1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(-1, 1),
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                            if (_userProfile != null) ...[
                              const SizedBox(width: 10),
                              CurrentlyPlayingBadge(
                                userId: _userProfile!['id'],
                                initialProfile: _userProfile!,
                                inline: true,
                              ),
                            ],
                          ],
                        ),
                        // Barra de nivel: ancho acotado (no full-width)
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: _buildInlineLevelProgress(compact: false),
                        ),
                      ],
                    ),
                  )
                else
                  // En móvil: Padding que sube los textos sobre el banner
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(-1, -1),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1, -1),
                                color: Colors.black,
                              ),
                              Shadow(offset: Offset(1, 1), color: Colors.black),
                              Shadow(
                                offset: Offset(-1, 1),
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(-1, -1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(1, -1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(1, 1),
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(-1, 1),
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                            if (_userProfile != null) ...[
                              const SizedBox(width: 10),
                              CurrentlyPlayingBadge(
                                userId: _userProfile!['id'],
                                initialProfile: _userProfile!,
                                inline: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar({required bool isDesktop}) {
    return Container(
      margin: EdgeInsets.only(
        left: isDesktop ? 380 : 16,
        right: isDesktop ? 40 : 16,
      ),
      decoration: isDesktop
          ? BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor)
          : BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
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
            _buildNavTab('Perfil', 0, compact: !isDesktop),
            _buildNavTab('Juegos', 1, compact: !isDesktop),
            _buildNavTab('Diario', 2, compact: !isDesktop),
            _buildNavTab('Reseñas', 3, compact: !isDesktop),
            _buildNavTab('Logros', 4, compact: !isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(String title, int index, {bool compact = false}) {
    final isSelected = _selectedTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _scrollToTabs();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 12 : 16,
            horizontal: compact ? 16 : 20,
          ),
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
              fontSize: compact ? 15 : 16,
              height: 1.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // (Layout methods removed for CustomScrollView approach)

  Widget _buildCurrentTabContent({bool isMobile = false}) {
    final userId =
        _userProfile?['id'] ??
        widget.userId ??
        Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_selectedTab == 0) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (isMobile) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSidebarInfo(isMobile: true),
              ),
              const SizedBox(height: 24),
            ],
            _buildHallOfFame(),
            const SizedBox(height: 32),
            _buildGiantStatsRow(isMobile: isMobile),
            const SizedBox(height: 32),
            _buildGamesTab(),
            if (isMobile) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRatingsHistogram(),
              ),
            ],
            SizedBox(height: getBottomSpacer(context)),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      // Juegos
      return ProfileGamesGridTab(
        userId: userId,
        status: _juegosStatusFilter,
        onReturn: _controller.fetchProfileData,
        scrollController: _scrollController,
      );
    } else if (_selectedTab == 2) {
      // Diario
      return ProfileJournalTab(
        userId: userId,
        userData: _userProfile,
        scrollController: _scrollController,
      );
    } else if (_selectedTab == 3) {
      // Reseñas
      return ProfileReviewsTab(
        userId: userId,
        userData: _userProfile,
        scrollController: _scrollController,
      );
    } else if (_selectedTab == 4) {
      // Logros
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(
            left: isMobile ? 16 : 0,
            right: isMobile ? 16 : 0,
            top: 24,
          ),
          child: ProfileAchievementsTab(
            userId: userId,
            isOwnProfile: _isOwnProfile,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSidebarInfo({bool isMobile = false}) {
    final bio = _userProfile?['bio'];
    final platforms = List<String>.from(_userProfile?['platforms'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio != null && bio.isNotEmpty) ...[
          Text(
            'Bio',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(bio, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
        ],
        if (!isMobile) _buildRatingsHistogram(),
        if (platforms.isNotEmpty) ...[
          Text(
            'Plataformas',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms.map((p) => _buildPlatformIcon(p)).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildRatingsHistogram() {
    final ratings = _ratings.where((r) => r > 0).toList();

    if (ratings.isEmpty) return const SizedBox.shrink();

    final List<int> buckets = List.filled(10, 0);
    double sum = 0;
    for (var r in ratings) {
      sum += r;
      int bucketIndex = (r.floor() - 1).clamp(0, 9);
      buckets[bucketIndex]++;
    }

    final maxCount = buckets.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    final avgRating = sum / ratings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Calificaciones',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${ratings.length} | ${formatRating(avgRating)} ★ Media',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(10, (index) {
              final count = buckets[index];
              final heightRatio = maxCount > 0 ? count / maxCount : 0.0;
              final barHeight = 80 * heightRatio;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Tooltip(
                    message: 'Nota ${index + 1}: $count juegos',
                    child: Container(
                      height: barHeight > 0
                          ? (barHeight < 4 ? 4 : barHeight)
                          : 0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1★',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Text(
              '10★',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGiantStatsRow({bool isMobile = false}) {
    final stats = [
      _buildGiantStat(
        _controller.beatenCount.toString().padLeft(3, '0'),
        'Completados',
        () {
          setState(() {
            _juegosStatusFilter = 'beaten';
            _selectedTab = 1;
          });
          _scrollToTabs();
        },
      ),
      _buildGiantStat(
        _controller.platinumCount.toString().padLeft(3, '0'),
        'Platinos',
        () {
          setState(() {
            _juegosStatusFilter = 'completed';
            _selectedTab = 1;
          });
          _scrollToTabs();
        },
      ),
      _buildGiantStat(
        _controller.playingCount.toString().padLeft(3, '0'),
        'Jugando',
        () {
          setState(() {
            _juegosStatusFilter = 'playing';
            _selectedTab = 1;
          });
          _scrollToTabs();
        },
      ),
      _buildGiantStat(
        _controller.wishlistCount.toString().padLeft(3, '0'),
        'En Wishlist',
        () {
          if (_controller.wishlistCount > 0) {
            setState(() {
              _juegosStatusFilter = 'wishlist';
              _selectedTab = 1;
            });
            _scrollToTabs();
          }
        },
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      child: isMobile
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [stats[0], stats[1]],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [stats[2], stats[3]],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: stats,
            ),
    );
  }

  Widget _buildGiantStat(String number, String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHallOfFame() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Hall of Fame',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final game = _hallOfFame[index];
                  final isNumberOne = index == 2;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AspectRatio(
                        aspectRatio: 0.72,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (isNumberOne)
                              Positioned(
                                top: -4,
                                bottom: -4,
                                left: -4,
                                right: -4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    if (game != null) {
                                      final isDesktop =
                                          MediaQuery.of(context).size.width >
                                          800;
                                      if (isDesktop) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                GameDetailsScreen(
                                                  gameData: game,
                                                ),
                                          ),
                                        ).then(
                                          (_) => _controller.fetchProfileData(),
                                        );
                                      } else {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: false,
                                          enableDrag: true,
                                          builder: (context) =>
                                              DraggableScrollableSheet(
                                                initialChildSize: 1.0,
                                                minChildSize: 0.5,
                                                maxChildSize: 1.0,
                                                expand: false,
                                                snap: true,
                                                builder:
                                                    (
                                                      context,
                                                      scrollController,
                                                    ) {
                                                      return GameDetailsScreen(
                                                        gameData: game,
                                                        scrollController:
                                                            scrollController,
                                                      );
                                                    },
                                              ),
                                        ).then(
                                          (_) => _controller.fetchProfileData(),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child:
                                        game != null &&
                                            game['cover_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            child: CorpusNetworkImage(
                                              url: game['cover_url'].replaceAll(
                                                't_cover_big',
                                                't_1080p',
                                              ),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.add,
                                              color: isNumberOne
                                                  ? Colors.amber.withValues(
                                                      alpha: 0.8,
                                                    )
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (isNumberOne)
                              Positioned(
                                top: -18,
                                left: 0,
                                right: 0,
                                child: Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 26,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, String? status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _juegosStatusFilter = status;
                  _selectedTab = 1;
                });
                _scrollToTabs();
              },
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _juegosStatusFilter = status;
                  _selectedTab = 1;
                });
                _scrollToTabs();
              },
              child: Text(
                'Ver todo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> games) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(width: 110, child: _buildGameCard(game)),
          );
        },
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final userRating = (game['user_rating'] ?? 0).toDouble();
    return GameCard(
      game: Game.fromMap(game),
      isInLibrary: true,
      userRating: userRating,
      onReturn: _controller.fetchProfileData,
    );
  }

  Widget _buildPlatformIcon(String platform) {
    String? imagePath;
    IconData? icon;
    Color color;
    switch (platform) {
      case 'pc':
        icon = Icons.computer;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'linux':
        imagePath = 'assets/images/linux.png';
        color = Colors.orangeAccent.shade700;
        break;
      case 'playstation':
        imagePath = 'assets/images/playstation.png';
        color = Colors.blue;
        break;
      case 'xbox':
        imagePath = 'assets/images/xbox.png';
        color = Colors.green;
        break;
      case 'switch':
        imagePath = 'assets/images/switch.png';
        color = Colors.red;
        break;
      case 'wii':
        imagePath = 'assets/images/wii.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'mac':
        imagePath = 'assets/images/mac.png';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case 'android':
        imagePath = 'assets/images/android.png';
        color = const Color(0xFF3DDC84);
        break;
      case 'nintendo':
        imagePath = 'assets/images/switch.png';
        color = Colors.red;
        break; // Fallback para datos antiguos
      default:
        icon = Icons.device_unknown;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: Theme.of(
          context,
        ).extension<CorpusThemeExtension>()!.radiusSmall,
      ),
      child: imagePath != null
          ? Image.asset(imagePath, width: 24, height: 24, color: color)
          : Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildGamesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_wishlistGames.isNotEmpty) ...[
          _buildSectionTitle('Quiero', _controller.wishlistCount, 'wishlist'),
          _buildCarousel(_wishlistGames),
          const SizedBox(height: 24),
        ],
        if (_playingGames.isNotEmpty) ...[
          _buildSectionTitle('Jugando', _controller.playingCount, 'playing'),
          _buildCarousel(_playingGames),
          const SizedBox(height: 24),
        ],
        if (_beatenGames.isNotEmpty) ...[
          _buildSectionTitle('Completados', _controller.beatenCount, 'beaten'),
          _buildCarousel(_beatenGames),
          const SizedBox(height: 24),
        ],
        if (_platinumGames.isNotEmpty) ...[
          _buildSectionTitle('Platinos', _controller.platinumCount, 'completed'),
          _buildCarousel(_platinumGames),
          const SizedBox(height: 24),
        ],
        if (_beatenGames.isEmpty && _platinumGames.isEmpty && _playingGames.isEmpty && _wishlistGames.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Aún no tienes juegos en tu biblioteca.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón de amigos con badge que muestra las solicitudes pendientes.
class _FriendsBadgeButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _FriendsBadgeButton({required this.onPressed});

  @override
  State<_FriendsBadgeButton> createState() => _FriendsBadgeButtonState();
}

class _FriendsBadgeButtonState extends State<_FriendsBadgeButton> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;
      final data = await Supabase.instance.client
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', myId)
          .eq('status', 'pending');
      if (mounted) {
        setState(() => _pendingCount = (data as List).length);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: _pendingCount > 0,
      label: Text(_pendingCount.toString()),
      child: IconButton(
        icon: const Icon(
          Icons.people_rounded,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
        tooltip: 'Amigos',
        onPressed: () {
          widget.onPressed();
          _loadPendingCount();
        },
      ),
    );
  }
}

class _MobileProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  // Tabs: padding 12*2 + text 15 + borde 3 ≈ 42 → reservamos 48
  static const double _tabBarHeight = 48.0;
  // Expandido: avatar 80 + padding + nivel ≈ 120; +~22 si hay "Jugando"
  static const double _expandedProfileHeight = 120.0;
  static const double _playingExtraHeight = 22.0;
  // Colapsado: avatar ≈ nombre+@ (~40) + padding ≈ 60
  static const double _collapsedProfileHeight = 60.0;

  final double topPadding;
  final bool hasCurrentlyPlaying;
  final Widget Function(double collapseProgress) profileBuilder;
  final Widget Function() tabBarBuilder;

  _MobileProfileHeaderDelegate({
    required this.topPadding,
    this.hasCurrentlyPlaying = false,
    required this.profileBuilder,
    required this.tabBarBuilder,
  });

  double get _expandedProfile =>
      _expandedProfileHeight +
      (hasCurrentlyPlaying ? _playingExtraHeight : 0.0);

  @override
  double get minExtent => topPadding + _collapsedProfileHeight + _tabBarHeight;

  @override
  double get maxExtent => topPadding + _expandedProfile + _tabBarHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = maxExtent - minExtent;
    final collapseProgress = collapseRange > 0
        ? (shrinkOffset / collapseRange).clamp(0.0, 1.0)
        : 0.0;
    final profileHeight =
        _expandedProfile -
        ((_expandedProfile - _collapsedProfileHeight) * collapseProgress);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: Colors.black26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPadding),
          SizedBox(
            height: profileHeight,
            child: ClipRect(child: profileBuilder(collapseProgress)),
          ),
          SizedBox(
            height: _tabBarHeight,
            child: ClipRect(child: tabBarBuilder()),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MobileProfileHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.hasCurrentlyPlaying != hasCurrentlyPlaying ||
        oldDelegate.profileBuilder != profileBuilder ||
        oldDelegate.tabBarBuilder != tabBarBuilder;
  }
}
