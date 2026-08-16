import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class ProfileData {
  const  ProfileData({
    required this.userProfile,
    required this.wishlistGames,
    required this.wishlistCount,
    required this.playingGames,
    required this.playingCount,
    required this.beatenGames,
    required this.beatenCount,
    required this.platinumGames,
    required this.platinumCount,
    required this.ratings,
    required this.hallOfFame,
    required this.friendsCount,
  });

  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> wishlistGames;
  final int wishlistCount;
  final List<Map<String, dynamic>> playingGames;
  final int playingCount;
  final List<Map<String, dynamic>> beatenGames;
  final int beatenCount;
  final List<Map<String, dynamic>> platinumGames;
  final int platinumCount;
  
  /// Lista de todas las notas (ratings) del usuario para el histograma, sin los joins pesados.
  final List<double> ratings;
  
  final List<Map<String, dynamic>?> hallOfFame;

  final int friendsCount;

  ProfileData copyWith({
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? wishlistGames,
    int? wishlistCount,
    List<Map<String, dynamic>>? playingGames,
    int? playingCount,
    List<Map<String, dynamic>>? beatenGames,
    int? beatenCount,
    List<Map<String, dynamic>>? platinumGames,
    int? platinumCount,
    List<double>? ratings,
    List<Map<String, dynamic>?>? hallOfFame,
    int? friendsCount,
  }) {
    return ProfileData(
      userProfile: userProfile ?? this.userProfile,
      wishlistGames: wishlistGames ?? this.wishlistGames,
      wishlistCount: wishlistCount ?? this.wishlistCount,
      playingGames: playingGames ?? this.playingGames,
      playingCount: playingCount ?? this.playingCount,
      beatenGames: beatenGames ?? this.beatenGames,
      beatenCount: beatenCount ?? this.beatenCount,
      platinumGames: platinumGames ?? this.platinumGames,
      platinumCount: platinumCount ?? this.platinumCount,
      ratings: ratings ?? this.ratings,
      hallOfFame: hallOfFame ?? this.hallOfFame,
      friendsCount: friendsCount ?? this.friendsCount,
    );
  }
}

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchUserProfile(
    String userId, {
    bool isOwnProfile = false,
  }) async {
    var profile = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profile == null && isOwnProfile) {
      final email = _client.auth.currentUser?.email ?? 'jugador';
      final defaultUsername = email.split('@')[0];
      try {
        profile = await _client
            .from('users')
            .insert({'id': userId, 'username': defaultUsername})
            .select()
            .single();
      } catch (e) {
        debugPrint('[ProfileRepository] No se pudo crear el perfil: $e');
        profile = {'username': defaultUsername};
      }
    }

    return profile;
  }

  Future<List<dynamic>> fetchHallOfFame(String userId) async {
    try {
      return await _client
          .from('hall_of_fame')
          .select('*, games(*)')
          .eq('user_id', userId)
          .order('pin_order', ascending: true);
    } catch (e) {
      debugPrint('[ProfileRepository] Hall of fame no disponible: $e');
      return [];
    }
  }

  Future<ProfileData> fetchProfileData(
    String userId, {
    bool isOwnProfile = false,
  }) async {
    final userProfile = await fetchUserProfile(
      userId,
      isOwnProfile: isOwnProfile,
    );

    final results = await Future.wait<dynamic>([
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'wishlist')
          .neq('is_steam_only', true)
          .order('updated_at', ascending: false)
          .limit(20),
      _client
          .from('user_games')
          .select('user_id')
          .eq('user_id', userId)
          .eq('status', 'wishlist')
          .neq('is_steam_only', true),
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'playing')
          .order('updated_at', ascending: false)
          .limit(20),
      _client
          .from('user_games')
          .select('user_id')
          .eq('user_id', userId)
          .eq('status', 'playing'),
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'beaten')
          .order('last_played_at', ascending: false, nullsFirst: false)
          .limit(20),
      _client
          .from('user_games')
          .select('user_id')
          .eq('user_id', userId)
          .eq('status', 'beaten'),
      (() async {
        final platinoReviews = await _client
            .from('reviews')
            .select('game_id')
            .eq('user_id', userId)
            .eq('completion_type', '100_percent');
        final platinoGameIds = platinoReviews.map((r) => r['game_id'] as int).toList();
        if (platinoGameIds.isEmpty) return [];
        return await _client
            .from('user_games')
            .select('*, games!inner(*)')
            .eq('user_id', userId)
            .inFilter('game_id', platinoGameIds)
            .order('last_played_at', ascending: false, nullsFirst: false)
            .limit(20);
      })(),
      (() async {
        final platinoReviews = await _client
            .from('reviews')
            .select('game_id')
            .eq('user_id', userId)
            .eq('completion_type', '100_percent');
        return platinoReviews;
      })(),
      fetchHallOfFame(userId),
      _client
          .from('reviews')
          .select('rating')
          .eq('user_id', userId),
      _client
          .from('friendships')
          .select('requester_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId'),
    ]);

    final wishlistRes = results[0] as List<dynamic>;
    final wishlistCountRes = results[1] as List<dynamic>;
    final playingRes = results[2] as List<dynamic>;
    final playingCountRes = results[3] as List<dynamic>;
    final beatenRes = results[4] as List<dynamic>;
    final beatenCountRes = results[5] as List<dynamic>;
    final platinumRes = results[6] as List<dynamic>;
    final platinumCountRes = results[7] as List<dynamic>;
    final rawHallOfFame = results[8] as List<dynamic>;
    final ratingsRes = results[9] as List<dynamic>;
    final friendshipsRes = results[10] as List<dynamic>;

    return ProfileData(
      userProfile: userProfile,
      wishlistGames: _enrichList(wishlistRes),
      wishlistCount: wishlistCountRes.length,
      playingGames: _enrichList(playingRes),
      playingCount: playingCountRes.length,
      beatenGames: _enrichList(beatenRes, useLastPlayed: true),
      beatenCount: beatenCountRes.length,
      platinumGames: _enrichList(platinumRes, useLastPlayed: true),
      platinumCount: platinumCountRes.length,
      ratings: ratingsRes
          .map((e) => (e['rating'] as num?)?.toDouble() ?? 0.0)
          .toList(),
      hallOfFame: _parseHallOfFame(rawHallOfFame),
      friendsCount: friendshipsRes.length,
    );
  }

  static List<Map<String, dynamic>> _enrichList(
    List<dynamic> rawGames, {
    bool useLastPlayed = false,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final row in rawGames) {
      final gameData = _enrichGameData(row, useLastPlayed: useLastPlayed);
      if (gameData != null) {
        result.add(gameData);
      }
    }
    // We also sort them internally just to be absolutely sure they are in order.
    result.sort((a, b) => (b['_sort_date'] as String).compareTo(a['_sort_date'] as String));
    return result;
  }

  static Map<String, dynamic>? _enrichGameData(
    dynamic row, {
    bool useLastPlayed = false,
  }) {
    final gameData = row['games'];
    if (gameData == null) return null;

    final enriched = Map<String, dynamic>.from(gameData as Map);
    final rating = (row['rating'] ?? 0).toDouble();
    enriched['user_rating'] = rating;

    final updatedAt = row['updated_at']?.toString() ?? '';
    final lastPlayedAt = row['last_played_at']?.toString() ?? updatedAt;
    enriched['_sort_date'] = useLastPlayed ? lastPlayedAt : updatedAt;

    return enriched;
  }

  static List<Map<String, dynamic>?> _parseHallOfFame(
    List<dynamic> rawHallOfFame,
  ) {
    final result = List<Map<String, dynamic>?>.filled(5, null);
    try {
      for (final row in rawHallOfFame) {
        final order = row['pin_order'] as int?;
        if (order == null || order < 1 || order > 5) continue;
        final gameData = row['games'];
        if (gameData == null) continue;
        result[order - 1] = Map<String, dynamic>.from(gameData as Map);
      }
    } catch (e) {
      debugPrint('[ProfileRepository] Error parseando hall of fame: $e');
    }
    return result;
  }

  Future<List<GenreRadarEntry>> fetchGenreRadarEntries(String userId) async {
    final rows = await _client
        .from('user_games')
        .select(
          'game_id, status, play_time_hours, last_played_at, updated_at, '
          'games!inner(igdb_id, title, cover_url, genres)',
        )
        .eq('user_id', userId)
        .inFilter('status', const ['beaten', 'completed']);

    final entries = <GenreRadarEntry>[];

    for (final row in rows) {
      final status = row['status'] as String?;
      if (status != 'beaten' && status != 'completed') continue;

      final gameData = row['games'] as Map<String, dynamic>?;
      if (gameData == null) continue;

      final genres = Game.fromMap(gameData)
          .genres
          .where((g) => g.toLowerCase() != 'indie')
          .toList();
      if (genres.isEmpty) continue;

      final lastPlayed = row['last_played_at'] != null
          ? DateTime.tryParse(row['last_played_at'].toString())
          : null;
      final updated = row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'].toString())
          : null;
      final effectiveDate = lastPlayed ?? updated;
      if (effectiveDate == null) continue;

      entries.add(GenreRadarEntry(
        gameId: (row['game_id'] as num).toInt(),
        gameTitle: gameData['title'] as String? ?? '',
        coverUrl: Game.fromMap(gameData).coverUrl,
        genres: genres,
        hours: 0.0,
        effectiveDate: effectiveDate,
      ));
    }

    return entries;
  }
}
