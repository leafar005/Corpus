import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../theme/style_pack_registry.dart';
import 'style_pack_music_backend.dart';
import 'style_pack_music_backend_io.dart'
    if (dart.library.js_interop) 'style_pack_music_backend_web.dart'
    as backend;

/// Plays optional background music tied to the active [StylePack].
class StylePackMusicService with WidgetsBindingObserver {
  StylePackMusicService._();
  static final StylePackMusicService instance = StylePackMusicService._();

  static const _volume = 0.35;

  StylePackMusicBackend _player = backend.createStylePackMusicBackend();
  ThemeNotifier? _themeNotifier;
  String? _playingPackId;
  bool _pausedByLifecycle = false;
  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _syncFuture;
  bool _pendingSync = false;
  bool _pendingForce = false;

  Future<void> init(ThemeNotifier themeNotifier) async {
    if (_initialized) return;
    if (_disposed) {
      _player = backend.createStylePackMusicBackend();
      _disposed = false;
    }
    _initialized = true;

    _themeNotifier = themeNotifier;
    await _player.init(volume: _volume);

    themeNotifier.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);

    _schedulePlaybackAttempt();
  }

  void dispose() {
    _disposed = true;
    _themeNotifier?.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _playingPackId = null;
    _pausedByLifecycle = false;
    _pendingSync = false;
    _pendingForce = false;
    _player.dispose();
    _initialized = false;
  }

  void _onThemeChanged() {
    syncWithCurrentPack(force: true);
  }

  void _schedulePlaybackAttempt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncWithCurrentPack(force: true);
    });
  }

  /// Syncs playback with the active style pack.
  ///
  /// Call with [force] when the theme changes so playback restarts even if the
  /// pack id is unchanged. Invoked synchronously from tap handlers on web so
  /// the browser still counts it as a user gesture.
  Future<void> syncWithCurrentPack({bool force = false}) {
    if (_syncFuture != null) {
      _pendingSync = true;
      _pendingForce = _pendingForce || force;
      return _syncFuture!;
    }

    final future = _runSerializedSync(initialForce: force);
    _syncFuture = future;
    return future;
  }

  Future<void> _runSerializedSync({required bool initialForce}) async {
    var currentForce = initialForce;
    try {
      while (!_disposed) {
        _pendingSync = false;
        _pendingForce = false;
        await _performSync(force: currentForce);
        if (!_pendingSync || _disposed) break;
        currentForce = _pendingForce;
      }
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _performSync({required bool force}) async {
    final packId = _themeNotifier?.stylePackId;
    if (packId == null) {
      await _stop();
      return;
    }

    final musicFile = StylePackRegistry.resolveMusicFilePath(packId);
    if (musicFile == null) {
      await _stop();
      return;
    }

    if (!force && _playingPackId == packId) return;

    try {
      if (kIsWeb) {
        await _player.playAsset(musicFile);
      } else {
        final file = File(musicFile);
        if (!file.existsSync()) {
          debugPrint('[StylePackMusic] Archivo no encontrado: $musicFile');
          _playingPackId = null;
          return;
        }
        await _player.playFile(musicFile);
      }
      _playingPackId = packId;
      _pausedByLifecycle = false;
    } catch (e, st) {
      debugPrint('[StylePackMusic] No se pudo reproducir $musicFile: $e\n$st');
      _playingPackId = null;
    }
  }

  Future<void> _stop() async {
    _playingPackId = null;
    _pausedByLifecycle = false;
    await _player.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_playingPackId == null || _disposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          unawaited(_player.resume().catchError((Object _) {}));
          _pausedByLifecycle = false;
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!_pausedByLifecycle) {
          unawaited(_player.pause().catchError((Object _) {}));
          _pausedByLifecycle = true;
        }
    }
  }
}
