-- Migration: add duracionde_time column to games table
-- Stores scraped duration data from duracionde.com (cached 30 days)

ALTER TABLE games
  ADD COLUMN IF NOT EXISTS duracionde_time jsonb DEFAULT NULL;

COMMENT ON COLUMN games.duracionde_time IS
  'Cached duration data from duracionde.com. Structure: {found, slug, matched_title, main, main_extra, completionist, checked_at}';
