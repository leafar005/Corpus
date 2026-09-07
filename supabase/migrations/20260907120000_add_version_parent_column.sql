-- Separa version_parent de parent_game. parent_game debe usarse SOLO para
-- DLC/expansion/standalone_expansion; version_parent para remasters, remakes,
-- ports y ediciones. Antes se conflacionaban en la misma columna, causando
-- que juegos como Ninja Gaiden II Black (remaster) se clasificaran como DLC.
ALTER TABLE games
  ADD COLUMN IF NOT EXISTS version_parent integer;

COMMENT ON COLUMN games.parent_game IS
  'ID de IGDB del juego base. SOLO para DLC/expansion/standalone_expansion. No usar para remasters/remakes/ports.';
COMMENT ON COLUMN games.version_parent IS
  'ID de IGDB del juego del que este es una versión (remaster/remake/port/edición). No implica DLC.';
