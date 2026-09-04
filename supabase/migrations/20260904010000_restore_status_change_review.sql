-- =============================================================================
-- Migración: Restaurar deduplicación y review_id en status_change
-- =============================================================================
-- La migración anterior (20260904000000) eliminó accidentalmente la inyección
-- de `review_id` y la lógica de deduplicación al sobrescribir la función
-- `on_user_game_status_change`. 
-- Esto provocaba que los eventos "status_change" (wishlist, jugando)
-- no tuvieran `review_id` asociado, lo que en la UI ocultaba la barra
-- de likes y comentarios.
-- Esta migración restaura ambos comportamientos, manteniendo el fix del backdate.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    latest_review_id uuid;
    already_exists boolean;
BEGIN
    -- Solo registramos si el estado realmente cambió o es una inserción nueva
    IF (TG_OP = 'INSERT') OR (OLD.status IS DISTINCT FROM NEW.status) THEN
        
        -- Dedup: no crear entrada si ya existe una idéntica reciente (5 min)
        SELECT EXISTS (
            SELECT 1 FROM public.activity_feed
            WHERE user_id = NEW.user_id
              AND game_id = NEW.game_id
              AND action_type = 'status_change'
              AND (metadata->>'status') = NEW.status::text
              AND created_at > now() - interval '5 minutes'
        ) INTO already_exists;

        IF already_exists THEN
            RETURN NEW;
        END IF;

        -- Buscar el id de la reseña más reciente para enlazarla y así permitir
        -- likes/comentarios en este post de activity_feed.
        SELECT id INTO latest_review_id
        FROM public.reviews
        WHERE user_id = NEW.user_id AND game_id = NEW.game_id
        ORDER BY created_at DESC
        LIMIT 1;

        INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
        VALUES (
            NEW.user_id,
            'status_change',
            NEW.game_id,
            latest_review_id,
            jsonb_build_object('status', NEW.status),
            COALESCE(NEW.last_played_at, NEW.updated_at, now())
        );
    END IF;
    RETURN NEW;
END;
$$;
