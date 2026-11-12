import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../repositories/activity_repository.dart';
import '../../utils/safe_change_notifier.dart';

/// Controller para el feed de actividad social.
///
/// Gestiona el estado de datos (actividades, franja de amigos, stories,
/// paginación, likes) y delega queries al [ActivityRepository].
///
/// **Nota sobre `PaginatedScrollMixin`**: el mixin sigue viviendo en
/// `_ActivityScreenState` porque depende de `ScrollController` y del
/// ciclo de vida de `State`. El screen llama a [fetchActivity] cuando
/// el mixin detecta que el usuario ha scrolleado hasta el fondo.
class ActivityController extends SafeChangeNotifier {
  ActivityController() {
    _userId = _supabase.auth.currentUser?.id;
  }

  final _supabase = Supabase.instance.client;
  final _repo = ActivityRepository();

  String? _userId;

  // ── Estado del feed ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> get activities => _activities;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _offset = 0;
  int get offset => _offset;

  bool hasMore = true;

  bool isLoadingMore = false;

  // ── Franja de amigos (stories) ───────────────────────────────────────
  List<Map<String, dynamic>> _friendsStrip = [];
  List<Map<String, dynamic>> get friendsStrip => _friendsStrip;

  Map<String, List<Map<String, dynamic>>> _userStories = {};
  Map<String, List<Map<String, dynamic>>> get userStories => _userStories;

  bool _isLoadingFriendsStrip = true;
  bool get isLoadingFriendsStrip => _isLoadingFriendsStrip;

  int _pendingRequestsCount = 0;
  int get pendingRequestsCount => _pendingRequestsCount;

  bool get isGuest => _userId == null;

  // ── Realtime ─────────────────────────────────────────────────────────
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSub;

  // ── Ciclo de vida ────────────────────────────────────────────────────

