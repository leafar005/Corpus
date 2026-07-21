-- ==============================================================================
-- CORPUS: MIGRACIÓN PARA CAMPOS AVANZADOS DE PERFIL
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de tu Dashboard de Supabase.

-- Añadir nuevas columnas a la tabla users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS display_name TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS platforms JSONB DEFAULT '[]'::jsonb;
