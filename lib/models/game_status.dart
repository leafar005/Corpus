import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

// lib/models/game_status.dart
//
// Espejo en Dart del enum `public.game_status` de PostgreSQL.
// Esto garantiza que el cliente y la BD usen exactamente los mismos valores
// y que cualquier valor inválido falle en compile-time, no en runtime.

/// Estado de un juego en la biblioteca del usuario.
/// Refleja el enum `public.game_status` de Supabase.
enum GameStatus {
  wishlist,
  toPlay,
  playing,
  beaten,
  completed,
  abandoned,
  onHold;

  /// Orden en el selector de reseñas y chips de perfil.
  static const List<GameStatus> pickerOrder = [
    wishlist,
    toPlay,
    playing,
    beaten,
    completed,
    abandoned,
    onHold,
  ];

  /// Orden de secciones en el perfil (sin on_hold).
  static const List<GameStatus> profileSectionOrder = [
    playing,
    toPlay,
    beaten,
    wishlist,
    completed,
  ];

  /// Convierte el string de la BD al enum de Dart.
  /// Lanza [ArgumentError] si el valor es desconocido.
  static GameStatus fromString(String value) {
    final clean = value.toLowerCase().trim();
    switch (clean) {
      case 'wishlist':
      case 'want':
      case 'quiero':
        return GameStatus.wishlist;
      case 'to_play':
      case 'por jugar':
      case 'toplay':
        return GameStatus.toPlay;
      case 'backlog':
        return GameStatus.toPlay;
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
  static CorpusIconKind iconForString(String? statusStr) {
    return fromStringOrDefault(statusStr).icon;
  }

  /// Representación para enviar a Supabase (coincide con el valor del enum en BD).
  String get dbValue => switch (this) {
    GameStatus.wishlist => 'wishlist',
    GameStatus.toPlay => 'to_play',
    GameStatus.playing => 'playing',
    GameStatus.beaten => 'beaten',
    GameStatus.completed => 'completed',
    GameStatus.abandoned => 'abandoned',
    GameStatus.onHold => 'on_hold',
  };

  /// Indica si el estado representa un cierre de la partida (terminado o
  /// abandonado). Se usa en review_modal.dart para saber cuándo
  /// autorellenar/restaurar la fecha de una reseña al cambiar de estado.
  bool get isFinished =>
      this == GameStatus.beaten || this == GameStatus.abandoned;

  /// Etiqueta legible para mostrar en UI.
  String get label => switch (this) {
    GameStatus.wishlist => 'Wishlist',
    GameStatus.toPlay => 'Por jugar',
    GameStatus.playing => 'Jugando',
    GameStatus.beaten => 'Terminado',
    GameStatus.completed => 'Platino',
    GameStatus.abandoned => 'Abandonado',
    GameStatus.onHold => 'En pausa',
  };

  /// Etiqueta corta para botones/chips.
  String get shortLabel => switch (this) {
    GameStatus.wishlist => 'Wishlist',
    GameStatus.toPlay => 'Por jugar',
    GameStatus.playing => 'Jugando',
    GameStatus.beaten => 'Terminado',
    GameStatus.completed => 'Platino',
    GameStatus.abandoned => 'Abandonado',
    GameStatus.onHold => 'En Pausa',
  };

  /// Icono representativo para UI.
  CorpusIconKind get icon => switch (this) {
    GameStatus.wishlist => CorpusIconKind.Favorite,
    GameStatus.toPlay => CorpusIconKind.Bookmark,
    GameStatus.playing => CorpusIconKind.VideogameAsset,
    GameStatus.beaten => CorpusIconKind.CheckCircle,
    GameStatus.completed => CorpusIconKind.EmojiEvents,
    GameStatus.abandoned => CorpusIconKind.CancelOutlined,
    GameStatus.onHold => CorpusIconKind.PauseCircleOutline,
  };

  /// Color del estado contextual al tema de Flutter.
  Color color(BuildContext context) => switch (this) {
    GameStatus.wishlist => Theme.of(context).colorScheme.primary,
    GameStatus.toPlay => Colors.green,
    GameStatus.playing => Colors.blueAccent,
    GameStatus.beaten => Theme.of(context).colorScheme.secondary,
    GameStatus.completed => Colors.amber,
    GameStatus.abandoned => Theme.of(context).colorScheme.error,
    GameStatus.onHold => Colors.orange,
  };

  /// Icono emoji representativo para UI compacta.
  String get emoji => switch (this) {
    GameStatus.wishlist => '💜',
    GameStatus.toPlay => '📋',
    GameStatus.playing => '▶️',
    GameStatus.beaten => '✅',
    GameStatus.completed => '🏆',
    GameStatus.abandoned => '❌',
    GameStatus.onHold => '⏸️',
  };
}
