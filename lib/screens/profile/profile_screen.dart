import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../../widgets/guest_login_prompt.dart';
import '../library/game_details_screen.dart';
import 'profile_games_list_screen.dart';
import '../activity/review_details_screen.dart';
import '../settings_screen.dart';
import 'achievements_screen.dart';
import '../../utils/level_calculator.dart';
import 'package:corpus/widgets/game_card.dart';
import 'package:corpus/widgets/filter_bottom_sheet.dart';
import '../social/friends_screen.dart';
import 'profile_achievements_tab.dart';
import 'profile_journal_tab.dart';

class ProfileScreen extends StatefulWidget {
  /// Si se proporciona, muestra el perfil de ese usuario. Si no, el propio.
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _wishlistGames = [];
  List<Map<String, dynamic>> _playingGames = [];
  List<Map<String, dynamic>> _allGames = [];
  List<Map<String, dynamic>> _userReviews = [];
  int _selectedTab = 0;
  List<Map<String, dynamic>?> _hallOfFame = List.filled(5, null);
  GameFilters _filters = GameFilters();
  StreamSubscription<AuthState>? _authSub;

  bool get _isOwnProfile {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return widget.userId == null || widget.userId == currentUserId;
  }

  /// Verdadero cuando se pide el perfil propio (userId == null) y no hay
  /// sesión iniciada: aquí no hay nada que cargar, solo un aviso de login.
  bool get _isGuestProfile =>
      widget.userId == null && Supabase.instance.client.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    if (_isGuestProfile) {
      _isLoading = false;
    } else {
      _fetchProfileData();
      libraryUpdateNotifier.addListener(_onLibraryUpdated);
    }

