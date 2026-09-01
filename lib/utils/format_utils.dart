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

const _monthsMinimal = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
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

/// Formato mínimo: "5 ago 2026" (sin punto).
String formatDateMinimal(String? isoString) {
  if (isoString == null) return '';
  try {
    final date = DateTime.parse(isoString).toLocal();
    return '${date.day} ${_monthsMinimal[date.month - 1]} ${date.year}';
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
    final fs = '${f.day} ${_monthsMinimal[f.month - 1]}';
    if (until == null) return '$fs ${f.year}';
    final u = DateTime.parse(until);
    final us = '${u.day} ${_monthsMinimal[u.month - 1]} ${u.year}';
    return f.year == u.year ? '$fs - $us' : '$fs ${f.year} - $us';
  } catch (_) {
    return '';
  }
}
