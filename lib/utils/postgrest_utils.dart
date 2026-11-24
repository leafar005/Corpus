// lib/utils/postgrest_utils.dart
//
// Utilidades de seguridad para consultas PostgREST / Supabase:
// - Validación estricta de UUIDs antes de interpolar en `.or(...)`
// - Escape de comodines `%`, `_`, `\` en `.ilike(...)`
// - Lista blanca de columnas permitidas en `ORDER BY` / filtros dinámicos
// - Proyecciones públicas explícitas para evitar `select('*')` sobre `users`

/// Expresión regular para UUID v1–v5 estándar (8-4-4-4-12 hex).
final RegExp kUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Columnas públicas básicas de `public.users` para joins de terceros
/// (comentarios, feed, reseñas, notificaciones).
const String kPublicUserBasicColumns = 'id, username, display_name, avatar_url';

/// Columnas públicas de perfil para `UserProfile.fromMap`.
const String kPublicUserProfileColumns =
    'id, username, display_name, avatar_url, bio, xp';

/// Columnas de perfil completo mostradas en `ProfileScreen` y `EditProfileScreen`.
/// Nota: `public.users` no tiene columna `level` (se calcula en cliente desde `xp`).
const String kFullPublicProfileColumns =
    'id, username, display_name, avatar_url, banner_url, bio, platforms, xp, '
    'currently_playing_appid, currently_playing_name';

/// Columnas permitidas para ordenar entradas del Diario (`ProfileJournalTab`).
const Set<String> kAllowedJournalOrderColumns = <String>{
  'created_at',
  'updated_at',
  'played_until',
  'played_from',
  'effective_date',
};

/// Devuelve `true` si [value] tiene formato UUID válido (tras `.trim()`).
bool isValidUuid(String? value) {
  if (value == null) return false;
  return kUuidPattern.hasMatch(value.trim());
}

/// Valida que [value] sea un UUID válido y devuelve su versión recortada.
/// Lanza [ArgumentError] si es nulo, vacío o contiene caracteres no UUID
/// (previene inyección en filtros `.or(...)` de PostgREST).
String requireValidUuid(String value, {String name = 'id'}) {
  final trimmed = value.trim();
  if (!kUuidPattern.hasMatch(trimmed)) {
    throw ArgumentError.value(value, name, 'Se esperaba un UUID válido');
  }
  return trimmed;
}

/// Escapa caracteres especiales de LIKE/ILIKE (`\`, `%`, `_`) para búsquedas
/// literales seguras en PostgreSQL / PostgREST.
String escapeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Verifica que [column] pertenezca al conjunto permitido [allowed].
String requireAllowedColumn(
  String column,
  Set<String> allowed, {
  String name = 'orderColumn',
}) {
  final trimmed = column.trim();
  if (!allowed.contains(trimmed)) {
    throw ArgumentError.value(
      column,
      name,
      'Columna de ordenación no permitida',
    );
  }
  return trimmed;
}
