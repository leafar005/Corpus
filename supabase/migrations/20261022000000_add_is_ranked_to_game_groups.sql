-- Add is_ranked column to game_groups table
-- This allows collections to optionally show a ranking/position number per game.

ALTER TABLE public.game_groups
  ADD COLUMN IF NOT EXISTS is_ranked boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.game_groups.is_ranked IS
  'When true the collection displays a ranking position number next to each game.';