    // Si el invitado inicia sesión mientras está en esta pantalla (le hemos
    // mandado a Login desde el botón y ha vuelto), refrescamos solos, sin
    // que tenga que salir y volver a entrar a la pestaña de Perfil.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted || widget.userId != null) return;
      final loggedInNow = Supabase.instance.client.auth.currentUser != null;
      if (loggedInNow && _userProfile == null) {
        setState(() => _isLoading = true);
        _fetchProfileData();
        libraryUpdateNotifier.addListener(_onLibraryUpdated);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _authSub?.cancel();
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      _fetchProfileData();
    }
  }

  Future<void> _fetchProfileData() async {
    final userId =
        widget.userId ?? Supabase.instance.client.auth.currentUser!.id;

    // 1. Perfil de usuario (va primero porque puede necesitar auto-crearse)
    var userResp = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (userResp == null && widget.userId == null) {
      // Solo auto-creamos el perfil del usuario actual
      final email =
          Supabase.instance.client.auth.currentUser!.email ?? 'jugador';
      final defaultUsername = email.split('@')[0];

      try {
        userResp = await Supabase.instance.client
            .from('users')
            .insert({'id': userId, 'username': defaultUsername})
            .select()
            .single();
      } catch (e) {
        userResp = {'username': defaultUsername};
      }
    }

    // 2. Las siguientes queries son independientes entre sí — las lanzamos en paralelo
    final results = await Future.wait([
      // Todos los juegos del usuario con detalles
      Supabase.instance.client
          .from('user_games')
          .select('*, games(*)')
          .eq('user_id', userId)
          .order('updated_at', ascending: false),
      // Reseñas del usuario
      Supabase.instance.client
          .from('reviews')
          .select('*, games(*), review_likes(user_id), review_comments(id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      // Hall of fame
      Supabase.instance.client
          .from('hall_of_fame')
          .select('*, games(*)')
          .eq('user_id', userId)
          .order('pin_order', ascending: true)
          .catchError((_) => <Map<String, dynamic>>[]),
    ]);

    final gamesResp = results[0];
    final reviewsResp = results[1];
    final hallOfFameResp = results[2];

    final hallOfFameList = List<Map<String, dynamic>?>.filled(5, null);
    try {
      for (var row in hallOfFameResp) {
        final order = row['pin_order'] as int;
        if (order >= 1 && order <= 5 && row['games'] != null) {
          hallOfFameList[order - 1] = row['games'];
        }
      }
    } catch (e) {
      debugPrint('[CORPUS] Hall of fame no disponible todavía: $e');
    }

    final List<dynamic> gamesList = gamesResp;

    final wishlist = <Map<String, dynamic>>[];
    final playing = <Map<String, dynamic>>[];
    final beaten = <Map<String, dynamic>>[];

    for (var row in gamesList) {
      final gameData = row['games'];
      if (gameData == null) continue;

      final rating = (row['rating'] ?? 0).toDouble();
      // Incluimos la nota dentro del gameData para mostrarla en la UI
      gameData['user_rating'] = rating;

      if (row['status'] == 'wishlist') {
        wishlist.add(gameData);
      } else if (row['status'] == 'playing') {
        playing.add(gameData);
      } else if (row['status'] == 'beaten' && rating > 0) {
        beaten.add(gameData);
      }
    }

    if (mounted) {
      setState(() {
        _userProfile = userResp;

        _wishlistGames = wishlist;
        _playingGames = playing;
        _allGames = beaten;
        _userReviews = List<Map<String, dynamic>>.from(reviewsResp);
        _hallOfFame = hallOfFameList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuestProfile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: GuestLoginPrompt(
            message: 'Inicia sesión para ver y personalizar tu perfil.',
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDesktop),
            _buildLevelProgressBar(isDesktop),
            _buildNavBar(isDesktop),
            const SizedBox(height: 24),
            if (isDesktop) _buildDesktopLayout() else _buildMobileLayout(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    final username = _userProfile?['username'] ?? 'Jugador';
    final displayName = _userProfile?['display_name'] ?? username;
    final avatarUrl = _userProfile?['avatar_url'];
    final bannerUrl = _userProfile?['banner_url'];
    final isMe =
        _userProfile?['id'] == Supabase.instance.client.auth.currentUser!.id;

    final bannerHeight = isDesktop ? 240.0 : 180.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner
        Container(
          height: bannerHeight,
          width: double.infinity,
          decoration: bannerUrl == null
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade800, Colors.red.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: bannerUrl != null
              ? Image.network(
                  bannerUrl.replaceAll(
                    't_cover_big',
                    't_1080p',
                  ), // Mejor resolución
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
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
                    );
                  },
                )
              : null,
        ),

        // Degradado inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Back Button (if navigated from another screen)
        if (Navigator.canPop(context))
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
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
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
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
                    ).then((_) => _fetchProfileData());
                  },
                ),
              ],
            ),
          ),

        // Avatar y Nombres (Alineados a la izquierda y sobresaliendo un poco abajo)
        Positioned(
          bottom: -40,
          left: isDesktop ? 40 : 16,
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
                      color: Colors.black.withValues(alpha: 0.3),
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
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 40,
                ), // Para que quede sobre el banner
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isDesktop ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(offset: Offset(-1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, 1), color: Colors.black),
                          Shadow(offset: Offset(-1, 1), color: Colors.black),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 14,
                        color: Colors.white,
                        shadows: const [
                          Shadow(offset: Offset(-1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, -1), color: Colors.black),
                          Shadow(offset: Offset(1, 1), color: Colors.black),
                          Shadow(offset: Offset(-1, 1), color: Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelProgressBar(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(
        top: 60, // Clear the avatar's overflow
        left: isDesktop ? 40 : 16,
        right: isDesktop ? 40 : 16,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _isOwnProfile
            ? () {
                final userId =
                    _userProfile?['id'] ??
                    Supabase.instance.client.auth.currentUser!.id;
                final xp = (_userProfile?['xp'] as num?)?.toInt() ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AchievementsScreen(userId: userId, initialXp: xp),
                  ),
                ).then((_) => _fetchProfileData());
              }
            : null,
        child: SizedBox(
          width: isDesktop ? 400 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nivel ${LevelCalculator.getLevel((_userProfile?['xp'] as num?)?.toInt() ?? 0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    LevelCalculator.getProgressString(
                      (_userProfile?['xp'] as num?)?.toInt() ?? 0,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: LevelCalculator.getProgressFraction(
                    (_userProfile?['xp'] as num?)?.toInt() ?? 0,
                  ),
                  minHeight: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(bool isDesktop) {
    return Container(
      margin: EdgeInsets.only(
        top: 24,
        left: isDesktop ? 40 : 16,
        right: isDesktop ? 40 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildNavTab('Perfil', 0),
          _buildNavTab('Juegos', 1),
          _buildNavTab('Diario', 2),
          _buildNavTab('Reseñas', 3),
          _buildNavTab('Logros', 4),
        ],
      ),
    );
  }

  Widget _buildNavTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
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
          child: SelectionContainer.disabled(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda (Sidebar)
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildSidebarInfo()],
            ),
          ),
          const SizedBox(width: 40),
          // Columna Derecha (Contenido Principal)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedTab == 0) ...[
                  _buildHallOfFame(),
                  const SizedBox(height: 32),
                  _buildGiantStatsRow(),
                  const SizedBox(height: 32),
                  // Si no hay contenido principal en 'Perfil', podríamos poner los juegos recientes
                  _buildGamesTab(),
                ] else if (_selectedTab == 1) ...[
                  _buildAllGamesTab(),
                ] else if (_selectedTab == 2) ...[
                  ProfileJournalTab(
                    reviews: _userReviews,
                    userData: _userProfile,
                    onReturn: _fetchProfileData,
                  ),
                ] else if (_selectedTab == 3) ...[
                  _buildReviewsTab(),
                ] else if (_selectedTab == 4) ...[
                  ProfileAchievementsTab(
                    userId:
                        _userProfile?['id'] ??
                        widget.userId ??
                        Supabase.instance.client.auth.currentUser!.id,
                    isOwnProfile: _isOwnProfile,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedTab == 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSidebarInfo(isMobile: true),
          ),
          const SizedBox(height: 24),
          _buildHallOfFame(),
          const SizedBox(height: 32),
          _buildGiantStatsRow(isMobile: true),
          const SizedBox(height: 32),
          _buildGamesTab(),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRatingsHistogram(),
          ),
          const SizedBox(height: 32),
        ] else if (_selectedTab == 1) ...[
          _buildAllGamesTab(),
        ] else if (_selectedTab == 2) ...[
          ProfileJournalTab(
            reviews: _userReviews,
            userData: _userProfile,
            onReturn: _fetchProfileData,
          ),
        ] else if (_selectedTab == 3) ...[
          _buildReviewsTab(),
        ] else if (_selectedTab == 4) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ProfileAchievementsTab(
              userId:
                  _userProfile?['id'] ??
                  widget.userId ??
                  Supabase.instance.client.auth.currentUser!.id,
              isOwnProfile: _isOwnProfile,
            ),
          ),
        ],
      ],
    );
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
    final ratings = _userReviews
        .map((r) => (r['rating'] ?? 0).toDouble())
        .where((r) => r > 0)
        .toList();

    if (ratings.isEmpty) return const SizedBox.shrink();

    final List<int> buckets = List.filled(10, 0);
    double sum = 0;
    for (var r in ratings) {
      sum += r;
      int bucketIndex = (r.round() - 1).clamp(0, 9);
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
                '${ratings.length} | ${avgRating.toStringAsFixed(1)} ★ Media',
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildGiantStat(
            _allGames.length.toString().padLeft(3, '0'),
            'Completados',
            () {
              if (_allGames.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileGamesListScreen(
                      title: 'Completados',
                      games: _allGames,
                    ),
                  ),
                ).then((_) => _fetchProfileData());
              }
            },
          ),
          _buildGiantStat(
            _playingGames.length.toString().padLeft(3, '0'),
            'Jugando',
            () {
              if (_playingGames.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileGamesListScreen(
                      title: 'Jugando',
                      games: _playingGames,
                    ),
                  ),
                ).then((_) => _fetchProfileData());
              }
            },
          ),
          _buildGiantStat(
            _wishlistGames.length.toString().padLeft(3, '0'),
            'En Wishlist',
            () {
              if (_wishlistGames.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileGamesListScreen(
                      title: 'Quiero',
                      games: _wishlistGames,
                    ),
                  ),
                ).then((_) => _fetchProfileData());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGiantStat(String number, String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SelectionContainer.disabled(
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
                                        ).then((_) => _fetchProfileData());
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
                                        ).then((_) => _fetchProfileData());
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
                                            child: Image.network(
                                              game['cover_url'].replaceAll(
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

  Widget _buildSectionTitle(
    String title,
    int count,
    List<Map<String, dynamic>> games,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileGamesListScreen(title: title, games: games),
                  ),
                ).then((_) => _fetchProfileData());
              },
              child: SelectionContainer.disabled(
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

  Widget _buildGrid(List<Map<String, dynamic>> games) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics:
            const NeverScrollableScrollPhysics(), // Scroll lo maneja la página
        shrinkWrap: true, // Para que el Grid se adapte al contenido
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return _buildGameCard(game);
        },
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    final userRating = (game['user_rating'] ?? 0).toDouble();
    return GameCard(
      game: game,
      isInLibrary: true,
      userRating: userRating,
      onReturn: _fetchProfileData,
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
        borderRadius: BorderRadius.circular(8),
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
          _buildSectionTitle('Quiero', _wishlistGames.length, _wishlistGames),
          _buildCarousel(_wishlistGames),
          const SizedBox(height: 24),
        ],
        if (_playingGames.isNotEmpty) ...[
          _buildSectionTitle('Jugando', _playingGames.length, _playingGames),
          _buildCarousel(_playingGames),
          const SizedBox(height: 24),
        ],
        if (_allGames.isNotEmpty) ...[
          _buildSectionTitle('Completados', _allGames.length, _allGames),
          _buildCarousel(_allGames),
        ] else ...[
          Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Aún no tienes juegos completados con nota.',
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

  void _openFilters() async {
    final result = await showModalBottomSheet<GameFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FilterBottomSheet(initialFilters: _filters),
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredGames() {
    final allGamesList = [..._allGames, ..._playingGames, ..._wishlistGames];

    var filtered = allGamesList.where((game) {
      final gameData = game['games'] ?? game;

      bool matchesGenres = true;
      if (_filters.genres.isNotEmpty) {
        final gameGenres =
            (gameData['genres'] as List?)
                ?.map((e) => e is int ? e : (e['id'] ?? -1))
                .toList() ??
            [];
        matchesGenres = _filters.genres.any((id) => gameGenres.contains(id));
      }

      bool matchesThemes = true;
      if (_filters.themes.isNotEmpty) {
        final gameThemes =
            (gameData['themes'] as List?)
                ?.map((e) => e is int ? e : (e['id'] ?? -1))
                .toList() ??
            [];
        matchesThemes = _filters.themes.any((id) => gameThemes.contains(id));
      }

      bool matchesGameModes = true;
      if (_filters.gameModes.isNotEmpty) {
        final gameModesList =
            (gameData['game_modes'] as List?)
                ?.map((e) => e is int ? e : (e['id'] ?? -1))
                .toList() ??
            [];
        matchesGameModes = _filters.gameModes.any(
          (id) => gameModesList.contains(id),
        );
      }

      bool matchesPerspectives = true;
      if (_filters.playerPerspectives.isNotEmpty) {
        final gamePerspectives =
            (gameData['player_perspectives'] as List?)
                ?.map((e) => e is int ? e : (e['id'] ?? -1))
                .toList() ??
            [];
        matchesPerspectives = _filters.playerPerspectives.any(
          (id) => gamePerspectives.contains(id),
        );
      }

      bool matchesPlatforms = true;

      bool matchesCategories = true;
      if (_filters.categories.isNotEmpty) {
        matchesCategories = _filters.categories.contains(gameData['category']);
      }

      return matchesGenres &&
          matchesThemes &&
          matchesGameModes &&
          matchesPerspectives &&
          matchesPlatforms &&
          matchesCategories;
    }).toList();

    filtered.sort((a, b) {
      final gameA = a['games'] ?? a;
      final gameB = b['games'] ?? b;

      int comparison = 0;
      if (_filters.sortBy == 'name') {
        comparison = (gameA['title'] ?? '').toString().compareTo(
          (gameB['title'] ?? '').toString(),
        );
      } else if (_filters.sortBy == 'first_release_date') {
        final dateA = gameA['release_date'] ?? '9999-12-31';
        final dateB = gameB['release_date'] ?? '9999-12-31';
        comparison = dateA.compareTo(dateB);
      } else if (_filters.sortBy == 'rating') {
        final ratingA = (a['rating'] ?? 0).toDouble();
        final ratingB = (b['rating'] ?? 0).toDouble();
        comparison = ratingA.compareTo(ratingB);
      } else {
        final ratingA = (a['rating'] ?? 0).toDouble();
        final ratingB = (b['rating'] ?? 0).toDouble();
        comparison = ratingA.compareTo(ratingB);
      }

      return _filters.sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Widget _buildAllGamesTab() {
    final filteredGames = _getFilteredGames();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextButton.icon(
            icon: const Icon(Icons.tune, size: 20),
            label: Text(
              'Filtros${_filters.hasFilters ? ' (${_filters.filterCount})' : ''}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: _filters.hasFilters
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: _openFilters,
          ),
        ),
        if (filteredGames.isNotEmpty)
          _buildGrid(filteredGames)
        else
          Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Aún no tienes juegos en tu biblioteca o ninguno coincide con los filtros.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    final textReviews = _userReviews.where((r) {
      final comment = r['comment'] as String?;
      return comment != null && comment.trim().isNotEmpty;
    }).toList();

    if (textReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Aún no has escrito ninguna reseña.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: textReviews.map((r) => _buildReviewCard(r)).toList(),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return "${date.day} ${months[date.month - 1]}. ${date.year}";
    } catch (e) {
      return '';
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

  Widget _buildReviewCard(Map<String, dynamic> activity) {
    final gameData = activity['games'] ?? {};
    final userData = activity['users'] ?? _userProfile ?? {};

    final title = gameData['title'] ?? 'Juego Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';

    final rating = (activity['rating'] ?? 0).toDouble();
    final comment = activity['comment'] ?? '';
    final status = activity['status'] ?? 'unknown';
    final dateStr = activity['created_at'] != null
        ? _formatDate(activity['created_at'])
        : '';

    final likes = (activity['review_likes'] as List?) ?? [];
    final comments = (activity['review_comments'] as List?) ?? [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final hasLiked = likes.any((l) => l['user_id'] == currentUserId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewDetailsScreen(
              gameData: gameData,
              userData: userData,
              reviewData: activity,
            ),
          ),
        ).then((_) => _fetchProfileData());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).primaryColorDark,
                    image: coverUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(coverUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.flag,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (rating > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                comment,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
              height: 1,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  size: 16,
                  color: hasLiked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  likes.length.toString(),
                  style: TextStyle(
                    color: hasLiked
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  comments.length.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
