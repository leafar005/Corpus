import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para obtener tiempos de duración desde duracionde.com.
///
/// Sigue el mismo patrón que [IGDBService.getTimeToBeat]:
///   1. Lee la caché en games.duracionde_time (< 30 días → devuelve sin red).
///   2. Si no hay caché o está caducada, invoca la edge function
///      `fetch-duracionde-time` y devuelve su resultado.
///
/// Devuelve `null` solo si ocurre un error inesperado; devuelve
/// `{'found': false, ...}` cuando el juego no está en duracionde.com.
class DuracionDeService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const _cacheDays = 30;

  /// Obtiene los tiempos de duración para [igdbId] con título [title].
  static Future<Map<String, dynamic>?> getTimeToBeat(
    int igdbId, {
    required String title,
  }) async {
    try {
      // 1. Intentar leer la caché directamente de Supabase
      final cached = await _readCache(igdbId);
      if (cached != null) return cached;

      // 2. Invocar la edge function
      final result = await _callEdgeFunction(igdbId, title);
      return result;
    } catch (e) {
      debugPrint('[DuracionDeService] Error: $e');
      return null;
    }
  }

  /// Lee duracionde_time de la tabla games y valida que no haya caducado.
  static Future<Map<String, dynamic>?> _readCache(int igdbId) async {
    try {
      final resp = await _client
          .from('games')
          .select('duracionde_time')
          .eq('igdb_id', igdbId)
          .maybeSingle();

      final raw = resp?['duracionde_time'] as Map<String, dynamic>?;
      if (raw == null || raw['checked_at'] == null) return null;

      final checkedAt = DateTime.tryParse(raw['checked_at'] as String);
      if (checkedAt == null) return null;

      final diffDays = DateTime.now().difference(checkedAt).inDays;
      if (diffDays < _cacheDays) {
        debugPrint('[DuracionDeService] Cache hit (${diffDays}d old)');
        return raw;
      }
    } catch (e) {
      debugPrint('[DuracionDeService] Error leyendo caché: $e');
    }
    return null;
  }

  /// Invoca la edge function fetch-duracionde-time.
  static Future<Map<String, dynamic>?> _callEdgeFunction(
    int igdbId,
    String title,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'fetch-duracionde-time',
        body: {'igdb_id': igdbId, 'title': title},
      );

      if (response.data == null) return null;
      final data = response.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[DuracionDeService] Error invocando edge function: $e');
      return null;
    }
  }
}
