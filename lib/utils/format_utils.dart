/// Formatea una nota numérica eliminando el .0 cuando el número es entero.
/// Ejemplos: 9.0 → "9", 7.5 → "7.5", 10.0 → "10"
String formatRating(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

// ── Nombres de mes ────────────────────────────────────────────────────────────

const _monthsLong = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const _monthsShort = [
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

// ── Funciones públicas ────────────────────────────────────────────────────────

/// Formato largo: "5 de Agosto de 2026".
/// Acepta [null] o cadenas malformadas y devuelve `''` en esos casos.
String formatDateLong(String? isoString) {
  if (isoString == null) return '';
  try {
    final date = DateTime.parse(isoString).toLocal();
    return '${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';
  } catch (_) {
    return '';
  }
}

/// Formato corto: "5 Ago. 2026".
/// Pensado para columnas o fichas con espacio horizontal limitado.
String formatDateShort(String? isoString) {
  if (isoString == null) return '';
  try {
    final date = DateTime.parse(isoString).toLocal();
    return '${date.day} ${_monthsShort[date.month - 1]}. ${date.year}';
  } catch (_) {
    return '';
  }
}

/// Formato relativo: "hace 5 minutos", "hace 2 horas", etc.
/// Si ha pasado un mes (30 días) o más, devuelve la fecha.
String formatDateRelative(String? isoString) {
  if (isoString == null) return '';
  try {
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    // En lugar de inDays (que trunca a bloques exactos de 24h),
    // calculamos los días redondeando para evitar que un comentario de hace
    // 14 días menos 1 hora se calcule como 13 días (y por tanto 1 semana).
    final int days = (difference.inHours / 24).round();

    if (days >= 30) {
      return formatDateShort(isoString);
    } else if (days >= 7) {
      final int weeks = days ~/ 7;
      return weeks == 1 ? 'hace 1 semana' : 'hace $weeks semanas';
    } else if (days >= 1) {
      return days == 1 ? 'hace 1 día' : 'hace $days días';
    } else if (difference.inHours >= 1) {
      return difference.inHours == 1 ? 'hace 1 hora' : 'hace ${difference.inHours} horas';
    } else if (difference.inMinutes >= 1) {
      return difference.inMinutes == 1 ? 'hace 1 minuto' : 'hace ${difference.inMinutes} minutos';
    } else {
      return 'hace un momento';
    }
  } catch (_) {
    return '';
  }
}

/// Rango de fechas minimal: "5 ene - 20 feb 2026" (mismo año)
/// o "5 ene 2025 - 20 feb 2026" (años distintos).
/// Si [until] es null devuelve sólo la fecha de inicio.
String formatDateRange(String? from, String? until) {
  if (from == null) return '';
  try {
    final f = DateTime.parse(from);
    final fs = '${f.day} ${_monthsShort[f.month - 1]}';
    if (until == null) return '$fs ${f.year}';
    final u = DateTime.parse(until);
    final us = '${u.day} ${_monthsShort[u.month - 1]} ${u.year}';
    return f.year == u.year ? '$fs - $us' : '$fs ${f.year} - $us';
  } catch (_) {
    return '';
  }
}
