/// Platform-agnostic audio backend for style-pack background music.
abstract class StylePackMusicBackend {
  Future<void> init({required double volume});

  Future<void> play(String assetPath);

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  void dispose();
}
