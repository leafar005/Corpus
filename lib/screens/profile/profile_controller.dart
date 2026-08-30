import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../repositories/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({this.userId}) : _repo = ProfileRepository() {
    _init();
  }

  final String? userId;
  final ProfileRepository _repo;

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
