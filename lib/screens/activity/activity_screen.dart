import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../activity/review_details_screen.dart';
import '../profile/profile_screen.dart';

/// Feed de actividad social en tiempo real.
/// Muestra la actividad del usuario actual y la de sus amigos aceptados.
/// La tabla `activity_feed` se puebla automáticamente mediante triggers
/// de PostgreSQL cuando se cambia el estado de un juego o se escribe una reseña.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchActivity();
    _subscribeRealtime();
    libraryUpdateNotifier.addListener(_onLibraryUpdated);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) _fetchActivity();
  }

  // ──────────────────────────────────────────
  // DATOS
  // ──────────────────────────────────────────

  Future<void> _fetchActivity({bool silent = false}) async {
    if (!silent && _activities.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      // 1. Una sola query para el feed completo
      final response = await _supabase
          .from('activity_feed')
          .select('''
            *,
            users!activity_feed_user_id_fkey(id, username, display_name, avatar_url),
            games!activity_feed_game_id_fkey(igdb_id, title, cover_url)
          ''')
          .order('created_at', ascending: false)
          .limit(60);

      final feedItems = List<Map<String, dynamic>>.from(response);

      // 2. Recoger todos los review_id en una sola pasada (evita N+1 queries)
      final reviewIds = feedItems
          .where((item) => item['action_type'] == 'reviewed')
          .map((item) => (item['metadata'] as Map?)?['review_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // 3. Una única query batch para todas las reviews necesarias
      final Map<String, Map<String, dynamic>> reviewsById = {};
      if (reviewIds.isNotEmpty) {
        try {
          final reviewsResp = await _supabase
              .from('reviews')
              .select('*, review_likes(user_id), review_comments(id)')
              .inFilter('id', reviewIds);
          for (final r in List<Map<String, dynamic>>.from(reviewsResp)) {
            reviewsById[r['id'] as String] = r;
          }
        } catch (_) {}
      }

      // 4. Enriquecer items y agrupar eventos relacionados (lógica de merge sin queries)
      final mergedActivities = <Map<String, dynamic>>[];
      for (var item in feedItems) {
        if (item['action_type'] == 'reviewed') {
          final reviewId = (item['metadata'] as Map?)?['review_id'] as String?;
          if (reviewId != null && reviewsById.containsKey(reviewId)) {
            item = Map<String, dynamic>.from(item);
            item['_review'] = reviewsById[reviewId];
          }
        }

        // Agrupar con eventos recientes del mismo usuario y juego (dentro de 24 horas)
        bool merged = false;
        final userId = item['user_id'];
        final gameId = item['game_id'];
        final type = item['action_type'];
        final dateStr = item['created_at'];

        if (userId != null && gameId != null && dateStr != null) {
          final date = DateTime.parse(dateStr);
          for (
            int i = mergedActivities.length - 1;
            i >= 0 && i >= mergedActivities.length - 4;
            i--
          ) {
            final prev = mergedActivities[i];
            if (prev['user_id'] == userId && prev['game_id'] == gameId) {
              final prevDate = DateTime.parse(prev['created_at']);
              if (date.difference(prevDate).abs().inHours < 24) {
                if (type == 'status_change' &&
                    prev['action_type'] == 'reviewed') {
                  prev['action_type'] = 'status_change';
                  if (prev['metadata'] == null) {
                    prev['metadata'] = <String, dynamic>{};
                  }
                  final itemMeta = item['metadata'] as Map? ?? {};
                  (prev['metadata'] as Map)['status'] = itemMeta['status'];
                  merged = true;
                  break;
                } else if (type == 'reviewed' &&
                    prev['action_type'] == 'status_change') {
                  prev['_review'] = item['_review'];
                  merged = true;
                  break;
                } else if (type == 'status_change' &&
                    prev['action_type'] == 'status_change') {
                  merged = true;
                  break;
                }
              }
            }
          }
        }

        if (!merged) {
          mergedActivities.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _activities = mergedActivities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ActivityScreen] Error cargando actividad: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Suscripción Realtime: cuando llega un nuevo evento al feed, recargamos.
  void _subscribeRealtime() {
    _realtimeChannel = _supabase
        .channel('activity_feed_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_feed',
          callback: (payload) {
            if (mounted) _fetchActivity();
          },
        )
        .subscribe();
  }

  // ──────────────────────────────────────────
  // LIKES
  // ──────────────────────────────────────────

  Future<void> _toggleLike(int index) async {
    final activity = _activities[index];
    final review = activity['_review'] as Map<String, dynamic>?;
    if (review == null) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    final reviewId = review['id'];

    final likes = List<Map<String, dynamic>>.from(review['review_likes'] ?? []);
    final hasLiked = likes.any((l) => l['user_id'] == currentUserId);

    setState(() {
      if (hasLiked) {
        likes.removeWhere((l) => l['user_id'] == currentUserId);
      } else {
        likes.add({'user_id': currentUserId});
      }
      _activities[index]['_review']['review_likes'] = likes;
    });

    try {
      if (!hasLiked) {
        await _supabase.from('review_likes').insert({
          'user_id': currentUserId,
          'review_id': reviewId,
          'review_user_id': review['user_id'],
          'review_game_id': review['game_id'],
        });
      } else {
        await _supabase.from('review_likes').delete().match({
          'user_id': currentUserId,
          'review_id': reviewId,
        });
      }
    } catch (_) {
      // Revertir
      setState(() {
        if (!hasLiked) {
          likes.removeWhere((l) => l['user_id'] == currentUserId);
        } else {
          likes.add({'user_id': currentUserId});
        }
        _activities[index]['_review']['review_likes'] = likes;
      });
    }
  }

  // ──────────────────────────────────────────
  // HELPERS DE FORMATO
  // ──────────────────────────────────────────

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
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Ahora mismo';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      return '${date.day} ${months[date.month - 1]}. ${date.year}';
    } catch (_) {
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
        return 'En wishlist';
      case 'abandoned':
        return 'Abandonado';
      case 'on_hold':
        return 'En Pausa';
      default:
        return 'Actualizado';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'beaten':
        return Icons.emoji_events;
      case 'playing':
        return Icons.sports_esports;
      case 'wishlist':
        return Icons.bookmark;
      case 'abandoned':
        return Icons.cancel;
      case 'on_hold':
        return Icons.pause_circle;
      default:
        return Icons.flag;
    }
  }

  String _getActionText(String actionType, String? status) {
    switch (actionType) {
      case 'status_change':
        switch (status) {
          case 'playing':
            return 'está jugando a';
          case 'beaten':
            return 'ha completado';
          case 'wishlist':
            return 'quiere jugar a';
          case 'abandoned':
            return 'ha abandonado';
          case 'on_hold':
            return 'ha pausado';
          default:
            return 'actualizó';
        }
      case 'reviewed':
        return 'ha reseñado';
      case 'achievement':
        return 'ha desbloqueado un logro en';
      default:
        return 'hizo algo con';
    }
  }

  IconData _getActionIcon(String actionType, String? status) {
    if (actionType == 'reviewed') return Icons.rate_review_rounded;
    if (actionType == 'achievement') return Icons.emoji_events_rounded;
    switch (status) {
      case 'beaten':
        return Icons.emoji_events;
      case 'playing':
        return Icons.sports_esports;
      case 'wishlist':
        return Icons.bookmark;
      case 'abandoned':
        return Icons.cancel;
      case 'on_hold':
        return Icons.pause_circle;
      default:
        return Icons.flag;
    }
  }

  Color _getActionColor(String actionType, String? status, BuildContext ctx) {
    if (actionType == 'reviewed') return Theme.of(ctx).colorScheme.secondary;
    if (actionType == 'achievement') return Colors.amber;
    switch (status) {
      case 'beaten':
        return Colors.green;
      case 'playing':
        return Theme.of(ctx).colorScheme.primary;
      case 'abandoned':
        return Colors.red;
      default:
        return Theme.of(ctx).colorScheme.onSurfaceVariant;
    }
  }

  // ──────────────────────────────────────────
  // CARD
  // ──────────────────────────────────────────

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final userData = activity['users'] as Map<String, dynamic>? ?? {};
    final gameData = activity['games'] as Map<String, dynamic>? ?? {};
    final meta = activity['metadata'] as Map<String, dynamic>? ?? {};
    final review = activity['_review'] as Map<String, dynamic>?;

    final displayName =
        userData['display_name'] as String? ??
        userData['username'] as String? ??
        'Usuario';
    final avatarUrl = userData['avatar_url'] as String?;
    final gameTitle = gameData['title'] as String? ?? 'Juego desconocido';
    final coverUrl = gameData['cover_url'] as String?;

    final actionType = activity['action_type'] as String? ?? 'status_change';
    final status = meta['status'] as String?;
    final dateStr = _formatDate(activity['created_at'] as String? ?? '');

    final actionText = _getActionText(actionType, status);
    final actionIcon = _getActionIcon(actionType, status);
    final actionColor = _getActionColor(actionType, status, context);

    final myId = _supabase.auth.currentUser?.id;
    final activityUserId = userData['id'] as String?;
    final isOwnActivity = myId == activityUserId;

    // Datos de la reseña enriquecida
    final rating = review != null
        ? (review['rating'] as num?)?.toDouble()
        : (meta['rating'] as num?)?.toDouble();
    final comment =
        review?['comment'] as String? ?? meta['comment'] as String? ?? '';
    final List<dynamic> imageUrls = review?['image_urls'] ?? [];
    final likes = review != null ? (review['review_likes'] as List?) ?? [] : [];
    final comments = review != null
        ? (review['review_comments'] as List?) ?? []
        : [];
    final replayCount = review?['replay_count'] ?? 0;
    final hasLiked = likes.any((l) => l['user_id'] == myId);
    final isReview = review != null;

    void openReview() {
      if (review == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewDetailsScreen(
            gameData: gameData,
            userData: userData,
            reviewData: review,
          ),
        ),
      ).then((_) => _fetchActivity(silent: true));
    }

    void openReviewComments() {
      if (review == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewDetailsScreen(
            gameData: gameData,
            userData: userData,
            reviewData: review,
            focusComment: true,
          ),
        ),
      ).then((_) => _fetchActivity(silent: true));
    }

    return GestureDetector(
      onTap: isReview ? openReview : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera: avatar + acción + tiempo ──
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (activityUserId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: activityUserId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (activityUserId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: activityUserId),
                          ),
                        );
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(fontSize: 15),
                        children: [
                          TextSpan(
                            text: isOwnActivity ? 'Tú' : displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' $actionText '),
                          TextSpan(
                            text: gameTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(actionIcon, size: 16, color: actionColor),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Cuerpo: portada + info del juego / reseña ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrl != null)
                  Container(
                    width: 100,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      image: DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                if (coverUrl != null) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Estado del juego
                      if (status != null)
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(status),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      // Nota + tiempo de juego
                      if (rating != null && rating > 0 ||
                          (review?['play_time_hours'] ?? 0) > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (rating != null && rating > 0) ...[
                              Icon(
                                Icons.star,
                                color: Theme.of(context).colorScheme.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if ((review?['play_time_hours'] ?? 0) > 0) ...[
                              Icon(
                                Icons.access_time,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(review!['play_time_hours'] as num).toDouble().toStringAsFixed(1)} h',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                            if (replayCount > 0) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.replay,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                replayCount.toString(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Comentario / reseña ──
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                comment,
                style: const TextStyle(fontSize: 16, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Imágenes adjuntas ──
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
                        onTap: () =>
                            _showImageFullScreen(imageUrls[idx] as String),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrls[idx] as String,
                            height: 120,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Acciones (likes / comentarios) solo en reseñas ──
            if (isReview) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  InkWell(
                    onTap: () => _toggleLike(index),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasLiked
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                            size: 20,
                            color: hasLiked
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            likes.length.toString(),
                            style: TextStyle(
                              color: hasLiked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: hasLiked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: openReviewComments,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            comments.length.toString(),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Aquí verás tu actividad y la de tus amigos',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '¡Añade juegos a tu biblioteca o invita a amigos para empezar!',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _fetchActivity,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchActivity,
              child: ListView.builder(
                itemCount: _activities.length,
                itemBuilder: (context, index) =>
                    _buildActivityCard(_activities[index], index),
              ),
            ),
    );
  }
}
