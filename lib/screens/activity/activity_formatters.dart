import 'package:flutter/material.dart';
import 'package:corpus/models/game_status.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';

/// Utilidades compartidas para formatear eventos del feed de actividad.
class ActivityFormatters {
  ActivityFormatters._();

  static String formatRelativeDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      const months = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Ahora mismo';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
      return '${date.day} ${months[date.month - 1]}. ${date.year}';
    } catch (_) {
      return '';
    }
  }

  static String actionText(
    String actionType,
    String? status, {
    required bool isOwnActivity,
  }) {
    switch (actionType) {
      case 'status_change':
        switch (status) {
          case 'playing':
            return isOwnActivity ? 'has empezado a jugar a' : 'está jugando a';
          case 'beaten':
            return isOwnActivity ? 'has completado' : 'ha completado';
          case 'completed':
            return isOwnActivity ? 'has platinado' : 'ha platinado';
          case 'wishlist':
          case 'to_play':
          case 'backlog':
            return isOwnActivity
                ? 'quieres jugar a'
                : 'quiere jugar a';
          case 'abandoned':
            return isOwnActivity ? 'has abandonado' : 'ha abandonado';
          case 'on_hold':
            return isOwnActivity ? 'has pausado' : 'ha pausado';
          default:
            return isOwnActivity ? 'has actualizado' : 'actualizó';
        }
      case 'reviewed':
        return isOwnActivity ? 'has reseñado' : 'ha reseñado';
      case 'achievement':
        return isOwnActivity
            ? 'has desbloqueado un logro en'
            : 'ha desbloqueado un logro en';
      default:
        return isOwnActivity ? 'has interactuado con' : 'hizo algo con';
    }
  }

  static CorpusIconKind actionIcon(String actionType, String? status) {
    if (actionType == 'reviewed') return CorpusIconKind.RateReviewRounded;
    if (actionType == 'achievement') return CorpusIconKind.EmojiEventsRounded;
    switch (status) {
      case 'beaten':
      case 'completed':
        return CorpusIconKind.CheckCircle;
      case 'playing':
        return CorpusIconKind.SportsEsports;
      case 'wishlist':
        return CorpusIconKind.Favorite;
      case 'to_play':
      case 'backlog':
        return CorpusIconKind.Bookmark;
      case 'abandoned':
        return CorpusIconKind.Cancel;
      case 'on_hold':
        return CorpusIconKind.PauseCircle;
      default:
        return CorpusIconKind.Flag;
    }
  }

  static Color actionColor(
    String actionType,
    String? status,
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (actionType == 'reviewed') return cs.secondary;
    if (actionType == 'achievement') return Colors.amber;
    switch (status) {
      case 'beaten':
      case 'completed':
        return Colors.green;
      case 'playing':
        return cs.primary;
      case 'to_play':
      case 'backlog':
        return Colors.green;
      case 'wishlist':
        return cs.primary;
      case 'abandoned':
        return Colors.red;
      default:
        return cs.onSurfaceVariant;
    }
  }

  static String displayName(Map<String, dynamic> userData) {
    return userData['display_name'] as String? ??
        userData['username'] as String? ??
        'Usuario';
  }

  /// Texto de acción para una publicación agrupada de varios juegos con el
  /// mismo estado.
  static String groupedActionText(
    String? status, {
    required bool isOwnActivity,
  }) {
    switch (status) {
      case 'to_play':
      case 'backlog':
        return isOwnActivity
            ? 'has añadido a "Por jugar":'
            : 'ha añadido a "Por jugar":';
      case 'wishlist':
        return isOwnActivity
            ? 'has añadido a "Wishlist":'
            : 'ha añadido a "Wishlist":';
      case 'playing':
        return isOwnActivity ? 'has empezado a jugar a:' : 'está jugando a:';
      case 'beaten':
        return isOwnActivity ? 'has completado:' : 'ha completado:';
      case 'completed':
        return isOwnActivity ? 'has platinado:' : 'ha platinado:';
      default:
        final label = GameStatus.labelForString(status);
        return isOwnActivity
            ? 'has añadido a "$label":'
            : 'ha añadido a "$label":';
    }
  }

  /// Separa los nombres de juegos de un grupo en la parte visible (máx.
  /// [maxShown] nombres) y el sufijo opcional `" y N más"`.
  static ({String shownTitles, String? moreSuffix}) splitGroupedGameTitles(
    List<String> titles, {
    int maxShown = 3,
  }) {
    if (titles.isEmpty) {
      return (shownTitles: '', moreSuffix: null);
    }
    if (titles.length == 1) {
      return (shownTitles: titles.first, moreSuffix: null);
    }
    if (titles.length <= maxShown) {
      final head = titles.sublist(0, titles.length - 1).join(', ');
      final last = titles.last;
      return (shownTitles: '$head y $last', moreSuffix: null);
    }
    final shown = titles.take(maxShown).join(', ');
    final remaining = titles.length - maxShown;
    return (shownTitles: shown, moreSuffix: ' y $remaining más');
  }

  /// Formatea como texto plano la lista de nombres de juegos de un grupo
  /// (p. ej. `"Juego A, Juego B, Juego C y 4 más"`).
  static String formatGroupedGameTitles(
    List<String> titles, {
    int maxShown = 3,
  }) {
    final parts = splitGroupedGameTitles(titles, maxShown: maxShown);
    return '${parts.shownTitles}${parts.moreSuffix ?? ''}';
  }
}
