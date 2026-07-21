import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final Map<String, dynamic>? userData;
  final double rating;
  final String comment;
  final String status;
  final String? updatedAt;

  const ReviewDetailsScreen({
    super.key,
    required this.gameData,
    required this.userData,
    required this.rating,
    required this.comment,
    required this.status,
    required this.updatedAt,
  });

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  bool _isLoading = true;
  int _likesCount = 0;
  bool _hasLiked = false;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchInteractions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchInteractions() async {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final reviewUserId = widget.userData?['id'];
    final reviewGameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    if (reviewUserId == null || reviewGameId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch likes
      final likesResponse = await Supabase.instance.client
          .from('review_likes')
          .select('user_id')
          .eq('review_user_id', reviewUserId)
          .eq('review_game_id', reviewGameId);
      
      final likes = likesResponse as List;
      _likesCount = likes.length;
      _hasLiked = likes.any((like) => like['user_id'] == currentUserId);

      // 2. Fetch comments
      final commentsResponse = await Supabase.instance.client
          .from('review_comments')
          .select('*, users(*)')
          .eq('review_user_id', reviewUserId)
          .eq('review_game_id', reviewGameId)
          .order('created_at', ascending: true);
      
      _comments = List<Map<String, dynamic>>.from(commentsResponse);
    } catch (e) {
      print('[CORPUS DEBUG] Error fetching interactions: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final reviewUserId = widget.userData?['id'];
    final reviewGameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    if (reviewUserId == null || reviewGameId == null) return;

    // Optimistic UI update
    setState(() {
      _hasLiked = !_hasLiked;
      _likesCount += _hasLiked ? 1 : -1;
    });

    try {
      if (_hasLiked) {
        await Supabase.instance.client.from('review_likes').insert({
          'user_id': currentUserId,
          'review_user_id': reviewUserId,
          'review_game_id': reviewGameId,
        });
      } else {
        await Supabase.instance.client
            .from('review_likes')
            .delete()
            .eq('user_id', currentUserId)
            .eq('review_user_id', reviewUserId)
            .eq('review_game_id', reviewGameId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _hasLiked = !_hasLiked;
          _likesCount += _hasLiked ? 1 : -1;
        });
      }
      print('[CORPUS DEBUG] Error toggling like: $e');
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final reviewUserId = widget.userData?['id'];
    final reviewGameId = widget.gameData['igdb_id'] ?? widget.gameData['id'];

    if (reviewUserId == null || reviewGameId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('review_comments').insert({
        'user_id': currentUserId,
        'review_user_id': reviewUserId,
        'review_game_id': reviewGameId,
        'content': content,
      });

      _commentController.clear();
      await _fetchInteractions(); // Refresh to get the new comment with user data
    } catch (e) {
      print('[CORPUS DEBUG] Error submitting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar comentario: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Eliminar comentario'),
        content: const Text('¿Estás seguro de que quieres eliminar este comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('review_comments')
          .delete()
          .eq('id', commentId);
      
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
        });
      }
    } catch (e) {
      print('[CORPUS DEBUG] Error deleting comment: $e');
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
      return "${date.day} de ${months[date.month - 1]} de ${date.year}";
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

  @override
  Widget build(BuildContext context) {
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
    final username = widget.userData?['username'] ?? 'Jugador';
    final avatarUrl = widget.userData?['avatar_url'];
    final dateStr = widget.updatedAt != null ? _formatDate(widget.updatedAt!) : '';
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Stash dark style
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartir próximamente')));
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, ) : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('@$username', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Game Mini-Card and Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      Container(
                        width: 100,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).primaryColorDark,
                          image: coverUrl.isNotEmpty ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null,
                        ),
                        child: coverUrl.isEmpty ? const Center(child: Icon(Icons.videogame_asset, color: Colors.white54)) : null,
                      ),
                      const SizedBox(width: 16),
                      
                      // Rating & Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.rating > 0) ...[
                              Row(
                                children: [
                                  Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 24),
                                  const SizedBox(width: 8),
                                  Text(widget.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Icon(Icons.flag, size: 18, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(_getStatusText(widget.status), style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Review Content
                  if (widget.comment.isNotEmpty)
                    Text(
                      widget.comment,
                      style: const TextStyle(fontSize: 16, height: 1.5, ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Date
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  
                  const SizedBox(height: 16),
                  Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  
                  // Like and Comment Buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _toggleLike,
                        icon: Icon(
                          _hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                          size: 18,
                          color: _hasLiked ? Theme.of(context).colorScheme.primary : Colors.white,
                        ),
                        label: Text(
                          _likesCount.toString(),
                          style: TextStyle(color: _hasLiked ? Theme.of(context).colorScheme.primary : Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: _hasLiked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant),
                          backgroundColor: _hasLiked ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Focus on text field
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(_comments.length.toString()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Theme.of(context).colorScheme.surfaceVariant),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Comments List
                  if (_comments.isNotEmpty) ...[
                    const Text('Comentarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final user = comment['users'];
                        final isMyComment = comment['user_id'] == currentUserId;
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              backgroundImage: user?['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                              child: user?['avatar_url'] == null ? const Icon(Icons.person, size: 16, ) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user?['username'] ?? 'Usuario',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(comment['created_at']),
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment['content'],
                                    style: const TextStyle(fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            if (isMyComment)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                onPressed: () => _deleteComment(comment['id']),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Comentario input
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              hintText: 'Añadir un comentario...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              counterText: '', // Ocultar el contador nativo para mantener diseño limpio
                            ),
                            maxLines: null,
                          ),
                        ),
                        if (_isSubmitting)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else
                          IconButton(
                            icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                            onPressed: _submitComment,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }
}
