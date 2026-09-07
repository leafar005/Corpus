-- Añadir la columna game_type que se omitió en la base de datos
-- para guardar el valor moderno de IGDB de forma separada a category.
ALTER TABLE games
  ADD COLUMN IF NOT EXISTS game_type integer;

-- Recargar el esquema de PostgREST para que detecte la nueva columna
NOTIFY pgrst, 'reload schema';
