// lib/utils/postgrest_utils.dart
//
// Utilidades de seguridad para consultas PostgREST / Supabase:
// - Validación estricta de UUIDs antes de interpolar en `.or(...)`
// - Escape de comodines `%`, `_`, `\` en `.ilike(...)`
// - Lista blanca de columnas permitidas en `ORDER BY` / filtros dinámicos
// - Proyecciones públicas explícitas para evitar `select('*')` sobre `users`

import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Proyección ligera de `public.games` para tarjetas, estantería, HOF y colecciones.
const String kGameCardColumns =
    'igdb_id, title, cover_url, release_date, genres, platforms, developer, '
    'publisher, publisher_id, category, game_type, parent_game, version_parent, '
    'steam_app_id, collection, franchises';

/// Proyección completa de `public.games` para pantalla de detalle, feed y diario.
const String kGameDetailColumns =
    'igdb_id, title, cover_url, release_date, genres, steam_app_id, summary, '
    'platforms, developer, publisher, publisher_id, category, game_type, '
    'parent_game, version_parent, themes, game_modes, player_perspectives, '
    'collection, franchises, game_engines, metacritic_score, metacritic_url, '
    'metacritic_user_score, metacritic_slug, metacritic_updated_at, duracionde_time';

/// Columnas de `public.reviews` utilizadas por UI y repositorios.
const String kReviewColumns =
    'id, user_id, game_id, rating, rating_gameplay, rating_narrative, '
    'rating_soundtrack, rating_visuals, comment, status, completion_type, '
    'is_replay, replay_number, platform, play_time_hours, played_from, '
    'played_until, progress_percent, created_at, updated_at, image_urls, '
    'partner_ids';

/// Columnas de `public.user_games`.
const String kUserGameColumns =
    'user_id, game_id, status, rating, rating_gameplay, rating_narrative, '
    'rating_soundtrack, rating_visuals, comment, partner_ids, play_count, '
    'play_time_hours, last_played_at, updated_at, steam_owned, '
    'steam_playtime_minutes, steam_last_played_at, steam_imported_at, is_steam_only';

/// Columnas de `public.achievements`.
const String kAchievementColumns =
    'id, name, description, category, xp_reward, rarity, icon_name, saga_target';

/// Columnas de `public.active_bundles`.
const String kActiveBundleColumns =
    'id, title, store_name, url, end_date, tiers, updated_at';

/// Columnas de `public.notifications`.
const String kNotificationColumns =
    'id, recipient_id, actor_id, type, review_id, post_id, comment_id, '
    'metadata, read_at, created_at';

/// Columnas de `public.notification_preferences`.
const String kNotificationPrefsColumns =
    'user_id, friend_started_playing, friend_finished_game, '
    'friend_wishlisted_game, new_bundle, bundle_expiring, comment_on_review, '
    'reply_to_comment, updated_at';

/// Columnas de `public.game_groups`.
const String kGameGroupColumns =
    'id, user_id, name, description, cover_game_id, sort_order, is_ranked, created_at';

/// Columnas de `public.game_group_items`.
const String kGameGroupItemColumns =
    'id, group_id, game_id, sort_order, note, created_at';

/// Columnas de `public.activity_feed`.
const String kActivityFeedColumns =
    'id, user_id, action_type, game_id, review_id, post_id, metadata, created_at';

/// Columnas de `public.review_comments`.
const String kReviewCommentColumns =
    'id, user_id, review_id, post_id, parent_comment_id, content, image_url, '
    'attached_game, created_at';

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

/// Valida que haya una sesión autenticada en [client].
/// Si se especifica [expectedUserId], exige además que coincida con el usuario actual.
String requireAuthenticatedUserId(
  SupabaseClient client, {
  String? expectedUserId,
}) {
  final uid = client.auth.currentUser?.id.trim();
  if (uid == null || uid.isEmpty) {
    throw StateError('Operación requiere sesión autenticada activa.');
  }
  if (expectedUserId != null && expectedUserId.trim() != uid) {
    throw StateError(
      'El usuario autenticado no coincide con el propietario de la operación.',
    );
  }
  return uid;
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
