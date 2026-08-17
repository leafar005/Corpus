-- =============================================================================
-- Fix: wishlist y playing no aparecen en el activity feed
-- =============================================================================
--
-- CAUSA RAIZ
-- ----------
-- on_review_upsert() crea entradas 'reviewed' para TODAS las reviews, incluyendo
-- las de status 'wishlist' y 'playing', que no tienen rating ni comentario real.
-- Esto es incorrecto: un juego en wishlist/playing no es una "reseña", sino un
-- cambio de estado. La entrada del feed debe ser 'status_change', no 'reviewed'.
--
-- Ademas, el trigger _mergeActivityItems en Dart fusiona/descarta pares de
-- (reviewed + status_change) del mismo juego en 24h, de modo que si se generan
-- ambas entradas simultaneamente, una se pierde segun el orden de llegada.
--
-- SOLUCION
-- --------
-- on_review_upsert() solo crea entradas 'reviewed' cuando la review tiene
-- status finalizado (beaten, abandoned, completed, on_hold) o tiene rating.
-- Para wishlist y playing, el 'status_change' que crea on_user_game_status_change
-- es suficiente y correcto.
--
-- BACKFILL
-- --------
-- Eliminar las entradas 'reviewed' huerfanas en activity_feed que corresponden
-- a reviews sin rating (wishlist/playing) y que no deben estar ahi.
-- =============================================================================

-- 1. Corregir on_review_upsert(): ignorar wishlist y playing
CREATE OR REPLACE FUNCTION public.on_review_upsert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Wishlist y playing no son reseñas: su presencia en el feed
    -- la gestiona on_user_game_status_change con action_type='status_change'.
    IF NEW.status IN ('wishlist', 'playing') THEN
        -- Si ya habia una entrada 'reviewed' de esta review (ej. el juego
        -- estaba beaten y el usuario lo puso a playing), la borramos.
        DELETE FROM public.activity_feed
        WHERE review_id = NEW.id
          AND action_type = 'reviewed';
        RETURN NEW;
    END IF;

    INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
    VALUES (
        NEW.user_id, 'reviewed', NEW.game_id, NEW.id,
        jsonb_build_object('rating', NEW.rating, 'comment', NEW.comment, 'review_id', NEW.id),
        COALESCE(NEW.created_at, now())
    )
    ON CONFLICT (review_id) WHERE action_type = 'reviewed' AND review_id IS NOT NULL
    DO UPDATE SET
        game_id    = EXCLUDED.game_id,
        metadata   = EXCLUDED.metadata,
        created_at = EXCLUDED.created_at;
    RETURN NEW;
END;
$$;

-- 2. Backfill: eliminar entradas 'reviewed' en activity_feed que pertenecen
--    a reviews de wishlist o playing (no deben estar en el feed como 'reviewed').
DELETE FROM public.activity_feed af
USING public.reviews r
WHERE af.review_id = r.id
  AND af.action_type = 'reviewed'
  AND r.status IN ('wishlist', 'playing');
