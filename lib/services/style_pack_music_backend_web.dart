import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'style_pack_music_backend.dart';

StylePackMusicBackend createStylePackMusicBackend() =>
    _WebStylePackMusicBackend();

class _WebStylePackMusicBackend implements StylePackMusicBackend {
  web.HTMLAudioElement? _audio;
  double _volume = 0.35;
  String? _currentSrc;
  String? _pendingAsset;
  bool _unlockListenersRegistered = false;
  JSFunction? _unlockListener;

  @override
  Future<void> init({required double volume}) async {
    _volume = volume;
    _ensureAudioElement();
    _registerUnlockListeners();
  }

  void _ensureAudioElement() {
    if (_audio != null) return;

    final audio = web.HTMLAudioElement()
      ..loop = true
      ..volume = _volume
      ..preload = 'metadata'
      ..style.display = 'none';

    web.document.body?.append(audio);
    _audio = audio;
  }

  void _registerUnlockListeners() {
    if (_unlockListenersRegistered) return;
    _unlockListenersRegistered = true;

    void onUserGesture(web.Event _) {
      final asset = _pendingAsset;
      if (asset != null) {
        _pendingAsset = null;
        playAsset(asset);
      } else if (_audio != null && _audio!.paused) {
        resume();
      }
    }

    final listener = onUserGesture.toJS;
    _unlockListener = listener;
    web.document.addEventListener('pointerdown', listener);
    web.document.addEventListener('keydown', listener);
    web.document.addEventListener('touchstart', listener);
  }

  void _removeUnlockListeners() {
    final listener = _unlockListener;
    if (listener == null) return;
    web.document.removeEventListener('pointerdown', listener);
    web.document.removeEventListener('keydown', listener);
    web.document.removeEventListener('touchstart', listener);
    _unlockListener = null;
    _unlockListenersRegistered = false;
  }

  @override
  Future<void> playAsset(String assetPath) async {
    _ensureAudioElement();
    final audio = _audio!;
    final src = 'assets/$assetPath';

    if (_currentSrc != src) {
      audio.pause();
      audio.currentTime = 0;
      audio.src = src;
      audio.loop = true;
      audio.volume = _volume;
      _currentSrc = src;
    }

    try {
      await audio.play().toDart;
      _pendingAsset = null;
      _removeUnlockListeners();
    } catch (_) {
      _pendingAsset = assetPath;
      _registerUnlockListeners();
      rethrow;
    }
  }

  @override
  Future<void> playFile(String filePath) async {
    throw UnsupportedError('Reproducción local no disponible en web.');
  }

  @override
  Future<void> stop() async {
    final audio = _audio;
    if (audio != null) {
      audio.pause();
      audio.currentTime = 0;
    }
    _currentSrc = null;
    _pendingAsset = null;
  }

  @override
  Future<void> pause() async {
    _audio?.pause();
  }

  @override
  Future<void> resume() async {
    final audio = _audio;
    if (audio != null) {
      try {
        await audio.play().toDart;
        _removeUnlockListeners();
      } catch (_) {
        _registerUnlockListeners();
      }
    }
  }

  @override
  void dispose() {
    _removeUnlockListeners();
    final audio = _audio;
    if (audio != null) {
      audio.pause();
      audio.remove();
    }
    _audio = null;
    _currentSrc = null;
    _pendingAsset = null;
  }
}
