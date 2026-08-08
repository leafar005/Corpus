import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../globals.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../widgets/coop_badge.dart';
import '../activity/review_details_screen.dart';
import '../profile/profile_screen.dart';
import '../social/friends_screen.dart';
import '../library/game_details_screen.dart';

import '../../widgets/paginated_scroll_mixin.dart';
import '../../theme/corpus_theme_extension.dart';

/// Feed de actividad social en tiempo real.
/// Muestra la actividad del usuario actual y la de sus amigos aceptados.
/// La tabla `activity_feed` se puebla automáticamente mediante triggers
/// de PostgreSQL cuando se cambia el estado de un juego o se escribe una reseña.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with PaginatedScrollMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  int _offset = 0;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSub;

  // Franja de amigos (estilo "historias") en la parte superior.
  List<Map<String, dynamic>> _friendsStrip = [];
  bool _isLoadingFriendsStrip = true;
  int _pendingRequestsCount = 0;

  bool get _isGuest => _supabase.auth.currentUser == null;

  @override
  void initState() {
    super.initState();
    initPagination();
    if (_isGuest) {
      // Invitado: nada de feed ni de suscripción realtime (sin sesión no
      // hay "actividad de tus amigos" que mostrar, y así evitamos abrir
      // un canal realtime y consultas que no llevan a ningún sitio).
      _isLoading = false;
    } else {
      _fetchActivity(isRefresh: true);
      _fetchFriendsStrip();
      _subscribeRealtime();
      libraryUpdateNotifier.addListener(_onLibraryUpdated);
    }

    // Si el invitado inicia sesión desde el botón de esta pantalla,
    // cargamos el feed real y activamos el realtime en ese momento.
    _authSub = _supabase.auth.onAuthStateChange.listen((_) {
      if (!mounted || _supabase.auth.currentUser == null) return;
      if (_realtimeChannel != null) return; // Ya activo tras un login anterior.
      setState(() => _isLoading = true);
      _fetchActivity(isRefresh: true);
      _fetchFriendsStrip();
      _subscribeRealtime();
      libraryUpdateNotifier.addListener(_onLibraryUpdated);
    });
  }

  @override
  void dispose() {
    disposePagination();
    _realtimeChannel?.unsubscribe();
    libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    _authSub?.cancel();
    super.dispose();
  }

  void _onLibraryUpdated() {
    if (mounted) _fetchActivity(isRefresh: true, silent: true);
  }

  Future<void> _fetchFriendsStrip() async {
    try {
      final myId = _supabase.auth.currentUser!.id;

      final asSender = await _supabase
          .from('friendships')
          .select(
            'friend:addressee_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name)',
          )
          .eq('requester_id', myId)
          .eq('status', 'accepted');

      final asReceiver = await _supabase
          .from('friendships')
          .select(
            'friend:requester_id(id, username, avatar_url, display_name, currently_playing_appid, currently_playing_name)',
          )
          .eq('addressee_id', myId)
          .eq('status', 'accepted');

      final friends = <Map<String, dynamic>>[
        ...List<Map<String, dynamic>>.from(
          asSender,
        ).map((e) => e['friend'] as Map<String, dynamic>),
        ...List<Map<String, dynamic>>.from(
          asReceiver,
        ).map((e) => e['friend'] as Map<String, dynamic>),
      ];

      final pending = await _supabase
          .from('friendships')
          .select('requester_id')
          .eq('addressee_id', myId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _friendsStrip = friends;
          _pendingRequestsCount = List.from(pending).length;
          _isLoadingFriendsStrip = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriendsStrip = false);
    }
  }

  Future<void> _openFriendsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
    // Al volver, refrescamos por si se aceptaron/enviaron solicitudes.
    if (mounted) _fetchFriendsStrip();
  }

  @override
  Future<void> loadMore() async {
    await _fetchActivity(isRefresh: false);
  }

  // ──────────────────────────────────────────
  // DATOS
  // ──────────────────────────────────────────

  Future<void> _fetchActivity({
    bool isRefresh = false,
    bool silent = false,
  }) async {
    if (isRefresh) {
      _offset = 0;
      hasMore = true;
      if (!silent && _activities.isEmpty) {
        setState(() => _isLoading = true);
      }
    } else {
      if (isLoadingMore || !hasMore) return;
      setState(() => isLoadingMore = true);
    }

    try {
      final from = _offset;
      final to = _offset + 29;

      // 1. Una sola query para el feed completo
      final response = await _supabase
          .from('activity_feed')
          .select('''
            *,
            users!activity_feed_user_id_fkey(id, username, display_name, avatar_url),
            games!activity_feed_game_id_fkey(igdb_id, title, cover_url)
          ''')
          .order('created_at', ascending: false)
          .range(from, to);

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
              .select(
                '*, review_likes(user_id), review_comments(id), users!reviews_partner_id_fkey(id, username, avatar_url)',
              )
              .inFilter('id', reviewIds);
          for (final r in List<Map<String, dynamic>>.from(reviewsResp)) {
            reviewsById[r['id'] as String] = r;
          }
        } catch (_) {}
      }

      // 3.5. Query batch para el partner (user_games)
      final Map<String, Map<String, dynamic>> partnerByUserGame = {};
      final userIds = feedItems
          .map((e) => e['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final gameIds = feedItems
          .map((e) => e['game_id'])
          .where((e) => e != null)
          .toSet()
          .toList();
      if (userIds.isNotEmpty && gameIds.isNotEmpty) {
        try {
          final ugResp = await _supabase
              .from('user_games')
              .select(
                'user_id, game_id, partner:users!user_games_partner_id_fkey(id, username, avatar_url)',
              )
              .inFilter('user_id', userIds)
              .inFilter('game_id', gameIds);
          for (final ug in List<Map<String, dynamic>>.from(ugResp)) {
            final partner = ug['partner'];
            if (partner != null) {
              partnerByUserGame['${ug['user_id']}_${ug['game_id']}'] =
                  partner as Map<String, dynamic>;
            }
          }
        } catch (_) {}
      }

      // 4. Enriquecer items y agrupar eventos relacionados (lógica de merge sin queries)
      final mergedActivities = <Map<String, dynamic>>[];
      for (var item in feedItems) {
        final uId = item['user_id'];
        final gId = item['game_id'];
        if (uId != null && gId != null) {
          item['_partner'] = partnerByUserGame['${uId}_$gId'];
        }

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
          if (isRefresh) {
            _activities = mergedActivities;
          } else {
            _activities.addAll(mergedActivities);
          }
          _offset += 30;
          hasMore = feedItems.length == 30;
          _isLoading = false;
          isLoadingMore = false;
        });
        if (hasMore) {
          triggerScrollCheck();
        }
      }
    } catch (e) {
      debugPrint('[ActivityScreen] Error cargando actividad: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          isLoadingMore = false;
          hasMore = false;
        });
      }
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
            if (mounted) _fetchActivity(isRefresh: true, silent: true);
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

  String _getActionText(String actionType, String? status, bool isOwnActivity) {
    switch (actionType) {
      case 'status_change':
        switch (status) {
          case 'playing':
            return isOwnActivity ? 'has empezado a jugar a' : 'está jugando a';
          case 'beaten':
            return isOwnActivity ? 'has completado' : 'ha completado';
          case 'wishlist':
            return isOwnActivity
                ? 'has añadido a la wishlist'
                : 'quiere jugar a';
          case 'abandoned':
            return isOwnActivity ? 'has abandonado' : 'ha abandonado';
          case 'on_hold':
            return isOwnActivity ? 'has pausado' : 'ha pausado';
          default:
            return isOwnActivity ? 'has actualizado' : 'actualizó';
        }
      case 'reviewed':
        return isOwnActivity ? 'has reseñado' : 'ha reseñado';
      case 'achievement':
        return isOwnActivity
            ? 'has desbloqueado un logro en'
            : 'ha desbloqueado un logro en';
      default:
        return isOwnActivity ? 'has interactuado con' : 'hizo algo con';
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
    final partner = activity['_partner'] as Map<String, dynamic>?;

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

    final myId = _supabase.auth.currentUser?.id;
    final activityUserId = userData['id'] as String?;
    final isOwnActivity = myId == activityUserId;

    final actionText = _getActionText(actionType, status, isOwnActivity);
    final actionIcon = _getActionIcon(actionType, status);
    final actionColor = _getActionColor(actionType, status, context);

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
      ).then((_) => _fetchActivity(isRefresh: true, silent: true));
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
      ).then((_) => _fetchActivity(isRefresh: true, silent: true));
    }

    void openGameDetails() {
      final isDesktop = MediaQuery.of(context).size.width > 800;
      if (isDesktop) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(gameData: gameData),
          ),
        ).then((_) => _fetchActivity(isRefresh: true, silent: true));
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
            builder: (context, scrollController) => GameDetailsScreen(
              gameData: gameData,
              scrollController: scrollController,
            ),
          ),
        ).then((_) => _fetchActivity(isRefresh: true, silent: true));
      }
    }

    return GestureDetector(
      onTap: isReview ? openReview : openGameDetails,
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
                      borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusSmall,
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
                      if (partner != null) ...[
                        const SizedBox(height: 8),
                        CoopBadge(
                          username: partner['username'] ?? 'Usuario',
                          avatarUrl: partner['avatar_url'],
                          size: 20,
                          status: status,
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
                        onTap: () {
                          final strUrls = imageUrls
                              .map((e) => e.toString())
                              .toList();
                          showFullScreenGallery(context, strUrls, idx);
                        },
                        child: ClipRRect(
                          borderRadius: Theme.of(context).extension<CorpusThemeExtension>()!.radiusSmall,
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

  // _showImageFullScreen removed in favor of full_screen_gallery.dart
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

  // ──────────────────────────────────────────
  // FRANJA DE AMIGOS
  // ──────────────────────────────────────────

  Widget _buildFriendsStrip() {
    return Container(
      height: 96,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: _isLoadingFriendsStrip
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _friendsStrip.isEmpty
          ? Center(
              child: TextButton.icon(
                onPressed: _openFriendsScreen,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Añade amigos para ver su actividad'),
              ),
            )
          // NUEVO: Escuchamos los cambios en el estado online global
          : ValueListenableBuilder<Set<String>>(
              valueListenable: onlineUsersNotifier,
              builder: (context, onlineUsers, child) {
                final sortedFriends = List<Map<String, dynamic>>.from(
                  _friendsStrip,
                );
                sortedFriends.sort((a, b) {
                  final aPlaying =
                      a['currently_playing_appid'] != null &&
                      a['currently_playing_name'] != null;
                  final bPlaying =
                      b['currently_playing_appid'] != null &&
                      b['currently_playing_name'] != null;

                  final aId = a['id'] as String?;
                  final bId = b['id'] as String?;

                  final aOnline = aId != null && onlineUsers.contains(aId);
                  final bOnline = bId != null && onlineUsers.contains(bId);

                  final aScore = aPlaying ? 2 : (aOnline ? 1 : 0);
                  final bScore = bPlaying ? 2 : (bOnline ? 1 : 0);

                  if (aScore != bScore) {
                    return bScore.compareTo(aScore);
                  }
                  // En caso de empate, ordenamos alfabéticamente por nombre
                  final aName =
                      (a['display_name'] as String? ??
                              a['username'] as String? ??
                              '')
                          .toLowerCase();
                  final bName =
                      (b['display_name'] as String? ??
                              b['username'] as String? ??
                              '')
                          .toLowerCase();
                  return aName.compareTo(bName);
                });

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sortedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = sortedFriends[index];
                    final friendId = friend['id'] as String?;
                    final displayName =
                        friend['display_name'] as String? ??
                        friend['username'] as String? ??
                        'Usuario';
                    final avatarUrl = friend['avatar_url'] as String?;

                    // Lógica del juego en curso
                    final playingGame =
                        friend['currently_playing_name'] as String?;
                    final isPlaying =
                        friend['currently_playing_appid'] != null &&
                        playingGame != null;

                    // Lógica de si está online
                    final isOnline =
                        friendId != null && onlineUsers.contains(friendId);

                    final playingColor = Colors.greenAccent[400]!;
                    const onlineColor =
                        Colors.blueAccent; // Color cuando solo están conectados

                    return GestureDetector(
                      onTap: () {
                        if (friendId == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: friendId),
                          ),
                        );
                      },
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? const Icon(Icons.person, size: 26)
                                      : null,
                                ),
                                // Dibujamos el punto si están jugando O si están online
                                if (isPlaying || isOnline)
                                  Positioned(
                                    bottom: -1,
                                    right: -1,
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // Prioridad al color verde si están jugando, azul si solo están en la app
                                        color: isPlaying
                                            ? playingColor
                                            : onlineColor,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (isPlaying)
                              Text(
                                playingGame,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: playingColor,
                                ),
                              )
                            else
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildFriendsHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Amigos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        _buildFriendsStrip(),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Actividad')),
        body: const Center(
          child: GuestLoginPrompt(
            icon: Icons.people_outline_rounded,
            message: 'Inicia sesión para ver la actividad de tus amigos.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _pendingRequestsCount > 0,
              label: Text(_pendingRequestsCount.toString()),
              child: const Icon(Icons.people_rounded),
            ),
            tooltip: 'Amigos',
            onPressed: _openFriendsScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchActivity(isRefresh: true),
              child: _activities.isEmpty
                  ? ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: getBottomSpacer(context)),

                      children: [
                        _buildFriendsHeaderSection(),
                        _buildEmptyState(),
                      ],
                    )
                  : ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: getBottomSpacer(context)),

                      itemCount: _activities.length + 1 + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildFriendsHeaderSection();
                        }
                        final activityIndex = index - 1;
                        if (activityIndex >= _activities.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildActivityCard(
                          _activities[activityIndex],
                          activityIndex,
                        );
                      },
                    ),
            ),
    );
  }
}
