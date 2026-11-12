-- =============================================================================
-- Migration: 20261109000000_fix_security_definer_search_path.sql
-- Completa SEC-05 de la auditoría (2026-11):
-- Fija explícitamente `search_path = public, pg_temp` en todas las funciones
-- `SECURITY DEFINER` del esquema `public` (on_user_game_status_change,
-- trigger_user_games_gamification, sync_user_games_rating_from_review,
-- calculate_user_xp, check_and_unlock_achievements, etc.) sin alterar su cuerpo.
-- =============================================================================

DO $$
DECLARE
  func_record RECORD;
BEGIN
  FOR func_record IN
    SELECT p.oid::regprocedure AS func_signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %s SET search_path = public, pg_temp;',
      func_record.func_signature
    );
  END LOOP;
END $$;

