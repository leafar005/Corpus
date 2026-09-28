import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../repositories/activity_repository.dart';
import '../../../repositories/review_repository.dart';
import '../../../models/models.dart';
import '../../../utils/safe_change_notifier.dart';

class ReviewDetailsController extends SafeChangeNotifier {
  ReviewDetailsController({
    required Map<String, dynamic> initialReviewData,
    required this.game,
  }) : currentReviewData = Map<String, dynamic>.from(initialReviewData),
       _activityRepo = ActivityRepository(),
       _reviewRepo = ReviewRepository();

  final Game game;
  final ActivityRepository _activityRepo;
  final ReviewRepository _reviewRepo;

  /// ID del usuario actual, obtenido vía el repo (evita acoplar a Supabase).
  String? get _currentUserId => _reviewRepo.client.auth.currentUser?.id;

  Map<String, dynamic> currentReviewData;
  bool isLoading = true;
  int likesCount = 0;
  bool hasLiked = false;
  List<Map<String, dynamic>> comments = [];
  bool isSubmitting = false;
  List<Map<String, dynamic>> partnersData = [];



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

  Future<void> fetchInteractions() async {
    final currentUserId = _currentUserId;
    final reviewId = currentReviewData['id'] as String?;

    if (currentUserId == null || reviewId == null) {
      isLoading = false;
      notify();
      return;
    }

    try {
      final result = await _activityRepo.fetchInteractions(
        reviewId,
        currentUserId,
      );
      likesCount = result.likesCount;
      hasLiked = result.hasLiked;
      comments = result.comments;
    } catch (e) {
      debugPrint('[ReviewDetailsController] Error fetching interactions: $e');
    } finally {
      isLoading = false;
      notify();
    }
  }

  Future<void> toggleLike() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final reviewId = currentReviewData['id'] as String?;
    if (reviewId == null) return;

    // Optimistic UI update
    hasLiked = !hasLiked;
    likesCount += hasLiked ? 1 : -1;
    notify();

    try {
      await _activityRepo.toggleLike(
        reviewId: reviewId,
        userId: currentUserId,
        currentlyLiked: !hasLiked, // was toggled above, pass pre-toggle value
      );
    } catch (e) {
      // Revert on error
      hasLiked = !hasLiked;
      likesCount += hasLiked ? 1 : -1;
      notify();
      debugPrint('[ReviewDetailsController] Error toggling like: $e');
    }
  }

  Future<void> submitComment({
    required String content,
    XFile? commentImage,
    Map<String, dynamic>? attachedGame,
    String? parentCommentId,
  }) async {
    if (content.isEmpty && commentImage == null && attachedGame == null) return;

    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final reviewId = currentReviewData['id'] as String?;
    if (reviewId == null) return;

    isSubmitting = true;
    notify();

    try {
      await _activityRepo.submitComment(
        reviewId: reviewId,
        userId: currentUserId,
        content: content.isNotEmpty ? content : null,
        commentImage: commentImage,
        attachedGame: attachedGame,
        parentCommentId: parentCommentId,
      );
      await fetchInteractions();
    } finally {
      isSubmitting = false;
      notify();
    }
  }

  Future<void> deleteComment(String commentId) async {
    final comment = comments.firstWhere(
      (c) => c['id'] == commentId,
      orElse: () => <String, dynamic>{},
    );
    await _activityRepo.deleteComment(
      commentId: commentId,
      imageUrl: comment['image_url'] as String?,
    );
    comments.removeWhere((c) => c['id'] == commentId);
    notify();
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
    if (isSubmitting) throw Exception('Already submitting');
    isSubmitting = true;
    notify();

    final userId = _currentUserId;
    if (userId == null) {
      isSubmitting = false;
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

      return result;
    } finally {
      isSubmitting = false;
      notify();
    }
  }
}
