import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/postgrest_utils.dart';

/// Datos cargados en paralelo para la pantalla de logros.
class AchievementsData {
  const AchievementsData({
    required this.xp,
    required this.achievements,
    required this.unlocked,
    required this.reviews,
    required this.userGames,
  });

  /// XP actual del usuario (de la tabla `users`).
  final int xp;

  /// Lista completa de logros ordenada por `xp_reward`.
  final List<Map<String, dynamic>> achievements;

  /// Map { achievement_id → unlocked_at } con todos los logros desbloqueados.
  final Map<String, DateTime> unlocked;

  /// Reviews del usuario (con juego). Se usan para calcular saga progress.
  final List<Map<String, dynamic>> reviews;

  /// Entradas de `user_games` del usuario (con juego).
  final List<Map<String, dynamic>> userGames;
}

/// Repositorio para [AchievementsScreen].
///
/// Las queries se disparan en paralelo con [Future.wait]; el tiempo total
/// de carga es el de la query más lenta en vez de la suma de todas.
class AchievementsRepository {
  AchievementsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Carga todos los datos necesarios para renderizar la pantalla de logros.
  Future<AchievementsData> fetchAll(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      final achievementsRows = await _client
          .from('achievements')
          .select(kAchievementColumns)
          .order('xp_reward', ascending: true)
          .limit(500);
      return AchievementsData(
        xp: 0,
        achievements: List<Map<String, dynamic>>.from(
          (achievementsRows as List).whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ),
        ),
        unlocked: const {},
        reviews: const [],
        userGames: const [],
      );
    }

    final results = await Future.wait([
      // 0: XP del usuario
      _client
          .from('users')
          .select('xp')
          .eq('id', trimmedUserId)
          .maybeSingle(),

      // 1: Logros definidos en la tabla achievements
      _client
          .from('achievements')
          .select(kAchievementColumns)
          .order('xp_reward', ascending: true)
          .limit(500),

      // 2: Logros desbloqueados por el usuario
      _client
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', trimmedUserId)
          .limit(500),

      // 3: Reviews del usuario (para saga progress)
      _client
          .from('reviews')
          .select('id, game_id, status, completion_type, platform, created_at, games($kGameCardColumns)')
          .eq('user_id', trimmedUserId)
          .limit(5000),

      // 4: Estado biblioteca (para saga progress — puede solapar con reviews)
      _client
          .from('user_games')
          .select('game_id, status, games($kGameCardColumns)')
          .eq('user_id', trimmedUserId)
          .limit(5000),
    ]);

    final rawUser = results[0];
    final userRow = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    final rawXp = userRow?['xp'];
    final xp = rawXp is num
        ? rawXp.toInt()
        : int.tryParse(rawXp?.toString() ?? '') ?? 0;

    final achievements = (results[1] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final unlockedRaw = (results[2] as List).whereType<Map>();
    final Map<String, DateTime> unlocked = {};
    for (final row in unlockedRaw) {
      final id = row['achievement_id']?.toString();
      final rawDate = row['unlocked_at']?.toString();
      final parsedDate = rawDate != null ? DateTime.tryParse(rawDate) : null;
      if (id != null && id.isNotEmpty && parsedDate != null) {
        unlocked[id] = parsedDate;
      } else if (id != null && kDebugMode) {
        debugPrint(
          '[AchievementsRepository] unlocked_at inválido para $id: $rawDate',
        );
      }
    }

    final reviews = (results[3] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final userGames = (results[4] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return AchievementsData(
      xp: xp,
      achievements: achievements,
      unlocked: unlocked,
      reviews: reviews,
      userGames: userGames,
    );
  }
}
