-- =============================================================================
-- Migración: Índices GIN sobre columnas JSONB en games + índice en developer
-- =============================================================================
-- Problema: check_user_achievements() y otras queries usan condiciones del tipo
--   g.genres::text ILIKE '%Role-playing%'
--   g.platforms::text ILIKE '%Nintendo%'
--   g.developer ILIKE '%FromSoftware%'
-- Estas condiciones convierten JSONB a texto y hacen LIKE, lo que impide el uso
-- de índices y obliga a un seq scan sobre la tabla games completa por cada condición.
--
-- Solución:
--   1. Índices GIN (jsonb_path_ops) para containment queries en campos JSONB.
--   2. Índice funcional btree en lower(developer) para búsquedas case-insensitive.
--   3. Índice GIN con trigrams en collection/franchises para text search.
--
-- Nota: Los índices GIN son más lentos en INSERT pero mucho más rápidos en búsqueda.
-- Para una tabla de catálogo de juegos (muchas más lecturas que escrituras) es ideal.
-- =============================================================================

-- ── Extensión pg_trgm (necesaria para índices trigram) ─────────────────────
-- Es estándar en Supabase; esta línea es idempotente.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── Índices GIN en campos JSONB ─────────────────────────────────────────────

-- genres: ['Role-playing (RPG)', 'Adventure', ...]
CREATE INDEX IF NOT EXISTS idx_games_genres_gin
  ON public.games USING gin (genres jsonb_path_ops);

-- themes: ['Action', 'Fantasy', ...]
CREATE INDEX IF NOT EXISTS idx_games_themes_gin
  ON public.games USING gin (themes jsonb_path_ops);

-- game_modes: ['Single player', 'Multiplayer', ...]
CREATE INDEX IF NOT EXISTS idx_games_game_modes_gin
  ON public.games USING gin (game_modes jsonb_path_ops);

-- player_perspectives: ['Third person', 'First person', ...]
CREATE INDEX IF NOT EXISTS idx_games_player_perspectives_gin
  ON public.games USING gin (player_perspectives jsonb_path_ops);

-- platforms: ['PC (Microsoft Windows)', 'PlayStation 5', ...]
CREATE INDEX IF NOT EXISTS idx_games_platforms_gin
  ON public.games USING gin (platforms jsonb_path_ops);

-- ── Índice funcional en developer (case-insensitive) ───────────────────────
-- Permite: WHERE lower(developer) LIKE lower('%FromSoftware%')
-- O con trigrams: WHERE developer ILIKE '%FromSoftware%' con buen rendimiento
CREATE INDEX IF NOT EXISTS idx_games_developer_lower
  ON public.games USING btree (lower(developer));

-- Índice trigram para búsquedas ILIKE sobre developer
CREATE INDEX IF NOT EXISTS idx_games_developer_trgm
  ON public.games USING gin (developer gin_trgm_ops);

-- ── Índices trigram en collection y franchises (text search en logros) ─────
-- collection es text → trigram funciona
CREATE INDEX IF NOT EXISTS idx_games_collection_trgm
  ON public.games USING gin (collection gin_trgm_ops);

-- franchises es text[] → usar GIN estándar para containment (NOT trgm)
CREATE INDEX IF NOT EXISTS idx_games_franchises_gin
  ON public.games USING gin (franchises);

-- ── Índice adicional: user_games por game_id (amigos con un juego) ──────────
-- Muy usado en fetchFriendsWithGame: WHERE game_id = X AND user_id IN (...)
CREATE INDEX IF NOT EXISTS idx_user_games_game_id
  ON public.user_games USING btree (game_id);

-- ── Índice adicional: reviews por (user_id, status) ────────────────────────
-- Usado en check_user_achievements, profiles y filtros de biblioteca
CREATE INDEX IF NOT EXISTS idx_reviews_user_status
  ON public.reviews USING btree (user_id, status);

-- ── Índice adicional: stash_community_reviews fecha ────────────────────────
-- Para paginación y ordering por fecha de creación
CREATE INDEX IF NOT EXISTS idx_stash_reviews_date
  ON public.stash_community_reviews USING btree (stash_created_at DESC);
