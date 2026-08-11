import 'package:flutter/material.dart';

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
  onHold;

  /// Convierte el string de la BD al enum de Dart.
  /// Lanza [ArgumentError] si el valor es desconocido.
  static GameStatus fromString(String value) {
    final clean = value.toLowerCase().trim();
    switch (clean) {
      case 'wishlist':
      case 'want':
      case 'quiero':
        return GameStatus.wishlist;
      case 'playing':
      case 'jugando':
      case 'in progress':
        return GameStatus.playing;
      case 'beaten':
      case 'finished':
      case 'terminado':
        return GameStatus.beaten;
      case 'completed':
      case 'platino':
        return GameStatus.completed;
      case 'abandoned':
      case 'dropped':
      case 'abandonado':
      case 'archived':
        return GameStatus.abandoned;
      case 'on_hold':
      case 'on hold':
      case 'paused':
      case 'pausado':
      case 'en pausa':
        return GameStatus.onHold;
      default:
        return GameStatus.values.firstWhere(
          (e) => e.dbValue == clean || e.name == clean,
          orElse: () => throw ArgumentError('GameStatus desconocido: "$value"'),
        );
    }
  }

  /// Convierte el string de la BD al enum, devolviendo [fallback] si no existe.
  static GameStatus fromStringOrDefault(
    String? value, {
    GameStatus fallback = GameStatus.wishlist,
  }) {
    if (value == null || value.trim().isEmpty) return fallback;
    try {
      return fromString(value);
    } catch (_) {
      return fallback;
    }
  }

  /// Helper estático para obtener el color desde una cadena raw de BD.
  static Color colorForString(BuildContext context, String? statusStr) {
    return fromStringOrDefault(statusStr).color(context);
  }

  /// Helper estático para obtener el texto desde una cadena raw de BD.
  static String labelForString(String? statusStr) {
    return fromStringOrDefault(statusStr).shortLabel;
  }

  /// Helper estático para obtener el icono desde una cadena raw de BD.
  static IconData iconForString(String? statusStr) {
    return fromStringOrDefault(statusStr).icon;
  }

  /// Representación para enviar a Supabase (coincide con el valor del enum en BD).
  String get dbValue => switch (this) {
    GameStatus.wishlist => 'wishlist',
    GameStatus.playing => 'playing',
    GameStatus.beaten => 'beaten',
    GameStatus.completed => 'completed',
    GameStatus.abandoned => 'abandoned',
    GameStatus.onHold => 'on_hold',
  };

  /// Etiqueta legible para mostrar en UI.
  String get label => switch (this) {
    GameStatus.wishlist => 'Quiero jugarlo',
    GameStatus.playing => 'Jugando',
    GameStatus.beaten => 'Terminado',
    GameStatus.completed => 'Platino',
    GameStatus.abandoned => 'Abandonado',
    GameStatus.onHold => 'En pausa',
  };

  /// Etiqueta corta para botones/chips.
  String get shortLabel => switch (this) {
    GameStatus.wishlist => 'Quiero',
    GameStatus.playing => 'Jugando',
    GameStatus.beaten => 'Terminado',
    GameStatus.completed => 'Platino',
    GameStatus.abandoned => 'Abandonado',
    GameStatus.onHold => 'En Pausa',
  };

  /// Icono representativo para UI.
  IconData get icon => switch (this) {
    GameStatus.wishlist => Icons.favorite,
    GameStatus.playing => Icons.videogame_asset,
    GameStatus.beaten => Icons.check_circle,
    GameStatus.completed => Icons.emoji_events,
    GameStatus.abandoned => Icons.cancel_outlined,
    GameStatus.onHold => Icons.pause_circle_outline,
  };

  /// Color del estado contextual al tema de Flutter.
  Color color(BuildContext context) => switch (this) {
    GameStatus.wishlist => Theme.of(context).colorScheme.primary,
    GameStatus.playing => Colors.blueAccent,
    GameStatus.beaten => Theme.of(context).colorScheme.secondary,
    GameStatus.completed => Colors.amber,
    GameStatus.abandoned => Theme.of(context).colorScheme.error,
    GameStatus.onHold => Colors.orange,
  };

  /// Icono emoji representativo para UI compacta.
  String get emoji => switch (this) {
    GameStatus.wishlist => '🎮',
    GameStatus.playing => '▶️',
    GameStatus.beaten => '✅',
    GameStatus.completed => '🏆',
    GameStatus.abandoned => '❌',
    GameStatus.onHold => '⏸️',
  };
}
