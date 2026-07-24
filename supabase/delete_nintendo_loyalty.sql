-- 1. Actualizar el trigger borrando el logro de las validaciones
\ir fix_achievements_and_xp.sql

-- 2. Eliminar el logro y sus referencias en cascada
DELETE FROM achievements WHERE id = 'nintendo_loyalty';
