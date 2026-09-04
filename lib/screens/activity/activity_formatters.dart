import 'package:flutter/material.dart';
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
            return isOwnActivity
                ? 'has añadido a la wishlist'
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
}
