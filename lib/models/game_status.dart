// lib/models/game_status.dart
//
// Espejo en Dart del enum `public.game_status` de PostgreSQL.
// Esto garantiza que el cliente y la BD usen exactamente los mismos valores
// y que cualquier valor inválido falle en compile-time, no en runtime.

/// Estado de un juego en la biblioteca del usuario.
/// Refleja el enum `public.game_status` de Supabase.
enum GameStatus {
  wishlist,
  playing,
  beaten,
  completed,
  abandoned,
  paused;

  /// Convierte el string de la BD al enum de Dart.
  /// Lanza [ArgumentError] si el valor es desconocido.
  static GameStatus fromString(String value) {
    return GameStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('GameStatus desconocido: "$value"'),
    );
  }

  /// Convierte el string de la BD al enum, devolviendo [fallback] si no existe.
  static GameStatus fromStringOrDefault(
    String? value, {
    GameStatus fallback = GameStatus.wishlist,
  }) {
    if (value == null) return fallback;
    try {
      return fromString(value);
    } catch (_) {
      return fallback;
    }
  }

  /// Representación para enviar a Supabase (coincide con el valor del enum en BD).
  String get dbValue => name;

  /// Etiqueta legible para mostrar en UI.
  String get label => switch (this) {
    GameStatus.wishlist   => 'Quiero jugarlo',
    GameStatus.playing    => 'Jugando',
    GameStatus.beaten     => 'Terminado',
    GameStatus.completed  => 'Platino',
    GameStatus.abandoned  => 'Abandonado',
    GameStatus.paused     => 'En pausa',
  };

  /// Icono emoji representativo para UI compacta.
  String get emoji => switch (this) {
    GameStatus.wishlist   => '🎮',
    GameStatus.playing    => '▶️',
    GameStatus.beaten     => '✅',
    GameStatus.completed  => '🏆',
    GameStatus.abandoned  => '❌',
    GameStatus.paused     => '⏸️',
  };
}
