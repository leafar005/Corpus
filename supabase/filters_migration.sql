-- ==============================================================================
-- CORPUS: MIGRACIÓN PARA CAMPOS DE FILTRADO EN JUEGOS
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de tu Dashboard de Supabase.

-- Añadir nuevas columnas a la tabla games para poder filtrar en la biblioteca
ALTER TABLE public.games 
ADD COLUMN IF NOT EXISTS themes JSONB,
ADD COLUMN IF NOT EXISTS game_modes JSONB,
ADD COLUMN IF NOT EXISTS player_perspectives JSONB,
ADD COLUMN IF NOT EXISTS platforms JSONB;
