-- =============================================================================
-- Fix: editar una reseña no debe mover su entrada en el activity feed
-- =============================================================================
--
-- CAUSA RAÍZ
-- ----------
-- on_review_upsert() (definido en 20260817000000) usa
-- COALESCE(NEW.updated_at, now()) como created_at del feed.
-- Cuando el usuario edita la reseña (rating, comentario, imágenes, etc.),
-- el trigger se dispara y el DO UPDATE sobreescribe activity_feed.created_at
-- con el valor de reviews.updated_at, que puede ser now() o una fecha
-- reciente por el trigger touch_review_updated_at. Resultado: la entrada
-- del feed sube al top aunque la reseña sea de hace semanas.
--
-- SOLUCIÓN
-- --------
-- Usar reviews.created_at (la fecha que el usuario elige explícitamente)
-- como fuente de verdad del feed. En el DO UPDATE, sincronizar created_at
-- del feed con reviews.created_at, no con updated_at ni con now().
--
-- BACKFILL
-- --------
-- Corregir las entradas de activity_feed donde created_at del feed quedó
-- más reciente que reviews.created_at (síntoma del bug anterior).
-- =============================================================================

-- 1. Corregir el trigger on_review_upsert()
CREATE OR REPLACE FUNCTION public.on_review_upsert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
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

-- 2. Backfill: corregir entradas ya descolocadas
--    Condicion: activity_feed.created_at es mas de 1 minuto posterior a reviews.created_at
UPDATE public.activity_feed af
SET created_at = r.created_at
FROM public.reviews r
WHERE af.review_id = r.id
  AND af.action_type = 'reviewed'
  AND af.created_at > r.created_at + interval '1 minute';
