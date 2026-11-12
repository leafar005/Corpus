import 'package:corpus/models/models.dart';
import 'package:corpus/repositories/activity_repository.dart';
import 'package:corpus/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Controlador compartido para el hilo de likes y comentarios de cualquier
/// `feed_post` (individual de reseña o post agrupado).
class PostThreadController extends SafeChangeNotifier {
  PostThreadController({
    String? initialPostId,
    this.reviewId,
    PostStats? initialStats,
    ActivityRepository? repo,
    SupabaseClient? client,
  }) : _repo = repo ?? ActivityRepository(),
       _client = client,
       _postId = initialPostId ?? initialStats?.postId,
       _likesCount = initialStats?.likesCount ?? 0,
       _hasLiked = initialStats?.likedByMe ?? false,
       _commentsCount = initialStats?.commentsCount ?? 0;

  final ActivityRepository _repo;
  final SupabaseClient? _client;
  final String? reviewId;

  String? _postId;
  int _likesCount;
  int _commentsCount;
  bool _hasLiked;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  String? get postId => _postId;
  int get likesCount => _likesCount;
  int get commentsCount =>
      _comments.isNotEmpty ? _comments.length : _commentsCount;
  bool get hasLiked => _hasLiked;
  List<Map<String, dynamic>> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;

  PostStats? get currentStats => _postId == null
      ? null
      : PostStats(
          postId: _postId!,
          likesCount: _likesCount,
          commentsCount: commentsCount,
          likedByMe: _hasLiked,
        );

  String? get _currentUserId =>
      (_client ?? Supabase.instance.client).auth.currentUser?.id;

  void updatePostId(String? newPostId) {
    if (newPostId == null || newPostId == _postId) return;
    _postId = newPostId;
    notifyListeners();
  }

  Future<String?> _ensurePostId() async {
    if (_postId != null) return _postId;
    if (reviewId == null) return null;
    _postId = await _repo.resolvePostIdForReview(reviewId!, create: true);
    if (_postId != null) {
      notifyListeners();
    }
    return _postId;
  }

  Future<void> fetchInteractions({bool resolveLatestReviewPost = false}) async {
    final userId = _currentUserId;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      if ((_postId == null || resolveLatestReviewPost) && reviewId != null) {
        final resolved = await _repo.resolvePostIdForReview(
          reviewId!,
          create: false,
        );
        if (resolved != null) {
          _postId = resolved;
        }
      }

      final pid = _postId;
      if (pid == null) {
        _likesCount = 0;
        _hasLiked = false;
        _comments = [];
        _commentsCount = 0;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final result = await _repo.fetchInteractions(pid, userId);
      _likesCount = result.likesCount;
      _hasLiked = result.hasLiked;
      _comments = result.comments;
      _commentsCount = result.comments.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PostThreadController] fetchInteractions failed: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final wasLiked = _hasLiked;
    _hasLiked = !wasLiked;
    _likesCount += wasLiked ? -1 : 1;
    notifyListeners();

    try {
      final pid = await _ensurePostId();
      if (pid == null) {
        _hasLiked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
        notifyListeners();
        return;
      }

      await _repo.toggleLike(
        postId: pid,
        userId: userId,
        currentlyLiked: wasLiked,
      );
    } catch (e) {
      _hasLiked = wasLiked;
      _likesCount += wasLiked ? 1 : -1;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> submitComment({
    required String? content,
    XFile? commentImage,
    Map<String, dynamic>? attachedGame,
    String? parentCommentId,
  }) async {
    if (_isSubmitting) return false;
    final userId = _currentUserId;
    if (userId == null) return false;

    final trimmed = content?.trim() ?? '';
    if (trimmed.isEmpty && commentImage == null && attachedGame == null) {
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      final pid = await _ensurePostId();
      if (pid == null) return false;

      await _repo.submitComment(
        postId: pid,
        userId: userId,
        content: trimmed,
        commentImage: commentImage,
        attachedGame: attachedGame,
        parentCommentId: parentCommentId,
      );
      await fetchInteractions();
      return true;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteComment(String commentId, {String? imageUrl}) async {
    await _repo.deleteComment(commentId: commentId, imageUrl: imageUrl);
    await fetchInteractions();
  }
}
