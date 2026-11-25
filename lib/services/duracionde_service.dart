import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para obtener tiempos de duración desde duracionde.com.
///
/// Sigue el mismo patrón que [IGDBService.getTimeToBeat]:
///   1. Caché LRU en memoria + deduplicación de peticiones concurrentes (`_inFlight`).
///   2. Lee la caché en `games.duracionde_time` (< 30 días en UTC → devuelve sin edge function).
///   3. Si no hay caché o está caducada (y existe sesión autenticada), invoca
///      la edge function `fetch-duracionde-time` y guarda en memoria.
class DuracionDeService {
  static SupabaseClient? _clientOverride;
  static SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const Duration _cacheTtl = Duration(days: 30);
  static const int _maxMemoryCacheEntries = 100;

  static final LinkedHashMap<int, Map<String, dynamic>> _memoryCache =
      LinkedHashMap<int, Map<String, dynamic>>();
  static final Map<int, Future<Map<String, dynamic>?>> _inFlight = {};

  @visibleForTesting
  static void setClientForTesting(SupabaseClient? client) {
    _clientOverride = client;
  }

  /// Limpia la caché en memoria y el registro de llamadas en curso.
  static void clearCache() {
    _memoryCache.clear();
    _inFlight.clear();
  }

  /// Obtiene los tiempos de duración para [igdbId] con título [title].
  static Future<Map<String, dynamic>?> getTimeToBeat(
    int igdbId, {
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (igdbId <= 0 || trimmedTitle.isEmpty) {
      return null;
    }

    final memCached = _memoryCache[igdbId];
    if (memCached != null && _isFresh(memCached)) {
      _memoryCache.remove(igdbId);
      _memoryCache[igdbId] = memCached;
      return Map<String, dynamic>.from(memCached);
    } else if (memCached != null) {
      _memoryCache.remove(igdbId);
    }

    final existing = _inFlight[igdbId];
    if (existing != null) {
      return existing;
    }

    final completer = Completer<Map<String, dynamic>?>();
    _inFlight[igdbId] = completer.future;

    () async {
      try {
        // 1. Intentar leer la caché directamente de Supabase
        final cached = await _readCache(igdbId);
        if (cached != null) {
          _putMemoryCache(igdbId, cached);
          completer.complete(Map<String, dynamic>.from(cached));
          return;
        }

        // 2. Evitar llamada a Edge Function sin sesión activa
        if (_client.auth.currentSession == null &&
            _client.auth.currentUser == null) {
          completer.complete(null);
          return;
        }

        // 3. Invocar la edge function
        final result = await _callEdgeFunction(igdbId, trimmedTitle);
        if (result != null) {
          _putMemoryCache(igdbId, result);
        }
        completer.complete(
          result != null ? Map<String, dynamic>.from(result) : null,
        );
      } catch (e) {
        debugPrint('[DuracionDeService] Error: $e');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      } finally {
        if (identical(_inFlight[igdbId], completer.future)) {
          _inFlight.remove(igdbId);
        }
      }
    }();

    return completer.future;
  }

  static void _putMemoryCache(int igdbId, Map<String, dynamic> value) {
    _memoryCache.remove(igdbId);
    _memoryCache[igdbId] = Map<String, dynamic>.from(value);
    while (_memoryCache.length > _maxMemoryCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  static Map<String, dynamic>? _normalizeCacheMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static bool _isFresh(Map<String, dynamic> data) {
    final checkedRaw = data['checked_at']?.toString();
    if (checkedRaw == null || checkedRaw.isEmpty) return false;
    final checkedAt = DateTime.tryParse(checkedRaw)?.toUtc();
    if (checkedAt == null) return false;

    final diff = DateTime.now().toUtc().difference(checkedAt);
    return !diff.isNegative && diff < _cacheTtl;
  }

  /// Lee duracionde_time de la tabla games y valida que no haya caducado.
  static Future<Map<String, dynamic>?> _readCache(int igdbId) async {
    try {
      final resp = await _client
          .from('games')
          .select('duracionde_time')
          .eq('igdb_id', igdbId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      final raw = _normalizeCacheMap(resp?['duracionde_time']);
      if (raw == null) return null;

      if (_isFresh(raw)) {
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
      final response = await _client.functions
          .invoke(
            'fetch-duracionde-time',
            body: {'igdb_id': igdbId, 'title': title},
          )
          .timeout(const Duration(seconds: 12));

      if (response.status >= 400 || response.data == null) return null;
      return _normalizeCacheMap(response.data);
    } catch (e) {
      debugPrint('[DuracionDeService] Error invocando edge function: $e');
      return null;
    }
  }
}
