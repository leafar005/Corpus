-- =============================================================================
-- Migración: Normalizar reviews.status al tipo enum game_status
-- =============================================================================
-- Problema: reviews.status es text DEFAULT 'beaten' sin constraint de valores,
--   mientras que user_games.status usa el enum public.game_status correctamente.
--   Esto permite insertar valores inválidos ('Beaten', 'done', '', etc.).
--
-- Plan:
--   1. Limpiar datos con valores fuera del enum (si los hay) → mapearlos a 'beaten'
--   2. Cambiar el tipo de la columna a public.game_status
-- =============================================================================

-- ── 1. Limpiar valores no válidos antes de la conversión ───────────────────
UPDATE public.reviews
SET status = 'beaten'
WHERE status NOT IN ('playing', 'beaten', 'wishlist', 'abandoned', 'on_hold');

-- ── 2. Eliminar el DEFAULT text antes de cambiar el tipo ──────────────────
-- PostgreSQL no puede castear automáticamente el DEFAULT 'beaten'::text al enum.
ALTER TABLE public.reviews
  ALTER COLUMN status DROP DEFAULT;

-- ── 3. Cambiar el tipo de la columna ──────────────────────────────────────
ALTER TABLE public.reviews
  ALTER COLUMN status TYPE public.game_status
  USING status::public.game_status;

-- ── 4. Restaurar el DEFAULT con el tipo correcto ──────────────────────────
ALTER TABLE public.reviews
  ALTER COLUMN status SET DEFAULT 'beaten'::public.game_status;
