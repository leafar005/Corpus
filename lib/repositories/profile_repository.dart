import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../utils/postgrest_utils.dart';

class ProfileData {
  const ProfileData({
    required this.userProfile,
    required this.wishlistGames,
    required this.wishlistCount,
    required this.playingGames,
    required this.playingCount,
    required this.toPlayGames,
    required this.toPlayCount,
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
  final List<Map<String, dynamic>> toPlayGames;
  final int toPlayCount;
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
    List<Map<String, dynamic>>? toPlayGames,
    int? toPlayCount,
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
      toPlayGames: toPlayGames ?? this.toPlayGames,
      toPlayCount: toPlayCount ?? this.toPlayCount,
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

  /// ID del usuario autenticado, o `null` si es guest.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Stream de cambios de autenticación. El controller lo usa para
  /// recargar datos cuando el usuario inicia/cierra sesión.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<Map<String, dynamic>?> fetchUserProfile(
    String userId, {
    bool isOwnProfile = false,
  }) async {
    var profile = await _client
        .from('users')
        .select(kFullPublicProfileColumns)
        .eq('id', userId)
        .maybeSingle();

    if (profile == null && isOwnProfile) {
      final email = _client.auth.currentUser?.email ?? 'jugador';
      final defaultUsername = email.split('@')[0];
      try {
        profile = await _client
            .from('users')
            .insert({'id': userId, 'username': defaultUsername})
            .select(kFullPublicProfileColumns)
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
    final safeUserId = requireValidUuid(userId, name: 'userId');
    final userProfile = await fetchUserProfile(
      safeUserId,
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
          .select('game_id')
          .eq('user_id', userId)
          .eq('status', 'wishlist')
          .neq('is_steam_only', true)
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'playing')
          .order('updated_at', ascending: false)
          .limit(20),
      _client
          .from('user_games')
          .select('game_id')
          .eq('user_id', userId)
          .eq('status', 'playing')
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'to_play')
          .order('updated_at', ascending: false)
          .limit(20),
      _client
          .from('user_games')
          .select('game_id')
          .eq('user_id', userId)
          .eq('status', 'to_play')
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select('*, games!inner(*)')
          .eq('user_id', userId)
          .eq('status', 'beaten')
          .order('last_played_at', ascending: false, nullsFirst: false)
          .limit(20),
      _client
          .from('user_games')
          .select('game_id')
          .eq('user_id', userId)
          .eq('status', 'beaten')
          .count(CountOption.exact),
      (() async {
        final reviewsRows = List<Map<String, dynamic>>.from(
          await _client
              .from('reviews')
              .select('game_id, rating, completion_type, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: true),
        );
        final platinoGameIds = <int>{};
        for (final row in reviewsRows) {
          if (row['completion_type'] == '100_percent' &&
              row['game_id'] != null) {
            platinoGameIds.add((row['game_id'] as num).toInt());
          }
        }
        final platinumGamesRows = platinoGameIds.isEmpty
            ? <dynamic>[]
            : await _client
                  .from('user_games')
                  .select('*, games!inner(*)')
                  .eq('user_id', userId)
                  .inFilter('game_id', platinoGameIds.toList())
                  .order('last_played_at', ascending: false, nullsFirst: false)
                  .limit(20);
        return (
          reviewsRows: reviewsRows,
          platinumCount: platinoGameIds.length,
          platinumGamesRows: platinumGamesRows,
        );
      })(),
      fetchHallOfFame(userId),
      _client
          .from('friendships')
          .select('requester_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$safeUserId,addressee_id.eq.$safeUserId')
          .count(CountOption.exact),
    ]);

    final wishlistRes = results[0] as List<dynamic>;
    final wishlistCount = (results[1] as PostgrestResponse).count;
    final playingRes = results[2] as List<dynamic>;
    final playingCount = (results[3] as PostgrestResponse).count;
    final toPlayRes = results[4] as List<dynamic>;
    final toPlayCount = (results[5] as PostgrestResponse).count;
    final beatenRes = results[6] as List<dynamic>;
    final beatenCount = (results[7] as PostgrestResponse).count;
    final reviewsBundle =
        results[8]
            as ({
              List<Map<String, dynamic>> reviewsRows,
              int platinumCount,
              List<dynamic> platinumGamesRows,
            });
    final rawHallOfFame = results[9] as List<dynamic>;
    final friendsCount = (results[10] as PostgrestResponse).count;

    // Mapa de game_id → completion_type (orden ascendente = prevalece el último)
    // y ratings derivados de la misma lectura de `reviews`.
    final completionTypeMap = <int, String>{};
    final ratings = <double>[];
    for (final row in reviewsBundle.reviewsRows) {
      if (row['rating'] != null) {
        ratings.add((row['rating'] as num).toDouble());
      }
      final gameId = row['game_id'];
      final ct = row['completion_type'];
      if (gameId != null && ct != null && ct.toString().isNotEmpty) {
        completionTypeMap[(gameId as num).toInt()] = ct.toString();
      }
    }

    return ProfileData(
      userProfile: userProfile,
      wishlistGames: _enrichList(
        wishlistRes,
        completionTypeMap: completionTypeMap,
      ),
      wishlistCount: wishlistCount,
      playingGames: _enrichList(
        playingRes,
        completionTypeMap: completionTypeMap,
      ),
      playingCount: playingCount,
      toPlayGames: _enrichList(
        toPlayRes,
        completionTypeMap: completionTypeMap,
      ),
      toPlayCount: toPlayCount,
      beatenGames: _enrichList(
        beatenRes,
        useLastPlayed: true,
        completionTypeMap: completionTypeMap,
      ),
      beatenCount: beatenCount,
      platinumGames: _enrichList(
        reviewsBundle.platinumGamesRows,
        useLastPlayed: true,
        completionTypeMap: completionTypeMap,
      ),
      platinumCount: reviewsBundle.platinumCount,
      ratings: ratings,
      hallOfFame: _parseHallOfFame(rawHallOfFame),
      friendsCount: friendsCount,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> enrichList(
    List<dynamic> rawGames, {
    bool useLastPlayed = false,
  }) => _enrichList(rawGames, useLastPlayed: useLastPlayed);

  @visibleForTesting
  static List<Map<String, dynamic>?> parseHallOfFame(
    List<dynamic> rawHallOfFame,
  ) => _parseHallOfFame(rawHallOfFame);

  static List<Map<String, dynamic>> _enrichList(
    List<dynamic> rawGames, {
    bool useLastPlayed = false,
    Map<int, String> completionTypeMap = const {},
  }) {
    final result = <Map<String, dynamic>>[];
    for (final row in rawGames) {
      final gameData = _enrichGameData(
        row,
        useLastPlayed: useLastPlayed,
        completionTypeMap: completionTypeMap,
      );
      if (gameData != null) {
        result.add(gameData);
      }
    }
    return result;
  }

  static Map<String, dynamic>? _enrichGameData(
    dynamic row, {
    bool useLastPlayed = false,
    Map<int, String> completionTypeMap = const {},
  }) {
    final gameData = row['games'];
    if (gameData == null) return null;

    final enriched = Map<String, dynamic>.from(gameData as Map);
    final rating = (row['rating'] as num? ?? 0).toDouble();
    enriched['user_rating'] = rating;

    // Propagar completion_type desde el mapa global de reviews
    final gameId = (row['game_id'] as num?)?.toInt();
    if (gameId != null) {
      final ct = completionTypeMap[gameId];
      if (ct != null) enriched['completion_type'] = ct;
    }

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
      final gameData = row['games'] as Map<String, dynamic>?;
      if (gameData == null) continue;

      final game = Game.fromMap(gameData);
      final genres = List<String>.unmodifiable(
        game.genres.where((g) => g.toLowerCase() != 'indie'),
      );
      if (genres.isEmpty) continue;

      final lastPlayed = row['last_played_at'] != null
          ? DateTime.tryParse(row['last_played_at'].toString())
          : null;
      final updated = row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'].toString())
          : null;
      final effectiveDate = lastPlayed ?? updated;
      if (effectiveDate == null) continue;

      entries.add(
        GenreRadarEntry(
          gameId: (row['game_id'] as num).toInt(),
          gameTitle: gameData['title'] as String? ?? '',
          coverUrl: game.coverUrl,
          genres: genres,
          hours: (row['play_time_hours'] as num?)?.toDouble() ?? 0.0,
          effectiveDate: effectiveDate,
        ),
      );
    }

    return entries;
  }
}
