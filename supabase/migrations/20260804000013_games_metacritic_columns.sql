-- =============================================================================
-- Migración: Añadir columnas de Metacritic a la tabla games
-- =============================================================================
-- El cliente ya lee metacritic_score, metacritic_url, metacritic_user_score de
-- widget.gameData (lectura de Supabase). La Edge Function get-metacritic-score
-- ya intenta escribir estos campos. Solo faltan las columnas en la BD.
-- =============================================================================

ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS metacritic_score       integer,
  ADD COLUMN IF NOT EXISTS metacritic_url         text,
  ADD COLUMN IF NOT EXISTS metacritic_user_score  real,
  ADD COLUMN IF NOT EXISTS metacritic_slug        text,
  ADD COLUMN IF NOT EXISTS metacritic_updated_at  timestamptz;

-- Índice para búsqueda por slug (cuando ya lo tenemos cacheado, lo usamos directo)
CREATE INDEX IF NOT EXISTS idx_games_metacritic_slug
  ON public.games (metacritic_slug)
  WHERE metacritic_slug IS NOT NULL;
