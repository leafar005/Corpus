import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/utils/format_utils.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../globals.dart';
import '../../widgets/guest_login_prompt.dart';
import '../../widgets/full_screen_gallery.dart';
import '../../widgets/coop_badge.dart';
import '../activity/activity_formatters.dart';
import '../activity/activity_story_viewer.dart';
import '../library/game_details_screen.dart';
import '../../repositories/activity_repository.dart';
import '../../widgets/corpus_network_image.dart';
import '../../widgets/paginated_scroll_mixin.dart';
import '../../models/models.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';
import '../../widgets/activity_story_ring.dart';

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
  final _repo = ActivityRepository();

  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  int _offset = 0;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSub;

  // Franja de amigos (estilo "historias") en la parte superior.
  List<Map<String, dynamic>> _friendsStrip = [];
  Map<String, List<Map<String, dynamic>>> _userStories = {};
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
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      final result = await _repo.fetchFriendsStrip(myId);
      final friendIds = result.friends
          .map((f) => f['id'] as String?)
          .whereType<String>()
          .toList();

      final stories = friendIds.isNotEmpty
          ? await _repo.fetchRecentStoriesForUsers(friendIds)
          : <String, List<Map<String, dynamic>>>{};

      if (mounted) {
        setState(() {
          _friendsStrip = result.friends;
          _userStories = stories;
          _pendingRequestsCount = result.pendingCount;
          _isLoadingFriendsStrip = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriendsStrip = false);
    }
  }

  void _openUserStory(Map<String, dynamic> userData) {
    final userId = userData['id'] as String?;
    if (userId == null) return;

    final stories = _userStories[userId];
    if (stories == null || stories.isEmpty) {
      context.pushProfile(userId: userId);
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, secondaryAnimation) => ActivityStoryViewer(
          userData: userData,
          activities: stories,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openFriendsScreen() async {
    await context.pushFriends();
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
      final result = await _repo.fetchActivityPage(_offset);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _activities = result.mergedActivities;
          } else {
            _activities.addAll(result.mergedActivities);
          }
          _offset = result.nextOffset;
          hasMore = result.hasMore;
          _isLoading = false;
          isLoadingMore = false;
        });
        if (hasMore) triggerScrollCheck();
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

  Future<void> _refreshInPlace() async {
    if (_activities.isEmpty) {
      _fetchActivity(isRefresh: true, silent: true);
      return;
    }
    try {
      final result = await _repo.fetchActivityPage(0, limit: _offset);
      if (mounted) {
        setState(() {
          _activities = result.mergedActivities;
        });
      }
    } catch (e) {
      debugPrint('[ActivityScreen] Error en refreshInPlace: $e');
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
            if (!mounted) return;
            // Incrementar badge de notificaciones no leídas en la nav bar.
            // El reset lo hace MainScreen cuando el usuario abre la pestaña.
            unreadActivityCount.value++;
            _fetchActivity(isRefresh: true, silent: true);
            _fetchFriendsStrip();
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

  String _formatDate(String isoString) =>
      ActivityFormatters.formatRelativeDate(isoString);

  String _getStatusText(String status) => GameStatus.labelForString(status);

  IconData _getStatusIcon(String status) => GameStatus.iconForString(status);

  String _getActionText(String actionType, String? status, bool isOwnActivity) =>
      ActivityFormatters.actionText(
        actionType,
        status,
        isOwnActivity: isOwnActivity,
      );

  IconData _getActionIcon(String actionType, String? status) =>
      ActivityFormatters.actionIcon(actionType, status);

  Color _getActionColor(String actionType, String? status, BuildContext ctx) =>
      ActivityFormatters.actionColor(actionType, status, ctx);

  // ──────────────────────────────────────────
  // CARD
  // ──────────────────────────────────────────

  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    final userData = activity['users'] as Map<String, dynamic>? ?? {};
    final gameData = activity['games'] as Map<String, dynamic>? ?? {};
    final meta = activity['metadata'] as Map<String, dynamic>? ?? {};
    final review = activity['_review'] as Map<String, dynamic>?;
    final partners = activity['_partners'] as List<dynamic>? ?? [];

    final displayName =
        userData['display_name'] as String? ??
        userData['username'] as String? ??
        'Usuario';
    final avatarUrl = userData['avatar_url'] as String?;
    final gameTitle = gameData['title'] as String? ?? 'Juego desconocido';
    final coverUrl = gameData['cover_url'] as String?;

    final actionType = activity['action_type'] as String? ?? 'status_change';
    // El status efectivo: para eventos 'reviewed', tomamos el status de la propia
    // reseña (que refleja el estado real del juego). Para 'achievement' usamos
    // una clave especial. Para status_change usamos el metadata directamente.
    final String? effectiveStatus = actionType == 'reviewed'
        ? (review?['status'] as String? ?? meta['status'] as String?)
        : actionType == 'achievement'
        ? 'achievement'
        : meta['status'] as String?;
    final dateStr = _formatDate(activity['created_at'] as String? ?? '');

    final myId = _supabase.auth.currentUser?.id;
    final activityUserId = userData['id'] as String?;
    final isOwnActivity = myId == activityUserId;

    final actionText = _getActionText(actionType, effectiveStatus, isOwnActivity);
    final actionIcon = _getActionIcon(actionType, effectiveStatus);
    final actionColor = _getActionColor(actionType, effectiveStatus, context);

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
      context
          .pushReviewDetails(gameData, userData, review)
          .then((_) => _refreshInPlace());
    }

    void openReviewComments() {
      if (review == null) return;
      context
          .pushReviewDetails(
            gameData,
            userData,
            review,
            focusComment: true,
          )
          .then((_) => _refreshInPlace());
    }

    void openGameDetails() {
      final isDesktop = MediaQuery.of(context).size.width > 800;
      if (isDesktop) {
        context
            .pushGameDetails(gameData)
            .then((_) => _refreshInPlace());
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
        ).then((_) => _refreshInPlace());
      }
    }

    void handleStatusChangeTap() async {
      final uId = activityUserId;
      final internalGameId = activity['game_id'] as int?;

      if (uId != null && internalGameId != null) {
        final review = await _repo.fetchLatestReviewForUserAndGame(uId, internalGameId);
        if (review != null && mounted) {
           context.pushReviewDetails(
             gameData,
             userData,
             review,
           ).then((_) => _refreshInPlace());
           return;
        }
      }
      
      openGameDetails();
    }

    return GestureDetector(
      onTap: isReview ? openReview : handleStatusChangeTap,
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
                      context.pushProfile(userId: activityUserId);
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
                        context.pushProfile(userId: activityUserId);
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
                      borderRadius: Theme.of(
                        context,
                      ).extension<CorpusThemeExtension>()!.radiusSmall,
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
                      if (effectiveStatus != null && effectiveStatus != 'achievement')
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(effectiveStatus),
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(effectiveStatus),
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
                                formatRating(rating),
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
                      if (partners.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: partners.map((partner) {
                            return CoopBadge(
                              username: partner['username'] ?? 'Usuario',
                              avatarUrl: partner['avatar_url'],
                              size: 20,
                              status: effectiveStatus,
                              userId: partner['id'] as String?,
                            );
                          }).toList(),
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
                          borderRadius: Theme.of(
                            context,
                          ).extension<CorpusThemeExtension>()!.radiusSmall,
                          child: CorpusNetworkImage(
                            url: imageUrls[idx] as String,
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
      height: 110,
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
                  final aId = a['id'] as String?;
                  final bId = b['id'] as String?;

                  final aHasStory =
                      aId != null && (_userStories[aId]?.isNotEmpty ?? false);
                  final bHasStory =
                      bId != null && (_userStories[bId]?.isNotEmpty ?? false);

                  final aPlaying =
                      a['currently_playing_appid'] != null &&
                      a['currently_playing_name'] != null;
                  final bPlaying =
                      b['currently_playing_appid'] != null &&
                      b['currently_playing_name'] != null;

                  final aOnline = aId != null && onlineUsers.contains(aId);
                  final bOnline = bId != null && onlineUsers.contains(bId);

                  // Prioridad: historia reciente > jugando > online > alfabético
                  final aScore =
                      (aHasStory ? 4 : 0) +
                      (aPlaying ? 2 : 0) +
                      (aOnline ? 1 : 0);
                  final bScore =
                      (bHasStory ? 4 : 0) +
                      (bPlaying ? 2 : 0) +
                      (bOnline ? 1 : 0);

                  if (aScore != bScore) {
                    return bScore.compareTo(aScore);
                  }

                  // En caso de empate (ambos jugando o ambos offline), ordenamos por actividad (XP).
                  // Así los usuarios más inactivos (pocos juegos) se van al final.
                  final aXp = (a['xp'] as num?)?.toInt() ?? 0;
                  final bXp = (b['xp'] as num?)?.toInt() ?? 0;
                  if (aXp != bXp) {
                    return bXp.compareTo(aXp); // Mayor XP primero
                  }

                  // En caso de empate de XP, ordenamos alfabéticamente por nombre
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

                    final hasStory =
                        friendId != null &&
                        (_userStories[friendId]?.isNotEmpty ?? false);

                    final playingColor = Colors.greenAccent[400]!;
                    const onlineColor =
                        Colors.blueAccent;

                    return GestureDetector(
                      onTap: () {
                        if (friendId == null) return;
                        _openUserStory(friend);
                      },
                      onLongPress: () {
                        if (friendId == null) return;
                        context.pushProfile(userId: friendId);
                      },
                      child: Container(
                        width: 76,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ActivityStoryRing(
                                  radius: 30,
                                  hasStory: hasStory,
                                  avatarUrl: avatarUrl,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                // Dibujamos el punto si están jugando O si están online
                                if (isPlaying || isOnline)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 17,
                                      height: 17,
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
        appBar: AppBar(title: const CorpusScreenTitle('Actividad')),
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
        title: const CorpusScreenTitle('Actividad'),
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
              onRefresh: () async {
                await _fetchActivity(isRefresh: true);
                await _fetchFriendsStrip();
              },
              child: _activities.isEmpty
                  ? ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: getBottomSpacer(context),
                      ),

                      children: [
                        _buildFriendsHeaderSection(),
                        _buildEmptyState(),
                      ],
                    )
                  : ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: getBottomSpacer(context),
                      ),

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
