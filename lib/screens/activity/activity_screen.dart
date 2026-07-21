import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
          .from('user_games')
          .select('*, games(*), users!user_games_user_id_fkey(*), review_likes(user_id), review_comments(id)')
          .order('updated_at', ascending: false)
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

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final gameData = activity['games'] ?? {};
    final userData = activity['users'] ?? {};
    
    final title = gameData['title'] ?? 'Juego Desconocido';
    final coverUrl = gameData['cover_url'] ?? '';
    final username = userData['username'] ?? 'Jugador';
    final avatarUrl = userData['avatar_url'];
    
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
        ).then((_) => _fetchActivity());
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
            // Cabecera del usuario
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 20, ) : null,
                ),
                const SizedBox(width: 8),
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Info del Juego y Nota
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
                return _buildActivityCard(_activities[index]);
              },
            ),
    );
  }
}
