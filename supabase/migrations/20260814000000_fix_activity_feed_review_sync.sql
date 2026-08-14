-- =============================================================================
-- Fix: activity_feed no se sincroniza con ediciones de reviews
-- =============================================================================

-- 1. Columna real para review_id (antes solo vivía dentro de metadata jsonb)
ALTER TABLE public.activity_feed
  ADD COLUMN review_id uuid REFERENCES public.reviews(id) ON DELETE CASCADE;

UPDATE public.activity_feed
SET review_id = (metadata->>'review_id')::uuid
WHERE action_type = 'reviewed'
  AND metadata->>'review_id' IS NOT NULL;

-- Limpieza defensiva por si ya hay duplicados 'reviewed' del mismo review_id
DELETE FROM public.activity_feed a
USING public.activity_feed b
WHERE a.action_type = 'reviewed'
  AND b.action_type = 'reviewed'
  AND a.review_id = b.review_id
  AND a.review_id IS NOT NULL
  AND (a.created_at, a.id) < (b.created_at, b.id);

CREATE UNIQUE INDEX activity_feed_review_id_uq
  ON public.activity_feed (review_id)
  WHERE action_type = 'reviewed' AND review_id IS NOT NULL;

CREATE INDEX activity_feed_review_id_idx ON public.activity_feed (review_id);

-- 2. on_review_upsert ahora hace upsert (INSERT o UPDATE de reviews mueven/actualizan
--    la misma fila de activity_feed en vez de dejarla congelada o duplicarla)
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

DROP TRIGGER IF EXISTS trg_review_upsert ON public.reviews;
CREATE TRIGGER trg_review_upsert
  AFTER INSERT OR UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.on_review_upsert();

-- 3. on_user_game_status_change ahora intenta enlazar la reseña más reciente
--    de ese user+game, para que los posts de "status_change" dejen de quedar huérfanos
CREATE OR REPLACE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    latest_review_id uuid;
BEGIN
    IF (TG_OP = 'INSERT') OR (OLD.status IS DISTINCT FROM NEW.status) THEN
        SELECT id INTO latest_review_id
        FROM public.reviews
        WHERE user_id = NEW.user_id AND game_id = NEW.game_id
        ORDER BY created_at DESC
        LIMIT 1;

        INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
        VALUES (
            NEW.user_id, 'status_change', NEW.game_id, latest_review_id,
            jsonb_build_object('status', NEW.status),
            COALESCE(NEW.updated_at, now())
        );
    END IF;
    RETURN NEW;
END;
$$;

-- 4. Completar el enum que falta (Platino existe en Dart pero no en la BD)
ALTER TYPE public.game_status ADD VALUE IF NOT EXISTS 'completed';
