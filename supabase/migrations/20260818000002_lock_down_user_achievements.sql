-- Nuevo archivo: supabase/migrations/20260818000002_lock_down_user_achievements.sql

DROP POLICY IF EXISTS "Trigger maneja user_achievements" ON public.user_achievements;

-- Bloquea INSERT/UPDATE/DELETE directos desde clientes. Solo las funciones
-- SECURITY DEFINER (check_user_achievements) pueden escribir en esta tabla,
-- porque esas funciones se ejecutan con los privilegios del owner y por
-- tanto ignoran RLS.
CREATE POLICY "No direct user writes on user_achievements"
  ON public.user_achievements
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- La política de SELECT "Usuarios pueden ver todos los logros desbloqueados"
-- (USING (true)) ya existe y sigue vigente sin cambios — la lectura pública
-- de logros no se toca.
