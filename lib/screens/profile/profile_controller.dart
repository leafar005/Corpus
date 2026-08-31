import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/activity_repository.dart';

import 'package:corpus/globals.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({this.userId})
    : _repo = ProfileRepository(),
      _activityRepo = ActivityRepository() {
    _init();
  }

  final String? userId;
  final ProfileRepository _repo;
  final ActivityRepository _activityRepo;

  bool _disposed = false;
  StreamSubscription<AuthState>? _authSub;

  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  Map<String, dynamic>? userProfile;
  List<Map<String, dynamic>> wishlistGames = [];
  int wishlistCount = 0;
  List<Map<String, dynamic>> playingGames = [];
  int playingCount = 0;
  List<Map<String, dynamic>> beatenGames = [];
  int beatenCount = 0;
  List<Map<String, dynamic>> platinumGames = [];
  int platinumCount = 0;
  List<double> ratings = [];
  List<Map<String, dynamic>?> hallOfFame = List.filled(5, null);
  int friendsCount = 0;

  List<Map<String, dynamic>> stories = [];

  bool get isOwnProfile {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return userId == null || userId == currentUserId;
  }

  bool get isGuestProfile =>
      userId == null && Supabase.instance.client.auth.currentUser == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _init() {
    if (isGuestProfile) {
      isLoading = false;
      _notify();
    } else {
      fetchProfileData();
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (_disposed || userId != null) return;
      final loggedInNow = Supabase.instance.client.auth.currentUser != null;
      if (loggedInNow && userProfile == null) {
        isLoading = true;
        _notify();
        fetchProfileData();
      } else {
        userProfile = null;
        _notify();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> fetchProfileData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final targetUserId = userId ?? currentUser?.id;
    if (targetUserId == null) {
      isLoading = false;
      _notify();
      return;
    }

    try {
      final data = await _repo.fetchProfileData(
        targetUserId,
        isOwnProfile: userId == null,
      );
      userProfile = data.userProfile;
      wishlistGames = data.wishlistGames;
      wishlistCount = data.wishlistCount;
      playingGames = data.playingGames;
      playingCount = data.playingCount;
      beatenGames = data.beatenGames;
      beatenCount = data.beatenCount;
      platinumGames = data.platinumGames;
      platinumCount = data.platinumCount;
      ratings = data.ratings;
      hallOfFame = data.hallOfFame;
      friendsCount = data.friendsCount;
      hasError = false;
      errorMessage = null;

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final recentStoriesMap = await _activityRepo.fetchRecentStoriesForUsers(
          [targetUserId],
        );
        stories = recentStoriesMap[targetUserId] ?? [];
        if (stories.isNotEmpty) {
          final viewedIds = await _activityRepo.fetchViewedStoryIds(
            userId: currentUserId,
            activityIds: stories.map((e) => e['id'] as String).toList(),
          );
          viewedStoryIdsNotifier.value = {
            ...viewedStoryIdsNotifier.value,
            ...viewedIds,
          };
        }
      }
    } catch (e, st) {
      debugPrint(
        '[ProfileController] Error cargando perfil EXACTO: ${e.runtimeType} - $e\n$st',
      );
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }
}
