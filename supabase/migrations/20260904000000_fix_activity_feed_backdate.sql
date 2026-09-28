-- =============================================================================
-- Migración: Fix backdated activity feed
-- =============================================================================
-- Soluciona el problema de las reseñas backdated apareciendo como actividad
-- reciente debido a la generación de un evento "status_change" en la tabla
-- user_games que forzaba el timestamp 'now()'.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Solo registramos si el estado realmente cambió o es una inserción nueva
    IF (TG_OP = 'INSERT') OR (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.activity_feed (user_id, action_type, game_id, metadata, created_at)
        VALUES (
            NEW.user_id,
            'status_change',
            NEW.game_id,
            jsonb_build_object('status', NEW.status),
            COALESCE(NEW.last_played_at, NEW.updated_at, now())
        );
    END IF;
    RETURN NEW;
END;
$$;
