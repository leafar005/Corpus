import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsService {
  UserSettingsService._internal();
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;

  SupabaseClient get _supabase => Supabase.instance.client;
  final Map<String, dynamic> _pending = {};
  Timer? _debounce;

  static const List<String> syncKeys = [
    'theme_mode',
    'theme_color',
    'style_pack_id',
    'mobile_grid_columns',
    'floating_mobile_nav',
    'localize_links',
    'time_source_pref',
    'home_sections_order',
    'home_sections_hidden',
    'anticipated_countdown_style',
    'wishlist_countdown_style',
    'home_bundles_ending_soon_days',
    'info_tab_order',
    'info_tab_hidden',
  ];

  static const Map<String, dynamic> defaults = {
    'theme_mode': 'system',
    'theme_color': null,
    'style_pack_id': 'default',
    'mobile_grid_columns': 3,
    'floating_mobile_nav': true,
    'localize_links': true,
    'time_source_pref': 'igdb',
    'home_sections_order': [
      'hero',
      'bundles_ending_soon',
      'stash_activity',
      'wishlist_anticipated',
      'anticipated_games',
    ],
    'home_sections_hidden': <String>[],
    'anticipated_countdown_style': 'days_only',
    'wishlist_countdown_style': 'days_only',
    'home_bundles_ending_soon_days': 3,
    'info_tab_order': [
      'franchise',
      'genres_themes',
      'platforms',
      'metacritic',
      'stash_stats',
      'summary',
      'hltb',
      'engine',
    ],
    'info_tab_hidden': <String>[],
  };

  /// Descarga los ajustes remotos y los aplica a SharedPreferences.
  Future<void> pullAndApplyToLocalCache() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('user_settings_dirty') == true) {
      final ok = await flushNow();
      if (ok) {
        await prefs.setBool('user_settings_dirty', false);
      }
      return;
    }

    try {
      final remote = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (remote == null) {
        final seed = _snapshotLocals(prefs);
        await _supabase.from('user_settings').upsert({
          'user_id': userId,
          ...seed,
        }, onConflict: 'user_id');
        return;
      }

      await _applyRemoteToLocal(remote, prefs);
    } catch (_) {
      // Ignorar fallos de red y usar caché local
    }
  }

  /// Registra un cambio local para sincronizar con debounce.
  void push(Map<String, dynamic> changedKeys) {
    try {
      if (_supabase.auth.currentUser?.id == null) return;
    } catch (_) {
      // Si Supabase no está inicializado (ej: tests), salimos en silencio.
      return;
    }

    _pending.addAll(changedKeys);
    SharedPreferences.getInstance().then(
      (p) => p.setBool('user_settings_dirty', true),
    );

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  /// Fuerza el envío inmediato de lo pendiente.
  Future<bool> flushNow() async {
    _debounce?.cancel();
    await _flush();
    return _pending.isEmpty;
  }

  /// Resetea SharedPreferences a defaults locales (logout).
  Future<void> resetLocalCacheToDefaults() async {
    _debounce?.cancel();
    _pending.clear();
    final prefs = await SharedPreferences.getInstance();

    for (final key in syncKeys) {
      await prefs.remove(key);
    }
    await prefs.setBool('user_settings_dirty', false);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _pending.clear();
      return;
    }

    final payload = Map<String, dynamic>.from(_pending);
    try {
      await _supabase.from('user_settings').upsert({
        'user_id': userId,
        ...payload,
      }, onConflict: 'user_id');

      _pending.removeWhere((k, _) => payload.containsKey(k));
      if (_pending.isEmpty) {
        final p = await SharedPreferences.getInstance();
        await p.setBool('user_settings_dirty', false);
      }
    } catch (e) {
      debugPrint('[UserSettingsService] push falló, se reintentará: $e');
    }
  }

  Map<String, dynamic> _snapshotLocals(SharedPreferences prefs) {
    final Map<String, dynamic> seed = {};
    for (final key in syncKeys) {
      final val = prefs.get(key);
      if (val != null) {
        seed[key] = val;
      } else {
        seed[key] = defaults[key];
      }
    }
    return seed;
  }

  Future<void> _applyRemoteToLocal(
    Map<String, dynamic> remote,
    SharedPreferences prefs,
  ) async {
    for (final key in syncKeys) {
      final val = remote[key];
      if (val == null) {
        await prefs.remove(key);
      } else {
        if (val is String) {
          await prefs.setString(key, val);
        } else if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is bool) {
          await prefs.setBool(key, val);
        } else if (val is double) {
          await prefs.setDouble(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, val.map((e) => e.toString()).toList());
        }
      }
    }
  }
}
