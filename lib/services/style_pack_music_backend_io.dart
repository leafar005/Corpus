import 'package:audioplayers/audioplayers.dart';

import 'style_pack_music_backend.dart';

StylePackMusicBackend createStylePackMusicBackend() =>
    _AudioplayersStylePackMusicBackend();

class _AudioplayersStylePackMusicBackend implements StylePackMusicBackend {
  final AudioPlayer _player = AudioPlayer();
  double _volume = 0.35;

  @override
  Future<void> init({required double volume}) async {
    _volume = volume;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume);
  }

  @override
  Future<void> play(String assetPath) async {
    await _player.stop();
    await _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  void dispose() => _player.dispose();
}
