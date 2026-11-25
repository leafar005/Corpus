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

  String _buildSafeDefaultUsername(String userId) {
    final email = _client.auth.currentUser?.email ?? '';
    final rawPrefix = email.contains('@') ? email.split('@').first : 'jugador';
    var cleaned = rawPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.length < 3) {
      final suffix = userId.replaceAll('-', '');
      final pad = suffix.length >= 4 ? suffix.substring(0, 4) : suffix;
      cleaned = '${cleaned.isEmpty ? 'user' : cleaned}_$pad';
    }
    if (cleaned.length > 24) {
      cleaned = cleaned.substring(0, 24);
    }
    return cleaned;
  }

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
      final defaultUsername = _buildSafeDefaultUsername(userId);
      try {
        profile = await _client
            .from('users')
            .insert({'id': userId, 'username': defaultUsername})
            .select(kFullPublicProfileColumns)
            .single();
      } catch (e) {
        debugPrint('[ProfileRepository] Error creando perfil inicial: $e');
        final suffix = userId.replaceAll('-', '');
        final shortSuffix =
            suffix.length >= 4 ? suffix.substring(0, 4) : suffix;
        final maxBase = 24 - shortSuffix.length - 1;
        final base = defaultUsername.length > maxBase
            ? defaultUsername.substring(0, maxBase)
            : defaultUsername;
        final retryUsername = '${base}_$shortSuffix';
        try {
          profile = await _client
              .from('users')
              .insert({'id': userId, 'username': retryUsername})
              .select(kFullPublicProfileColumns)
              .single();
        } catch (retryErr) {
          debugPrint(
            '[ProfileRepository] No se pudo crear el perfil en reintento: $retryErr',
          );
          profile = await _client
              .from('users')
              .select(kFullPublicProfileColumns)
              .eq('id', userId)
              .maybeSingle()
              .catchError((Object _) => null);
          profile ??= <String, dynamic>{
            'id': userId,
            'username': defaultUsername,
            'xp': 0,
          };
        }
      }
    }

    return profile;
  }

  Future<List<dynamic>> fetchHallOfFame(String userId) async {
    try {
      return await _client
          .from('hall_of_fame')
          .select('user_id, game_id, pin_order, created_at, games($kGameCardColumns)')
          .eq('user_id', userId)
          .order('pin_order', ascending: true)
          .limit(5);
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

    const userGameSelect = '$kUserGameColumns, games!inner($kGameCardColumns)';

    final results = await Future.wait<dynamic>([
      fetchUserProfile(safeUserId, isOwnProfile: isOwnProfile),
      _client
          .from('user_games')
          .select(userGameSelect)
          .eq('user_id', safeUserId)
          .eq('status', 'wishlist')
          .neq('is_steam_only', true)
          .order('updated_at', ascending: false)
          .limit(20)
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select(userGameSelect)
          .eq('user_id', safeUserId)
          .eq('status', 'playing')
          .order('updated_at', ascending: false)
          .limit(20)
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select(userGameSelect)
          .eq('user_id', safeUserId)
          .eq('status', 'to_play')
          .order('updated_at', ascending: false)
          .limit(20)
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select(userGameSelect)
          .eq('user_id', safeUserId)
          .eq('status', 'beaten')
          .order('last_played_at', ascending: false, nullsFirst: false)
          .limit(20)
          .count(CountOption.exact),
      _client
          .from('user_games')
          .select('game_id, status')
          .eq('user_id', safeUserId)
          .limit(5000),
      _client
          .from('reviews')
          .select('game_id, rating, completion_type, created_at')
          .eq('user_id', safeUserId)
          .order('created_at', ascending: true)
          .limit(5000),
      fetchHallOfFame(safeUserId),
      _client
          .from('friendships')
          .select('requester_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$safeUserId,addressee_id.eq.$safeUserId')
          .count(CountOption.exact),
    ]);

    final userProfile = results[0] is Map
        ? Map<String, dynamic>.from(results[0] as Map)
        : null;
    final wishlistResp = results[1] as PostgrestResponse;
    final playingResp = results[2] as PostgrestResponse;
    final toPlayResp = results[3] as PostgrestResponse;
    final beatenResp = results[4] as PostgrestResponse;
    final allUserGamesRaw = results[5] is List ? results[5] as List : const [];
    final reviewsRows = (results[6] is List ? results[6] as List : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawHallOfFame = results[7] is List ? results[7] as List : const [];
    final friendsCount = (results[8] as PostgrestResponse).count;

    final currentStatusByGame = <int, String>{};
    for (final ug in allUserGamesRaw.whereType<Map>()) {
      final gid = (ug['game_id'] as num?)?.toInt();
      final status = ug['status']?.toString();
      if (gid != null && status != null) {
        currentStatusByGame[gid] = status;
      }
    }

    // Mapa de game_id → completion_type (orden ascendente = prevalece el último)
    // y ratings deduplicados (1 nota efectiva por juego para el histograma).
    final completionTypeMap = <int, String>{};
    final ratingByGame = <int, double>{};
    for (final row in reviewsRows) {
      final gameId = (row['game_id'] as num?)?.toInt();
      if (gameId != null) {
        final rawRating = row['rating'];
        if (rawRating is num) {
          ratingByGame[gameId] = rawRating.toDouble();
        }
        final ct = row['completion_type'];
        if (ct != null && ct.toString().isNotEmpty) {
          completionTypeMap[gameId] = ct.toString();
        }
      }
    }
    final ratings = ratingByGame.values.toList();

    // Platinos: juegos actualmente en estado 'completed', o en estado 'beaten'
    // cuya última reseña tiene completion_type == '100_percent'.
    final platinoGameIds = <int>{};
    for (final entry in currentStatusByGame.entries) {
      if (entry.value == 'completed' ||
          (entry.value == 'beaten' &&
              completionTypeMap[entry.key] == '100_percent')) {
        platinoGameIds.add(entry.key);
      }
    }

    final platinumGamesRaw = platinoGameIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('user_games')
              .select(userGameSelect)
              .eq('user_id', safeUserId)
              .inFilter('game_id', platinoGameIds.toList())
              .order('last_played_at', ascending: false, nullsFirst: false)
              .limit(20) as List<dynamic>;

    List<dynamic> dataList(PostgrestResponse resp) =>
        resp.data is List ? resp.data as List<dynamic> : const [];

    return ProfileData(
      userProfile: userProfile,
      wishlistGames: _enrichList(
        dataList(wishlistResp),
        completionTypeMap: completionTypeMap,
      ),
      wishlistCount: wishlistResp.count,
      playingGames: _enrichList(
        dataList(playingResp),
        completionTypeMap: completionTypeMap,
      ),
      playingCount: playingResp.count,
      toPlayGames: _enrichList(
        dataList(toPlayResp),
        completionTypeMap: completionTypeMap,
      ),
      toPlayCount: toPlayResp.count,
      beatenGames: _enrichList(
        dataList(beatenResp),
        useLastPlayed: true,
        completionTypeMap: completionTypeMap,
      ),
      beatenCount: beatenResp.count,
      platinumGames: _enrichList(
        platinumGamesRaw,
        useLastPlayed: true,
        completionTypeMap: completionTypeMap,
      ),
      platinumCount: platinoGameIds.length,
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
    if (row is! Map) return null;
    final gameData = row['games'];
    if (gameData is! Map) return null;

    final enriched = Map<String, dynamic>.from(gameData);
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
        if (row is! Map) continue;
        final order = (row['pin_order'] as num?)?.toInt();
        if (order == null || order < 1 || order > 5) continue;
        final gameData = row['games'];
        if (gameData is! Map) continue;
        result[order - 1] = Map<String, dynamic>.from(gameData);
      }
    } catch (e) {
      debugPrint('[ProfileRepository] Error parseando hall of fame: $e');
    }
    return result;
  }

  Future<List<GenreRadarEntry>> fetchGenreRadarEntries(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return [];

    final rows = await _client
        .from('user_games')
        .select(
          'game_id, status, play_time_hours, last_played_at, updated_at, '
          'games!inner(igdb_id, title, cover_url, genres)',
        )
        .eq('user_id', trimmedUserId)
        .inFilter('status', const ['beaten', 'completed'])
        .limit(5000);

    final entries = <GenreRadarEntry>[];

    for (final row in (rows as List).whereType<Map>()) {
      final rawGame = row['games'];
      if (rawGame is! Map) continue;

      final parsedGenres = Game.parseGenres(rawGame['genres']);
      final genres = List<String>.unmodifiable(
        parsedGenres.where((g) => g.toLowerCase() != 'indie'),
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

      final gameId = (row['game_id'] as num?)?.toInt();
      if (gameId == null) continue;

      entries.add(
        GenreRadarEntry(
          gameId: gameId,
          gameTitle: rawGame['title']?.toString() ?? '',
          coverUrl: rawGame['cover_url']?.toString(),
          genres: genres,
          hours: (row['play_time_hours'] as num?)?.toDouble() ?? 0.0,
          effectiveDate: effectiveDate,
        ),
      );
    }

    return entries;
  }
}
