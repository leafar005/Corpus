import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../theme/style_pack_registry.dart';
import 'style_pack_music_backend.dart';
import 'style_pack_music_backend_io.dart'
    if (dart.library.html) 'style_pack_music_backend_web.dart' as backend;

/// Plays optional background music tied to the active [StylePack].
class StylePackMusicService with WidgetsBindingObserver {
  StylePackMusicService._();
  static final StylePackMusicService instance = StylePackMusicService._();

  static const _volume = 0.35;

  final StylePackMusicBackend _player = backend.createStylePackMusicBackend();
  ThemeNotifier? _themeNotifier;
  String? _playingPackId;
  bool _pausedByLifecycle = false;
  bool _initialized = false;

  Future<void> init(ThemeNotifier themeNotifier) async {
    if (_initialized) return;
    _initialized = true;

    _themeNotifier = themeNotifier;
    await _player.init(volume: _volume);

    themeNotifier.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);

    _schedulePlaybackAttempt();
  }

  void dispose() {
    _themeNotifier?.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
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

    if (kIsWeb) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        syncWithCurrentPack(force: true);
      });
    }
  }

  /// Syncs playback with the active style pack.
  ///
  /// Call with [force] when the theme changes so playback restarts even if the
  /// pack id is unchanged. Invoked synchronously from tap handlers on web so
  /// the browser still counts it as a user gesture.
  Future<void> syncWithCurrentPack({bool force = false}) async {
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
      _playingPackId = packId;
    }
  }

  Future<void> _stop() async {
    _playingPackId = null;
    _pausedByLifecycle = false;
    await _player.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_playingPackId == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _player.resume();
          _pausedByLifecycle = false;
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!_pausedByLifecycle) {
          _player.pause();
          _pausedByLifecycle = true;
        }
    }
  }
}
