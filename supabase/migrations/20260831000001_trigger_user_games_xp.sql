-- =============================================================================
-- Migración: Añadir trigger de gamificación a user_games
-- =============================================================================
-- Problema: La función `calculate_user_xp` suma XP por cada juego en `user_games`,
-- pero solo se recalculaba al modificar reseñas o logros, no al añadir juegos a la biblioteca.
-- Solución: Añadir trigger a `user_games` para recalcular XP al insertar, actualizar o eliminar.

CREATE OR REPLACE FUNCTION public.trigger_user_games_gamification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_uid uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_uid := OLD.user_id;
    ELSE
        target_uid := NEW.user_id;
    END IF;

    PERFORM public.calculate_user_xp(target_uid);

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_user_game_changed_gamification ON public.user_games;

CREATE TRIGGER on_user_game_changed_gamification
AFTER INSERT OR UPDATE OR DELETE ON public.user_games
FOR EACH ROW
EXECUTE FUNCTION public.trigger_user_games_gamification();
