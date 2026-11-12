import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../../repositories/activity_repository.dart';
import '../../../repositories/review_repository.dart';
import '../../../models/models.dart';
import '../../../utils/safe_change_notifier.dart';
import '../widgets/post_thread_controller.dart';

class ReviewDetailsController extends SafeChangeNotifier {
  ReviewDetailsController({
    required Map<String, dynamic> initialReviewData,
    required this.game,
    String? postId,
  }) : currentReviewData = Map<String, dynamic>.from(initialReviewData),
       _activityRepo = ActivityRepository(),
       _reviewRepo = ReviewRepository() {
    final initialStats = PostStats.fromDynamic(initialReviewData['_post']);
    postThread = PostThreadController(
      initialPostId: postId ?? initialStats?.postId,
      reviewId: initialReviewData['id'] as String?,
      initialStats: initialStats,
      repo: _activityRepo,
    );
    postThread.addListener(notify);
  }

  final Game game;
  final ActivityRepository _activityRepo;
  final ReviewRepository _reviewRepo;
  late final PostThreadController postThread;

  /// ID del usuario actual, obtenido vía el repo (evita acoplar a Supabase).
  String? get _currentUserId => _reviewRepo.client.auth.currentUser?.id;

  Map<String, dynamic> currentReviewData;
  bool _isSavingReview = false;
  List<Map<String, dynamic>> partnersData = [];

  String? get postId => postThread.postId;
  bool get isLoading => postThread.isLoading;
  int get likesCount => postThread.likesCount;
  bool get hasLiked => postThread.hasLiked;
  List<Map<String, dynamic>> get comments => postThread.comments;
  bool get isSubmitting => _isSavingReview || postThread.isSubmitting;

  @override
  void dispose() {
    postThread.removeListener(notify);
    postThread.dispose();
    super.dispose();
  }

  Future<void> fetchPartner() async {
    final partners = currentReviewData['partners'];
    if (partners is List) {
      partnersData = List<Map<String, dynamic>>.from(partners);
      notify();
    } else {
      partnersData = [];
      notify();
    }
  }

  Future<void> fetchInteractions({bool resolveLatestReviewPost = false}) =>
      postThread.fetchInteractions(
        resolveLatestReviewPost: resolveLatestReviewPost,
      );

  Future<void> toggleLike() => postThread.toggleLike();

  Future<bool> submitComment({
    required String content,
    XFile? commentImage,
    Map<String, dynamic>? attachedGame,
    String? parentCommentId,
  }) => postThread.submitComment(
    content: content.isNotEmpty ? content : null,
    commentImage: commentImage,
    attachedGame: attachedGame,
    parentCommentId: parentCommentId,
  );

  Future<void> deleteComment(String commentId, {String? imageUrl}) async {
    final resolvedImageUrl =
        imageUrl ??
        comments.firstWhere(
              (c) => c['id'] == commentId,
              orElse: () => <String, dynamic>{},
            )['image_url']
            as String?;
    await postThread.deleteComment(commentId, imageUrl: resolvedImageUrl);
  }

  Future<void> deleteReview(String reviewId) async {
    final gameId = game.igdbId;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    await _reviewRepo.deleteReview(
      reviewId: reviewId,
      gameId: gameId,
      reviewData: Review.fromMap(currentReviewData),
    );
  }

  Future<SaveReviewResult> saveReviewModal({
    String? reviewId,
    required double rating,
    required double ratingGameplay,
    required double ratingNarrative,
    required double ratingSoundtrack,
    required double ratingVisuals,
    required String comment,
    required String status,
    required String completionType,
    required bool isReplay,
    required int? replayNumber,
    required String? platform,
    required double? playTimeHours,
    required DateTime? playedFrom,
    required DateTime? playedUntil,
    required int? progressPercent,
    required DateTime? reviewDate,
    required List<XFile> newImages,
    required List<String> existingImages,
    required List<String> partnerIds,
  }) async {
    if (_isSavingReview) throw Exception('Already submitting');
    _isSavingReview = true;
    notify();

    final userId = _currentUserId;
    if (userId == null) {
      _isSavingReview = false;
      notify();
      throw Exception('Not logged in');
    }

    final igdbId = game.igdbId;

    try {
      final result = await _reviewRepo.saveReview(
        userId: userId,
        igdbId: igdbId,
        gameData: game.toMap(),
        // FIX (3.2): Antes pasaba game.toMap() como enrichedData, duplicando
        // los mismos datos. El ReviewDetailsScreen no ejecuta enrichGameData,
        // así que no tiene datos IGDB adicionales. Pasar mapa vacío para que
        // upsertGame use solo los campos de gameData.
        enrichedData: const <String, dynamic>{},
        reviewId: reviewId ?? currentReviewData['id'],
        rating: rating,
        ratingGameplay: ratingGameplay,
        ratingNarrative: ratingNarrative,
        ratingSoundtrack: ratingSoundtrack,
        ratingVisuals: ratingVisuals,
        comment: comment,
        status: status,
        completionType: completionType,
        isReplay: isReplay,
        replayNumber: replayNumber,
        platform: platform,
        playTimeHours: playTimeHours,
        playedFrom: playedFrom,
        playedUntil: playedUntil,
        progressPercent: progressPercent,
        reviewDate: reviewDate,
        newImages: newImages,
        existingImages: existingImages,
        partnerIds: partnerIds,
      );

      final updatedReview = await _activityRepo.fetchUpdatedReview(
        currentReviewData['id'] as String,
        fallbackUserData: currentReviewData['users'] as Map<String, dynamic>?,
      );

      if (updatedReview != null) {
        currentReviewData = updatedReview;
      }

      await fetchPartner();
      unawaited(postThread.fetchInteractions(resolveLatestReviewPost: true));

      return result;
    } finally {
      _isSavingReview = false;
      notify();
    }
  }
}
