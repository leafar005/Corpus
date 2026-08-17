-- =============================================================================
-- Fix: borrar una reseña borraba en cascada CUALQUIER entrada de activity_feed
-- que la referenciara por review_id, incluidas las de action_type
-- 'status_change' (que solo enlazan a "la reseña más reciente en su momento").
-- Se cambia el FK a ON DELETE SET NULL (nunca borra filas por sí solo) y se
-- deja el borrado explícito de la entrada 'reviewed' en manos de
-- on_review_delete(), ahora BEFORE DELETE y usando la columna indexada
-- review_id en vez de metadata->>'review_id'.
-- =============================================================================

-- 1. Sustituir el FK: de CASCADE a SET NULL (nombre de constraint autogenerado,
--    lo buscamos dinámicamente para no depender de asumir el nombre exacto).
DO $$
DECLARE
  fk_name text;
BEGIN
  SELECT con.conname INTO fk_name
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  WHERE rel.relname = 'activity_feed'
    AND con.contype = 'f'
    AND con.conkey = (
      SELECT array_agg(attnum ORDER BY attnum)
      FROM pg_attribute
      WHERE attrelid = rel.oid AND attname = 'review_id'
    );

  IF fk_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.activity_feed DROP CONSTRAINT %I', fk_name);
  END IF;
END $$;

ALTER TABLE public.activity_feed
  ADD CONSTRAINT activity_feed_review_id_fkey
  FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE SET NULL;

-- 2. on_review_delete() pasa a BEFORE DELETE y usa la columna review_id
--    (indexada) en vez de metadata->>'review_id' (jsonb sin índice).
DROP TRIGGER IF EXISTS trg_review_delete ON public.reviews;

CREATE OR REPLACE FUNCTION public.on_review_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM public.activity_feed
    WHERE action_type = 'reviewed'
      AND review_id = OLD.id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_review_delete
  BEFORE DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.on_review_delete();
