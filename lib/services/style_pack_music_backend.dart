/// Platform-agnostic audio backend for style-pack background music.
abstract class StylePackMusicBackend {
  Future<void> init({required double volume});

  Future<void> playAsset(String assetPath);

  Future<void> playFile(String filePath);

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  void dispose();
}
