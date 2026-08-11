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
  Map<String, dynamic>? userProfile;
  List<Map<String, dynamic>> wishlistGames = [];
  List<Map<String, dynamic>> playingGames = [];
  List<Map<String, dynamic>> allGames = [];
  List<Map<String, dynamic>> userReviews = [];
  List<Map<String, dynamic>?> hallOfFame = List.filled(5, null);

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
      playingGames = data.playingGames;
      allGames = data.beatenGames;
      userReviews = data.reviews;
      hallOfFame = data.hallOfFame;
    } catch (e, st) {
      debugPrint('[ProfileController] Error cargando perfil: $e\n$st');
    } finally {
      isLoading = false;
      _notify();
    }
  }
}
