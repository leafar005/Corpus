-- =============================================================================
-- Fix: reviews.created_at (usado como "fecha de la reseña" y como timestamp
-- del activity feed) se quedaba congelado en la fecha de creación de la fila,
-- aunque el usuario terminara/abandonara el juego mucho después. Se añade
-- reviews.updated_at, gestionado por trigger solo en transiciones de estado
-- hacia 'beaten'/'abandoned', y el activity feed pasa a guiarse por esa
-- columna en vez de por created_at.
-- =============================================================================

-- 1. Nueva columna
ALTER TABLE public.reviews
  ADD COLUMN updated_at timestamp with time zone DEFAULT now() NOT NULL;

-- 2. Trigger: solo toca updated_at cuando el status entra en un estado
--    "finalizado" (beaten/abandoned) viniendo de otro distinto. Editar
--    cualquier otro campo (comentario, rating, imágenes...) sin tocar el
--    status no mueve la fecha del feed.
CREATE OR REPLACE FUNCTION public.touch_review_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status IN ('beaten', 'abandoned') THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_review_touch_updated_at
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.touch_review_updated_at();

-- 3. El activity feed pasa a usar updated_at en vez de created_at para las
--    entradas 'reviewed' (única función que cambia respecto a la versión de
--    20260814000000_fix_activity_feed_review_sync.sql: created_at -> updated_at
--    en el VALUES del INSERT).
CREATE OR REPLACE FUNCTION public.on_review_upsert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
    VALUES (
        NEW.user_id, 'reviewed', NEW.game_id, NEW.id,
        jsonb_build_object('rating', NEW.rating, 'comment', NEW.comment, 'review_id', NEW.id),
        COALESCE(NEW.updated_at, now())
    )
    ON CONFLICT (review_id) WHERE action_type = 'reviewed' AND review_id IS NOT NULL
    DO UPDATE SET
        game_id    = EXCLUDED.game_id,
        metadata   = EXCLUDED.metadata,
        created_at = EXCLUDED.created_at;
    RETURN NEW;
END;
$$;

-- 4. Backfill de reseñas ya afectadas por el bug (p. ej. la de P5 de Carlos).
--    Para la reseña más reciente de cada (user_id, game_id) ya finalizada,
--    si user_games.updated_at es posterior a reviews.created_at, asumimos que
--    ese fue el momento real en que se terminó/abandonó (así se sincronizó
--    tras el fix de last_played_at) y lo aplicamos como updated_at.
WITH latest_reviews AS (
  SELECT DISTINCT ON (user_id, game_id) id, user_id, game_id, created_at
  FROM public.reviews
  WHERE status IN ('beaten', 'abandoned')
  ORDER BY user_id, game_id, created_at DESC
)
UPDATE public.reviews r
SET updated_at = ug.updated_at
FROM latest_reviews lr
JOIN public.user_games ug
  ON ug.user_id = lr.user_id AND ug.game_id = lr.game_id
WHERE r.id = lr.id
  AND ug.updated_at > lr.created_at;
