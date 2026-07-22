import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../library/game_details_screen.dart';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/storage_utils.dart';

class ReviewDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic> reviewData;
  final bool focusComment;

  const ReviewDetailsScreen({
    super.key,
    required this.gameData,
    required this.userData,
    required this.reviewData,
    this.focusComment = false,
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
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  XFile? _commentImage;

  @override
  void initState() {
    super.initState();
    _fetchInteractions();
    if (widget.focusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchInteractions() async {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final reviewId = widget.reviewData['id'];

    if (reviewId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch likes
      final likesResponse = await Supabase.instance.client
          .from('review_likes')
          .select('user_id')
          .eq('review_id', reviewId);
      
      final likes = likesResponse as List;
      _likesCount = likes.length;
      _hasLiked = likes.any((like) => like['user_id'] == currentUserId);

      // Fetch comments
      final commentsResponse = await Supabase.instance.client
          .from('review_comments')
          .select('*, users(*)')
          .eq('review_id', reviewId)
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
    final reviewId = widget.reviewData['id'];
    if (reviewId == null) return;

    // Optimistic UI update
    setState(() {
      _hasLiked = !_hasLiked;
      _likesCount += _hasLiked ? 1 : -1;
    });

    try {
      if (_hasLiked) {
        await Supabase.instance.client.from('review_likes').insert({
          'user_id': currentUserId,
          'review_id': reviewId,
          'review_user_id': widget.reviewData['user_id'],
          'review_game_id': widget.reviewData['game_id'],
        });
      } else {
        await Supabase.instance.client
            .from('review_likes')
            .delete()
            .eq('user_id', currentUserId)
            .eq('review_id', reviewId);
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
    if (content.isEmpty && _commentImage == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final reviewId = widget.reviewData['id'];
    if (reviewId == null) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      if (_commentImage != null) {
        final bytes = await _commentImage!.readAsBytes();
        final ext = _commentImage!.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}.$ext';
        final path = '$currentUserId/$fileName';
        
        await Supabase.instance.client.storage
            .from('user_uploads')
            .uploadBinary(path, bytes);
            
        imageUrl = Supabase.instance.client.storage
            .from('user_uploads')
            .getPublicUrl(path);
      }

      await Supabase.instance.client.from('review_comments').insert({
        'user_id': currentUserId,
        'review_id': reviewId,
        'review_user_id': widget.reviewData['user_id'],
        'review_game_id': widget.reviewData['game_id'],
        'content': content.isNotEmpty ? content : null,
        if (imageUrl != null) 'image_url': imageUrl,
      });

      _commentController.clear();
      setState(() => _commentImage = null);
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
      final comment = _comments.firstWhere((c) => c['id'] == commentId, orElse: () => <String, dynamic>{});
      final imageUrl = comment['image_url'] as String?;
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await StorageUtils.deleteImagesFromUrls([imageUrl]);
      }

      await Supabase.instance.client
          .from('review_comments')
          .delete()
          .eq('id', commentId);
      
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentario eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar comentario: $e')));
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
      final List<String> urlsToDelete = [];
      final reviewImageUrls = widget.reviewData['image_urls'] as List<dynamic>?;
      if (reviewImageUrls != null) {
        urlsToDelete.addAll(reviewImageUrls.map((e) => e.toString()));
      }

      final commentsResponse = await Supabase.instance.client
          .from('review_comments')
          .select('image_url')
          .eq('review_id', reviewId);
          
      for (var c in commentsResponse) {
        if (c['image_url'] != null) {
          urlsToDelete.add(c['image_url']);
        }
      }

      if (urlsToDelete.isNotEmpty) {
        await StorageUtils.deleteImagesFromUrls(urlsToDelete);
      }

      await Supabase.instance.client.from('reviews').delete().eq('id', reviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reseña eliminada')));
        Navigator.pop(context); // Go back to the previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar reseña: $e')));
      }
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

  String _getMonthAbbr(int month) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
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
    } catch (_) { return ''; }
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

  String _getCompletionTypeText(String type) {
    switch(type) {
      case 'story': return 'Historia';
      case 'story_extras': return 'Historia + Extras';
      case '100_percent': return '100%';
      default: return type;
    }
  }

  IconData _getCompletionTypeIcon(String type) {
    switch(type) {
      case 'story': return Icons.auto_stories;
      case 'story_extras': return Icons.extension;
      case '100_percent': return Icons.stars;
      default: return Icons.flag;
    }
  }

  Widget _buildInfoBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSubRatingBadge(String label, double rating, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.gameData['title'] ?? 'Desconocido';
    final coverUrl = widget.gameData['cover_url'] ?? '';
    final username = widget.userData?['username'] ?? 'Jugador';
    final avatarUrl = widget.userData?['avatar_url'];
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    // Extract all fields from reviewData
    final rating = (widget.reviewData['rating'] ?? 0).toDouble();
    final comment = widget.reviewData['comment'] ?? '';
    final status = widget.reviewData['status'] ?? 'unknown';
    final createdAt = widget.reviewData['created_at'];
    final completionType = widget.reviewData['completion_type'] ?? 'story';
    final isReplay = widget.reviewData['is_replay'] ?? false;
    final replayNumber = widget.reviewData['replay_number'];
    final platform = widget.reviewData['platform'];
    final List<dynamic> imageUrls = widget.reviewData['image_urls'] ?? [];
    final playTimeHours = (widget.reviewData['play_time_hours'] ?? 0).toDouble();
    final playedFrom = widget.reviewData['played_from'];
    final playedUntil = widget.reviewData['played_until'];
    final progressPercent = widget.reviewData['progress_percent'];

    final ratingGameplay = (widget.reviewData['rating_gameplay'] ?? 0).toDouble();
    final ratingNarrative = (widget.reviewData['rating_narrative'] ?? 0).toDouble();
    final ratingSoundtrack = (widget.reviewData['rating_soundtrack'] ?? 0).toDouble();
    final ratingVisuals = (widget.reviewData['rating_visuals'] ?? 0).toDouble();

    final dateStr = createdAt != null ? _formatDate(createdAt) : '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                      const Spacer(),
                      if (widget.reviewData['user_id'] == Supabase.instance.client.auth.currentUser?.id)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteReview(widget.reviewData['id']),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Badges: completion type, replay, platform
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (completionType != 'none')
                        _buildInfoBadge(_getCompletionTypeText(completionType), _getCompletionTypeIcon(completionType), Theme.of(context).colorScheme.primary),
                      if (isReplay)
                        _buildInfoBadge('Rejugada${replayNumber != null ? ' #$replayNumber' : ''}', Icons.replay, Colors.orangeAccent),
                      if (platform != null)
                        _buildInfoBadge(platform, Icons.devices, Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Game Mini-Card and Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameDetailsScreen(gameData: widget.gameData),
                              ),
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).primaryColorDark,
                              image: coverUrl.isNotEmpty ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null,
                            ),
                            child: coverUrl.isEmpty ? const Center(child: Icon(Icons.videogame_asset, color: Colors.white54)) : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Rating & Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rating > 0) ...[
                              Row(
                                children: [
                                  Icon(Icons.star, color: Theme.of(context).colorScheme.secondary, size: 24),
                                  const SizedBox(width: 8),
                                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (ratingGameplay > 0 || ratingNarrative > 0 || ratingSoundtrack > 0 || ratingVisuals > 0) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (ratingGameplay > 0) _buildSubRatingBadge('Gameplay', ratingGameplay, Icons.sports_esports),
                                  if (ratingNarrative > 0) _buildSubRatingBadge('Narrativa', ratingNarrative, Icons.auto_stories),
                                  if (ratingSoundtrack > 0) _buildSubRatingBadge('Banda Sonora', ratingSoundtrack, Icons.music_note),
                                  if (ratingVisuals > 0) _buildSubRatingBadge('Visuales', ratingVisuals, Icons.brush),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Icon(_getStatusIcon(status), size: 18, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(_getStatusText(status), style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Review Content
                  if (comment.isNotEmpty)
                    Text(
                      comment,
                      style: const TextStyle(fontSize: 16, height: 1.5, ),
                    ),
                  
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
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
                                  child: Image.network(imageUrls[idx], height: 140, fit: BoxFit.fitHeight),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  // Extra info
                  if (playTimeHours > 0 || playedFrom != null || progressPercent != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (playTimeHours > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('${playTimeHours.toStringAsFixed(1)} horas', style: const TextStyle(color: Colors.grey)),
                              ]),
                            ),
                          if (playedFrom != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(_formatDateRange(playedFrom, playedUntil), style: const TextStyle(color: Colors.grey)),
                              ]),
                            ),
                          if (progressPercent != null)
                            Row(children: [
                              const Icon(Icons.pie_chart, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('$progressPercent% completado', style: const TextStyle(color: Colors.grey)),
                            ]),
                        ],
                      ),
                    ),
                  ],
                  
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
                                  const SizedBox(height: 4),
                                  if (comment['content'] != null && comment['content'].toString().isNotEmpty)
                                    Text(
                                      comment['content'],
                                      style: const TextStyle(fontSize: 14, height: 1.4),
                                    ),
                                  if (comment['image_url'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: GestureDetector(
                                        onTap: () => _showImageFullScreen(comment['image_url']),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                            child: Image.network(comment['image_url'], height: 150, fit: BoxFit.fitHeight),
                                        ),
                                      ),
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
                ],
              ),
            ),
          ),
        ),
        // Comentario input at the bottom
        if (!_isLoading)
          Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 8, 
              bottom: MediaQuery.of(context).padding.bottom + 8
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                if (_commentImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(_commentImage!.path, height: 80, width: 80, fit: BoxFit.cover)
                                : Image.file(File(_commentImage!.path), height: 80, width: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -8, right: -8,
                            child: GestureDetector(
                              onTap: () => setState(() => _commentImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1080);
                          if (file != null) setState(() => _commentImage = file);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                    child: TextField(
                      focusNode: _commentFocusNode,
                      controller: _commentController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Añadir un comentario...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        counterText: '',
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
          ],
        ),
      ),
      ],
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
