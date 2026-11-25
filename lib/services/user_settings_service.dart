import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsService {
  UserSettingsService._internal();
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;

  static const String _dirtyKey = 'user_settings_dirty';
  static const String _pendingJsonKey = 'user_settings_pending_json';

  SupabaseClient? _testClient;
  SupabaseClient get _supabase => _testClient ?? Supabase.instance.client;

  final Map<String, dynamic> _pending = {};
  Timer? _debounce;
  Future<void>? _dirtyFlagWrite;
  Future<void>? _activeFlush;
  bool _flushAgain = false;

  @visibleForTesting
  void setClientForTesting(SupabaseClient? client) {
    _testClient = client;
  }

  @visibleForTesting
  void resetForTesting() {
    _debounce?.cancel();
    _debounce = null;
    _pending.clear();
    _dirtyFlagWrite = null;
    _activeFlush = null;
    _flushAgain = false;
    _testClient = null;
  }

  @visibleForTesting
  Map<String, dynamic> get pendingSnapshotForTesting =>
      Map<String, dynamic>.from(_pending);

  static const String defaultThemeMode = 'system';
  static const String? defaultThemeColor = null;
  static const String defaultStylePackId = 'default';
  static const int defaultMobileGridColumns = 3;
  static const bool defaultFloatingMobileNav = true;
  static const bool defaultLocalizeLinks = true;
  static const String defaultTimeSourcePref = 'igdb';
  static const String defaultAnticipatedCountdownStyle = 'days_only';
  static const String defaultWishlistCountdownStyle = 'days_only';
  static const int defaultHomeBundlesEndingSoonDays = 3;
  static const List<String> defaultHomeSectionsOrder = [
    'hero',
    'bundles_ending_soon',
    'stash_activity',
    'wishlist_anticipated',
    'anticipated_games',
  ];
  static const List<String> defaultInfoTabOrder = [
    'franchise',
    'genres_themes',
    'platforms',
    'metacritic',
    'stash_stats',
    'summary',
    'hltb',
    'engine',
  ];

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

  static const Set<String> syncKeySet = {
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
  };

  static const Map<String, dynamic> defaults = {
    'theme_mode': defaultThemeMode,
    'theme_color': defaultThemeColor,
    'style_pack_id': defaultStylePackId,
    'mobile_grid_columns': defaultMobileGridColumns,
    'floating_mobile_nav': defaultFloatingMobileNav,
    'localize_links': defaultLocalizeLinks,
    'time_source_pref': defaultTimeSourcePref,
    'home_sections_order': defaultHomeSectionsOrder,
    'home_sections_hidden': <String>[],
    'anticipated_countdown_style': defaultAnticipatedCountdownStyle,
    'wishlist_countdown_style': defaultWishlistCountdownStyle,
    'home_bundles_ending_soon_days': defaultHomeBundlesEndingSoonDays,
    'info_tab_order': defaultInfoTabOrder,
    'info_tab_hidden': <String>[],
  };

  /// Descarga los ajustes remotos y los aplica a SharedPreferences.
  /// Si hay cambios locales offline pendientes (`user_settings_dirty == true`),
  /// los sube primero antes de conciliar con el estado remoto.
  Future<void> pullAndApplyToLocalCache() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (_dirtyFlagWrite != null) {
      await _dirtyFlagWrite;
    }

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_dirtyKey) == true) {
      if (_pending.isEmpty) {
        final rawPending = prefs.getString(_pendingJsonKey);
        if (rawPending != null && rawPending.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPending);
            if (decoded is Map) {
              for (final entry in decoded.entries) {
                final k = entry.key.toString();
                if (syncKeys.contains(k)) {
                  _pending[k] = entry.value;
                }
              }
            }
          } catch (_) {}
        }
        if (_pending.isEmpty) {
          _pending.addAll(_snapshotLocals(prefs));
        }
      }

      final ok = await flushNow();
      if (!ok) {
        return;
      }
      await prefs.setBool(_dirtyKey, false);
      await prefs.remove(_pendingJsonKey);
    }

    try {
      final remote = await _supabase
          .from('user_settings')
          .select(syncKeys.join(', '))
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (remote == null) {
        final seed = _snapshotLocals(prefs);
        await _supabase
            .from('user_settings')
            .upsert({'user_id': userId, ...seed}, onConflict: 'user_id')
            .timeout(const Duration(seconds: 6));
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

    var addedValid = false;
    for (final entry in changedKeys.entries) {
      if (!syncKeySet.contains(entry.key)) {
        assert(false, 'Clave desconocida en UserSettingsService.push: ${entry.key}');
        continue;
      }
      _pending[entry.key] = entry.value is List
          ? List<dynamic>.from(entry.value as List)
          : entry.value;
      addedValid = true;
    }
    if (!addedValid) return;

    final pendingSnapshot = _cloneMap(_pending);
    _dirtyFlagWrite = (_dirtyFlagWrite ?? Future<void>.value())
        .catchError((_) {})
        .then((_) async {
          final p = await SharedPreferences.getInstance();
          await p.setBool(_dirtyKey, true);
          await p.setString(_pendingJsonKey, jsonEncode(pendingSnapshot));
        });

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_flush());
    });
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
    if (_activeFlush != null) {
      await _activeFlush!.catchError((_) {});
    }
    if (_dirtyFlagWrite != null) {
      await _dirtyFlagWrite!.catchError((_) {});
      _dirtyFlagWrite = null;
    }
    _pending.clear();
    _flushAgain = false;

    final prefs = await SharedPreferences.getInstance();
    for (final key in syncKeys) {
      await prefs.remove(key);
    }
    await prefs.remove(_pendingJsonKey);
    await prefs.setBool(_dirtyKey, false);
  }

  Future<void> _flush() async {
    if (_activeFlush != null) {
      _flushAgain = true;
      return _activeFlush!;
    }

    final completer = Completer<void>();
    _activeFlush = completer.future;
    try {
      do {
        _flushAgain = false;
        if (_pending.isEmpty) break;

        if (_dirtyFlagWrite != null) {
          try {
            await _dirtyFlagWrite;
          } catch (_) {}
          _dirtyFlagWrite = null;
        }

        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) {
          // No descartar _pending si userId es null transitoriamente; solo
          // resetLocalCacheToDefaults limpia cambios en logout explícito.
          break;
        }

        final payload = _cloneMap(_pending);
        try {
          await _supabase
              .from('user_settings')
              .upsert({'user_id': userId, ...payload}, onConflict: 'user_id')
              .timeout(const Duration(seconds: 6));

          // Solo eliminar claves cuyo valor actual siga coincidiendo con el enviado.
          _pending.removeWhere(
            (k, v) => payload.containsKey(k) && _valuesEqual(v, payload[k]),
          );

          final p = await SharedPreferences.getInstance();
          if (_pending.isEmpty) {
            await p.setBool(_dirtyKey, false);
            await p.remove(_pendingJsonKey);
          } else {
            await p.setBool(_dirtyKey, true);
            await p.setString(_pendingJsonKey, jsonEncode(_cloneMap(_pending)));
            _flushAgain = true;
          }
        } catch (e) {
          debugPrint('[UserSettingsService] push falló, se reintentará: $e');
          break;
        }
      } while (_flushAgain && _pending.isNotEmpty);
    } finally {
      _activeFlush = null;
      completer.complete();
    }
  }

  static Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    final copy = <String, dynamic>{};
    for (final entry in source.entries) {
      copy[entry.key] = entry.value is List
          ? List<dynamic>.from(entry.value as List)
          : entry.value;
    }
    return copy;
  }

  static bool _valuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      return listEquals(
        a.map((e) => e?.toString()).toList(),
        b.map((e) => e?.toString()).toList(),
      );
    }
    return a == b;
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
