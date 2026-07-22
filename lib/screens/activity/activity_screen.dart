import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import 'review_details_screen.dart';
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
  }

  @override
  void dispose() {
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) {
      _fetchActivity();
    }
  }

  Future<void> _fetchActivity() async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos todos los juegos guardados por cualquier usuario (reseñas, notas o cambios de estado)
      final response = await Supabase.instance.client
          .from('reviews')
          .select('*, games(*), users!reviews_user_id_users_fkey(*), review_likes(user_id), review_comments(id)')
          .order('created_at', ascending: false)
          .limit(50);
      
      print('[CORPUS DEBUG] _fetchActivity response count: ${response.length}');
      if (response.isNotEmpty) {
        print('[CORPUS DEBUG] _fetchActivity first item: ${response[0]}');
      }
          
      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[CORPUS DEBUG] ERROR en _fetchActivity: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'beaten': return Icons.emoji_events;
      case 'playing': return Icons.sports_esports;
      case 'wishlist': return Icons.bookmark;
      case 'abandoned': return Icons.cancel;
      case 'on_hold': return Icons.pause_circle;
      default: return Icons.flag;
    }
  }

  Future<void> _toggleLike(int index) async {
    final activity = _activities[index];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final reviewId = activity['id'];
    if (reviewId == null) return;

    final likes = List<Map<String, dynamic>>.from(activity['review_likes'] ?? []);
    final hasLiked = likes.any((l) => l['user_id'] == currentUserId);

    setState(() {
      if (hasLiked) {
        likes.removeWhere((l) => l['user_id'] == currentUserId);
      } else {
        likes.add({'user_id': currentUserId});
      }
      _activities[index]['review_likes'] = likes;
    });

    try {
      if (!hasLiked) {
        await Supabase.instance.client.from('review_likes').insert({
          'user_id': currentUserId,
          'review_id': reviewId,
          'review_user_id': activity['user_id'],
          'review_game_id': activity['game_id'],
        });
      } else {
        await Supabase.instance.client
            .from('review_likes')
            .delete()
            .match({'user_id': currentUserId, 'review_id': reviewId});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!hasLiked) {
            likes.removeWhere((l) => l['user_id'] == currentUserId);
          } else {
            likes.add({'user_id': currentUserId});
          }
          _activities[index]['review_likes'] = likes;
        });
      }
    }
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final gameData = activity['games'] ?? {};
    final userData = activity['users'] ?? {};
    
    final title = gameData['title'] ?? 'Juego Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';
    final username = userData['username'] ?? 'Jugador';
    final avatarUrl = userData['avatar_url'];
    
    final rating = (activity['rating'] ?? 0).toDouble();
    final comment = activity['comment'] ?? '';
    final status = activity['status'] ?? 'unknown';
    final dateStr = activity['created_at'] != null ? _formatDate(activity['created_at']) : '';
    final replayCount = activity['replay_count'] ?? 0;

    final likes = (activity['review_likes'] as List?) ?? [];
    final comments = (activity['review_comments'] as List?) ?? [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final hasLiked = likes.any((l) => l['user_id'] == currentUserId);
    final List<dynamic> imageUrls = activity['image_urls'] ?? [];

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
        ).then((_) => _fetchActivity());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del usuario
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 24, ) : null,
                ),
                const SizedBox(width: 12),
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const Spacer(),
                if (replayCount > 0)
                  Row(
                    children: [
                      Icon(Icons.replay, size: 16, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(replayCount.toString(), style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 12),
                    ],
                  ),
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Info del Juego y Nota
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100, height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).primaryColorDark,
                    image: coverUrl.isNotEmpty ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null,
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(_getStatusIcon(status), size: 18, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(_getStatusText(status), style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                        ],
                      ),
                      if (rating > 0 || (activity['play_time_hours'] ?? 0) > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (rating > 0) ...[
                              Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 18),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 16),
                            ],
                            if ((activity['play_time_hours'] ?? 0) > 0) ...[
                              Icon(Icons.access_time, color: Colors.grey.shade400, size: 18),
                              const SizedBox(width: 4),
                              Text('${(activity['play_time_hours']).toDouble().toStringAsFixed(1)} h', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                comment,
                style: const TextStyle(fontSize: 16, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, idx) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showImageFullScreen(imageUrls[idx]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(imageUrls[idx], height: 120, fit: BoxFit.fitHeight),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleLike(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                          size: 20, 
                          color: hasLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade400
                        ),
                        const SizedBox(width: 6),
                        Text(
                          likes.length.toString(), 
                          style: TextStyle(
                            color: hasLiked ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, 
                            fontSize: 16,
                            fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewDetailsScreen(
                          gameData: gameData,
                          userData: userData,
                          reviewData: activity,
                          focusComment: true,
                        ),
                      ),
                    ).then((_) => _fetchActivity());
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(comments.length.toString(), style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad Global'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _activities.isEmpty
          ? const Center(
              child: Text('No hay actividad todavía.\n¡Añade un juego a tu biblioteca para empezar!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                return _buildActivityCard(_activities[index], index);
              },
            ),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
