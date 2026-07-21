import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../library/game_details_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_games_list_screen.dart';
import '../activity/review_details_screen.dart';
import '../settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  int _totalGamesCount = 0;
  List<Map<String, dynamic>> _wishlistGames = [];
  List<Map<String, dynamic>> _playingGames = [];
  List<Map<String, dynamic>> _allGames = [];
  List<Map<String, dynamic>> _userReviews = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
  }

  @override
  void dispose() {
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      _fetchProfileData();
    }
  }

  Future<void> _fetchProfileData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // 1. Fetch user profile, create if missing
    var userResp = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (userResp == null) {
      final email = Supabase.instance.client.auth.currentUser!.email ?? 'jugador';
      final defaultUsername = email.split('@')[0];
      
      try {
        userResp = await Supabase.instance.client.from('users').insert({
          'id': userId,
          'username': defaultUsername,
        }).select().single();
      } catch (e) {
        // En caso de colisión de username o error
        userResp = {'username': defaultUsername};
      }
    }

    // 2. Fetch all user games with details and social metrics
    final gamesResp = await Supabase.instance.client
        .from('user_games')
        .select('*, games(*), users!user_games_user_id_fkey(*), review_likes(user_id), review_comments(id)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
        
    final List<dynamic> gamesList = gamesResp;
    
    final wishlist = <Map<String, dynamic>>[];
    final playing = <Map<String, dynamic>>[];
    final beaten = <Map<String, dynamic>>[];
    final reviews = <Map<String, dynamic>>[];
    
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

      // Si tiene un comentario escrito, es una review textual
      final comment = row['comment'] as String?;
      if (comment != null && comment.trim().isNotEmpty) {
        reviews.add(row as Map<String, dynamic>);
      }
    }
    
    if (mounted) {
      setState(() {
        _userProfile = userResp;
        _totalGamesCount = gamesList.length; 
        _wishlistGames = wishlist;
        _playingGames = playing;
        _allGames = beaten; 
        _userReviews = reviews;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final username = _userProfile?['username'] ?? 'Jugador';
    final displayName = _userProfile?['display_name'] ?? username;
    final bio = _userProfile?['bio'];
    final platforms = List<String>.from(_userProfile?['platforms'] ?? []);
    final avatarUrl = _userProfile?['avatar_url'];
    final bannerUrl = _userProfile?['banner_url'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Estilo Stash oscuro
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: bannerUrl == null ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade800, Colors.red.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ) : null,
                  child: bannerUrl != null ? Image.network(
                    bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('[CORPUS] Fallo al cargar el banner: $bannerUrl');
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade800, Colors.red.shade900],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    },
                  ) : null,
                ),
                
                // Degradado inferior para fundir con el fondo
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, 
                        end: Alignment.topCenter,
                        colors: [Theme.of(context).scaffoldBackgroundColor, Colors.transparent],
                      )
                    )
                  )
                ),

                // Menú superior (Ajustes)
                Positioned(
                  top: 40, right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.settings, ),
                    onPressed: () {
                      if (_userProfile != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsScreen(userProfile: _userProfile!),
                          ),
                        ).then((_) {
                          _fetchProfileData(); // Por si editan el perfil desde ajustes
                        });
                      }
                    },
                  ),
                ),

                // Username arriba a la izquierda
                Positioned(
                  top: 48, left: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard_arrow_down, ),
                      const SizedBox(width: 8),
                      Text(
                        '@$username', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Theme.of(context).scaffoldBackgroundColor, blurRadius: 4)]),
                      ),
                    ],
                  ),
                ),
                
                // Foto de perfil
                Positioned(
                  bottom: -30, left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      onBackgroundImageError: (e, s) {
                        print('[CORPUS] Fallo al cargar el avatar: $avatarUrl');
                      },
                      child: avatarUrl == null 
                          ? const Icon(Icons.person, size: 40, ) 
                          : null,
                    ),
                  ),
                ),

                // Estadísticas
                Positioned(
                  bottom: 16, left: 110, right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('$_totalGamesCount', 'Juegos'),
                      _buildStatColumn('0', 'Seguidos'),
                      _buildStatColumn('0', 'Seguidores'),
                    ],
                  )
                )
              ]
            ),
            
            const SizedBox(height: 40),
            
            // Info de Usuario
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName, 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  if (platforms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: platforms.map((p) => _buildPlatformIcon(p)).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Botón Editar Perfil
            if (_userProfile?['id'] == Supabase.instance.client.auth.currentUser!.id)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userProfile: _userProfile!),
                        ),
                      ).then((updated) {
                        if (updated == true) {
                          _fetchProfileData();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ),
              ),
            if (_userProfile?['id'] == Supabase.instance.client.auth.currentUser!.id)
              const SizedBox(height: 24),
            
            // Píldoras
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTab('Juegos', 0),
                  const SizedBox(width: 8),
                  _buildTab('Reseñas', 1),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (_selectedTab == 0) _buildGamesTab(),
            if (_selectedTab == 1) _buildReviewsTab(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Theme.of(context).scaffoldBackgroundColor, blurRadius: 4)])),
        Text(label, style: TextStyle(fontSize: 12, shadows: [Shadow(color: Theme.of(context).scaffoldBackgroundColor, blurRadius: 4)])),
      ],
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, List<Map<String, dynamic>> games) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('$count', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileGamesListScreen(title: title, games: games),
                ),
              ).then((_) => _fetchProfileData());
            },
            child: Text('Ver todo', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
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
            child: SizedBox(
              width: 110,
              child: _buildGameCard(game),
            ),
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
        physics: const NeverScrollableScrollPhysics(), // Scroll lo maneja la página
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
    final coverUrl = game['cover_url'] ?? '';
    final title = game['title'] ?? 'Desconocido';
    final userRating = (game['user_rating'] ?? 0).toDouble();
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(gameData: game),
          ),
        ).then((_) {
          _fetchProfileData();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).primaryColorDark,
                    child: const Center(child: Icon(Icons.videogame_asset, size: 30, color: Colors.white54)),
                  ),
            if (coverUrl.isEmpty)
               Positioned(
                 bottom: 4, left: 4, right: 4,
                 child: Text(title, style: const TextStyle(fontSize: 10, ), maxLines: 2, overflow: TextOverflow.ellipsis),
               ),
            if (userRating > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.54), blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    userRating.toStringAsFixed(1),
                    style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(String platform) {
    String? imagePath;
    IconData? icon;
    Color color;
    switch (platform) {
      case 'pc': icon = Icons.computer; color = Colors.grey.shade300; break;
      case 'playstation': imagePath = 'assets/images/playstation.png'; color = Colors.blue; break;
      case 'xbox': imagePath = 'assets/images/xbox.png'; color = Colors.green; break;
      case 'nintendo': imagePath = 'assets/images/nintendo.png'; color = Colors.red; break;
      default: icon = Icons.device_unknown; color = Colors.grey; break;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: imagePath != null 
            ? Image.asset(imagePath, width: 16, height: 16, color: color)
            : Icon(icon, color: color, size: 16),
      ),
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Aún no tienes juegos completados con nota.', style: TextStyle(color: Colors.grey)),
            )
          )
        ],
      ],
    );
  }

  Widget _buildReviewsTab() {
    if (_userReviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Aún no has escrito ninguna reseña.', style: TextStyle(color: Colors.grey)),
        )
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _userReviews.map((r) => _buildReviewCard(r)).toList(),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return "${date.day} ${months[date.month - 1]}. ${date.year}";
    } catch (e) {
      return '';
    }
  }

  String _getStatusText(String status) {
    switch(status) {
      case 'beaten': return 'Terminado';
      case 'playing': return 'Jugando';
      case 'wishlist': return 'Quiero';
      case 'abandoned': return 'Abandonado';
      case 'on_hold': return 'En Pausa';
      default: return 'Desconocido';
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
    final dateStr = activity['updated_at'] != null ? _formatDate(activity['updated_at']) : '';

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
              rating: rating,
              comment: comment,
              status: status,
              updatedAt: activity['updated_at'],
            ),
          ),
        ).then((_) => _fetchProfileData());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50, height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).primaryColorDark,
                    image: coverUrl.isNotEmpty ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.flag, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(_getStatusText(status), style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                      if (rating > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 16),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                  size: 16, 
                  color: hasLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade400
                ),
                const SizedBox(width: 4),
                Text(
                  likes.length.toString(), 
                  style: TextStyle(
                    color: hasLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, 
                    fontSize: 13,
                    fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal
                  )
                ),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(comments.length.toString(), style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