  /// Inicializa el controller. Debe llamarse desde `initState`.
  void init() {
    if (isGuest) {
      _isLoading = false;
      notifyListeners();
    } else {
      fetchActivity(isRefresh: true);
      fetchFriendsStrip();
      _subscribeRealtime();
    }

    // Si el invitado inicia sesión, cargamos el feed.
    _authSub = _supabase.auth.onAuthStateChange.listen((_) {
      _userId = _supabase.auth.currentUser?.id;
      if (_userId == null) return;
      if (_realtimeChannel != null) return; // Ya activo.
      _isLoading = true;
      notifyListeners();
      fetchActivity(isRefresh: true);
      fetchFriendsStrip();
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  // ── Fetch actividad ──────────────────────────────────────────────────

  /// Carga la siguiente página de actividad (o refresca desde el inicio).
  ///
  /// Devuelve `true` si hay más páginas disponibles (para que el mixin
  /// sepa si debe seguir disparando `loadMore`).
  Future<bool> fetchActivity({
    bool isRefresh = false,
    bool silent = false,
  }) async {
    if (isRefresh) {
      _offset = 0;
      hasMore = true;
      if (!silent && _activities.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      if (isLoadingMore || !hasMore) return hasMore;
      isLoadingMore = true;
      notifyListeners();
    }

    try {
      final result = await _repo.fetchActivityPage(_offset);

      if (isRefresh) {
        _activities = result.mergedActivities;
      } else {
        // Rehacer la agrupación sobre la lista acumulada para que un grupo
        // que cruza el límite de página no quede partido.
        _activities = ActivityRepository.groupActivityItems([
          ..._activities,
          ...result.mergedActivities,
        ]);
      }
      _offset = result.nextOffset;
      hasMore = result.hasMore;
      _isLoading = false;
      isLoadingMore = false;
      notifyListeners();
      return hasMore;
    } catch (e) {
      debugPrint('[ActivityController] Error cargando actividad: $e');
      _isLoading = false;
      isLoadingMore = false;
      hasMore = false;
      notifyListeners();
      return false;
    }
  }

  /// Recarga in-place el rango ya cargado (sin cambiar offset/hasMore).
  Future<void> refreshInPlace() async {
    if (_activities.isEmpty) {
      fetchActivity(isRefresh: true, silent: true);
      return;
    }
    try {
      final result = await _repo.fetchActivityPage(0, limit: _offset);
      _activities = result.mergedActivities;
      notifyListeners();
    } catch (e) {
      debugPrint('[ActivityController] Error en refreshInPlace: $e');
    }
  }

  // ── Friends strip ────────────────────────────────────────────────────

  Future<void> fetchFriendsStrip() async {
    try {
      final myId = _userId;
      if (myId == null) return;

      final result = await _repo.fetchFriendsStrip(myId);
      final friendIds = result.friends
          .map((f) => f['id'] as String?)
          .whereType<String>()
          .toList();

      final stories = friendIds.isNotEmpty
          ? await _repo.fetchRecentStoriesForUsers(friendIds)
          : <String, List<Map<String, dynamic>>>{};

      _friendsStrip = result.friends;
      _userStories = stories;
      _pendingRequestsCount = result.pendingCount;
      _isLoadingFriendsStrip = false;
      notifyListeners();

      return; // Las viewed IDs se devuelven via retorno o se notifican
      // El screen las inyecta en viewedStoryIdsNotifier.
    } catch (e) {
      _isLoadingFriendsStrip = false;
      notifyListeners();
    }
  }

  /// Versión que devuelve los IDs vistos para que el screen los inyecte
  /// en `viewedStoryIdsNotifier`.
  Future<Set<String>> fetchFriendsStripWithViewed() async {
    final myId = _userId;
    if (myId == null) return {};

    try {
      final result = await _repo.fetchFriendsStrip(myId);
      final friendIds = result.friends
          .map((f) => f['id'] as String?)
          .whereType<String>()
          .toList();

      final stories = friendIds.isNotEmpty
          ? await _repo.fetchRecentStoriesForUsers(friendIds)
          : <String, List<Map<String, dynamic>>>{};

      final allActivityIds = stories.values
          .expand((list) => list)
          .expand(ActivityRepository.activityIdsOf)
          .toList();

      final viewed = allActivityIds.isNotEmpty
          ? await _repo.fetchViewedStoryIds(
              userId: myId,
              activityIds: allActivityIds,
            )
          : <String>{};

      _friendsStrip = result.friends;
      _userStories = stories;
      _pendingRequestsCount = result.pendingCount;
      _isLoadingFriendsStrip = false;
      notifyListeners();
      return viewed;
    } catch (e) {
      _isLoadingFriendsStrip = false;
      notifyListeners();
      return {};
    }
  }

  // ── Likes ────────────────────────────────────────────────────────────

  void _applyPostStats(int index, PostStats stats) {
    final current = Map<String, dynamic>.from(_activities[index]);
    final statsMap = stats.toMap();
    current['_post'] = statsMap;
    if (stats.postId.isNotEmpty) {
      current['post_id'] ??= stats.postId;
    }

    final review = current['_review'];
    if (review is Map<String, dynamic>) {
      review['_post'] = statsMap;
    } else if (review is Map) {
      final copy = Map<String, dynamic>.from(review);
      copy['_post'] = statsMap;
      current['_review'] = copy;
    }

    final groupedItems = current['_grouped_items'];
    if (groupedItems is List && groupedItems.isNotEmpty) {
      final first = groupedItems.first;
      if (first is Map<String, dynamic>) {
        first['_post'] = statsMap;
      }
    }

    _activities[index] = current;
  }

  /// Alterna like en una actividad por índice (individual o agrupada).
  /// Hace optimistic update y revierte si la petición falla.
  Future<void> toggleLike(int index) async {
    if (index < 0 || index >= _activities.length) return;
    final activity = _activities[index];
    final currentUserId = _userId;
    if (currentUserId == null) return;

    final review = activity['_review'] as Map<String, dynamic>?;
    String? postId =
        (activity['post_id'] as String?) ??
        (PostStats.fromDynamic(activity['_post'])?.postId) ??
        (PostStats.fromDynamic(review?['_post'])?.postId);

    if (postId == null && review?['id'] == null) return;

    final stats =
        PostStats.fromDynamic(
          activity['_post'] ?? review?['_post'],
          fallbackPostId: postId,
        ) ??
        PostStats(postId: postId ?? '');
    final hasLiked = stats.likedByMe;
    final nextStats = stats.copyWith(
      likedByMe: !hasLiked,
      likesCount: (stats.likesCount + (hasLiked ? -1 : 1)).clamp(0, 1 << 30),
    );

    // Optimistic update
    _applyPostStats(index, nextStats);
    notifyListeners();

    try {
      postId ??= await _repo.resolvePostIdForReview(
        review!['id'] as String,
        create: true,
      );
      if (postId == null) {
        _applyPostStats(index, stats);
        notifyListeners();
        return;
      }

      await _repo.toggleLike(
        postId: postId,
        userId: currentUserId,
        currentlyLiked: hasLiked,
      );

      if (nextStats.postId != postId) {
        _applyPostStats(index, nextStats.copyWith(postId: postId));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ActivityController] toggleLike failed: $e');
      _applyPostStats(index, stats);
      notifyListeners();
    }
  }

  // ── Realtime ─────────────────────────────────────────────────────────

  /// Callback para que el screen lo llame cuando reciba un evento realtime.
  /// Recarga el rango acumulado para que la entrada nueva se incorpore al
  /// grupo existente sin perder páginas ya cargadas.
  void onRealtimeEvent() {
    refreshInPlace();
    fetchFriendsStrip();
  }

  void _subscribeRealtime() {
    _realtimeChannel = _supabase
        .channel('activity_feed_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_feed',
          callback: (payload) {
            onRealtimeEvent();
          },
        )
        .subscribe();
  }
}
