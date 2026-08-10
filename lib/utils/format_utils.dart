/// Formatea una nota numérica eliminando el .0 cuando el número es entero.
/// Ejemplos: 9.0 → "9", 7.5 → "7.5", 10.0 → "10"
String formatRating(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
