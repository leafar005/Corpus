import 'package:supabase_flutter/supabase_flutter.dart';

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
/// Las 4 queries se disparan en paralelo con [Future.wait]; el tiempo total
/// de carga es el de la query más lenta en vez de la suma de todas.
class AchievementsRepository {
  AchievementsRepository();

  final _client = Supabase.instance.client;

  /// Carga todos los datos necesarios para renderizar la pantalla de logros.
  Future<AchievementsData> fetchAll(String userId) async {
    final results = await Future.wait([
      // 0: XP del usuario
      _client.from('users').select('xp').eq('id', userId).maybeSingle(),

      // 1: Logros definidos en la tabla achievements
      _client.from('achievements').select().order('xp_reward', ascending: true),

      // 2: Logros desbloqueados por el usuario
      _client
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', userId),

      // 3: Reviews del usuario (para saga progress)
      _client.from('reviews').select('*, games(*)').eq('user_id', userId),

      // 4: Estado biblioteca (para saga progress — puede solapar con reviews)
      _client.from('user_games').select('*, games(*)').eq('user_id', userId),
    ]);

    final userRow = results[0] as Map<String, dynamic>?;
    final xp = (userRow?['xp'] as num?)?.toInt() ?? 0;

    final achievements = List<Map<String, dynamic>>.from(results[1] as List);

    final unlockedRaw = List<Map<String, dynamic>>.from(results[2] as List);
    final Map<String, DateTime> unlocked = {
      for (final row in unlockedRaw)
        row['achievement_id'] as String: DateTime.parse(
          row['unlocked_at'] as String,
        ),
    };

    final reviews = List<Map<String, dynamic>>.from(results[3] as List);
    final userGames = List<Map<String, dynamic>>.from(results[4] as List);

    return AchievementsData(
      xp: xp,
      achievements: achievements,
      unlocked: unlocked,
      reviews: reviews,
      userGames: userGames,
    );
  }
}
