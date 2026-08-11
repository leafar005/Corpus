// lib/repositories/profile_repository.dart
//
// Acceso a datos para el perfil de usuario.
//
// Extrae toda la lógica Supabase que estaba inline en ProfileScreen._fetchProfileData
// a un repositorio testeable y reutilizable.
//
// Uso:
// ```dart
// final repo = ProfileRepository();
// final data = await repo.fetchProfileData(userId: userId);
// ```

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado estructurado de cargar el perfil completo.
/// Evita devolver múltiples valores sueltos y facilita el testing.
class ProfileData {
  const ProfileData({
    required this.userProfile,
    required this.wishlistGames,
    required this.playingGames,
    required this.beatenGames,
    required this.reviews,
    required this.hallOfFame,
  });

  final Map<String, dynamic>? userProfile;

  /// Juegos en lista de deseos (excluye is_steam_only), ordenados por updated_at desc.
  final List<Map<String, dynamic>> wishlistGames;

  /// Juegos en progreso, ordenados por updated_at desc.
  final List<Map<String, dynamic>> playingGames;

  /// Juegos completados/terminados, ordenados por last_played_at desc.
  final List<Map<String, dynamic>> beatenGames;

  /// Reseñas del usuario con datos de juego, likes y comentarios.
  final List<Map<String, dynamic>> reviews;

  /// Hall of fame — lista fija de 5 posiciones (null si vacía).
  final List<Map<String, dynamic>?> hallOfFame;

  ProfileData copyWith({
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? wishlistGames,
    List<Map<String, dynamic>>? playingGames,
    List<Map<String, dynamic>>? beatenGames,
    List<Map<String, dynamic>>? reviews,
    List<Map<String, dynamic>?>? hallOfFame,
  }) {
    return ProfileData(
      userProfile: userProfile ?? this.userProfile,
      wishlistGames: wishlistGames ?? this.wishlistGames,
      playingGames: playingGames ?? this.playingGames,
      beatenGames: beatenGames ?? this.beatenGames,
      reviews: reviews ?? this.reviews,
      hallOfFame: hallOfFame ?? this.hallOfFame,
    );
  }
}

/// Acceso a datos para el perfil de usuario.
///
/// Centraliza todas las queries de `users`, `user_games`, `reviews` y
/// `hall_of_fame` que antes vivían inline en [ProfileScreen].
class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ──────────────────────────────────────────────────────────────────
  // Queries individuales
  // ──────────────────────────────────────────────────────────────────

  /// Obtiene el perfil del usuario desde la tabla `users`.
  /// Si el usuario es el actual y no tiene perfil, lo crea con un username
  /// derivado del email.
  ///
  /// [isOwnProfile] — true si el userId es del usuario autenticado actualmente.
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

  /// Obtiene todos los `user_games` del usuario con los datos del juego anidados.
  Future<List<dynamic>> fetchUserGames(String userId) async {
    return _client
        .from('user_games')
        .select('*, games(*)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
  }

  /// Obtiene las reseñas del usuario con datos de juego, likes y comentarios.
  Future<List<dynamic>> fetchReviews(String userId) async {
    return _client
        .from('reviews')
        .select('*, games(*), review_likes(user_id), review_comments(id)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Obtiene el Hall of Fame del usuario (hasta 5 juegos ordenados por pin_order).
  /// Devuelve una lista vacía si la tabla no existe o hay un error.
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

  // ──────────────────────────────────────────────────────────────────
  // Método de carga completa (orquesta el resto en paralelo)
  // ──────────────────────────────────────────────────────────────────

  /// Carga en paralelo todos los datos necesarios para renderizar el perfil.
  ///
  /// El perfil del usuario va primero porque puede necesitar auto-crearse.
  /// Las demás queries son independientes y se ejecutan con [Future.wait].
  ///
  /// [isOwnProfile] — true si el userId corresponde al usuario autenticado.
  Future<ProfileData> fetchProfileData(
    String userId, {
    bool isOwnProfile = false,
  }) async {
    // El perfil va primero: puede necesitar crear la fila en users
    final userProfile = await fetchUserProfile(
      userId,
      isOwnProfile: isOwnProfile,
    );

    // Las demás queries son independientes — en paralelo
    final results = await Future.wait([
      fetchUserGames(userId),
      fetchReviews(userId),
      fetchHallOfFame(userId),
    ]);

    final rawGames = results[0];
    final rawReviews = results[1];
    final rawHallOfFame = results[2];

    return ProfileData(
      userProfile: userProfile,
      wishlistGames: _extractWishlist(rawGames),
      playingGames: _extractPlaying(rawGames),
      beatenGames: _extractBeaten(rawGames),
      reviews: List<Map<String, dynamic>>.from(rawReviews),
      hallOfFame: _parseHallOfFame(rawHallOfFame),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Helpers de parseo (lógica de negocio, no de red — testeables)
  // ──────────────────────────────────────────────────────────────────

  /// Extrae los juegos de la wishlist de la respuesta de `user_games`.
  /// Excluye los juegos is_steam_only. Ordena por updated_at desc.
  static List<Map<String, dynamic>> extractWishlist(List<dynamic> rawGames) =>
      _extractWishlist(rawGames);

  static List<Map<String, dynamic>> _extractWishlist(List<dynamic> rawGames) {
    final result = <Map<String, dynamic>>[];
    for (final row in rawGames) {
      if (row['status'] != 'wishlist') continue;
      if (row['is_steam_only'] == true) continue;
      final gameData = _enrichGameData(row);
      if (gameData == null) continue;
      result.add(gameData);
    }
    result.sort(
      (a, b) => (b['_sort_date'] as String).compareTo(
        a['_sort_date'] as String,
      ),
    );
    return result;
  }

  /// Extrae los juegos en progreso. Ordena por updated_at desc.
  static List<Map<String, dynamic>> extractPlaying(List<dynamic> rawGames) =>
      _extractPlaying(rawGames);

  static List<Map<String, dynamic>> _extractPlaying(List<dynamic> rawGames) {
    final result = <Map<String, dynamic>>[];
    for (final row in rawGames) {
      if (row['status'] != 'playing') continue;
      final gameData = _enrichGameData(row);
      if (gameData == null) continue;
      result.add(gameData);
    }
    result.sort(
      (a, b) => (b['_sort_date'] as String).compareTo(
        a['_sort_date'] as String,
      ),
    );
    return result;
  }

  /// Extrae los juegos terminados. Ordena por last_played_at desc.
  static List<Map<String, dynamic>> extractBeaten(List<dynamic> rawGames) =>
      _extractBeaten(rawGames);

  static List<Map<String, dynamic>> _extractBeaten(List<dynamic> rawGames) {
    final result = <Map<String, dynamic>>[];
    for (final row in rawGames) {
      if (row['status'] != 'beaten') continue;
      final gameData = _enrichGameData(row, useLastPlayed: true);
      if (gameData == null) continue;
      result.add(gameData);
    }
    result.sort(
      (a, b) => (b['_sort_date'] as String).compareTo(
        a['_sort_date'] as String,
      ),
    );
    return result;
  }

  /// Construye un mapa `gameData` enriquecido con `user_rating` y `_sort_date`.
  static Map<String, dynamic>? _enrichGameData(
    dynamic row, {
    bool useLastPlayed = false,
  }) {
    final gameData = row['games'];
    if (gameData == null) return null;

    // Copiamos para no mutar el mapa original (viene de Supabase)
    final enriched = Map<String, dynamic>.from(gameData as Map);
    final rating = (row['rating'] ?? 0).toDouble();
    enriched['user_rating'] = rating;

    final updatedAt = row['updated_at']?.toString() ?? '';
    final lastPlayedAt = row['last_played_at']?.toString() ?? updatedAt;
    enriched['_sort_date'] = useLastPlayed ? lastPlayedAt : updatedAt;

    return enriched;
  }

  /// Convierte la lista raw de hall_of_fame en una lista fija de 5 posiciones.
  static List<Map<String, dynamic>?> parseHallOfFame(
    List<dynamic> rawHallOfFame,
  ) => _parseHallOfFame(rawHallOfFame);

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
}
