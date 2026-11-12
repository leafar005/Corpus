-- =============================================================================
-- Migration 4: Separar trigger `fill_interaction_refs` / `fill_comment_refs`
-- =============================================================================
-- Corrige el error PostgreSQL 42703:
--   `record "new" has no field "parent_comment_id"`
-- Al compartir una misma función trigger entre `review_likes` y
-- `review_comments`, PL/pgSQL valida los campos de `NEW` en la expresión
-- completa antes de evaluar `TG_TABLE_NAME = 'review_comments'`, fallando al
-- insertar un like porque `review_likes` no tiene columna `parent_comment_id`.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.resolve_interaction_refs(
  p_post_id        uuid,
  p_review_id      uuid,
  p_parent_post_id uuid DEFAULT NULL
)
RETURNS TABLE (post_id uuid, review_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_post_id   uuid := p_post_id;
  v_review_id uuid := p_review_id;
BEGIN
  IF v_post_id IS NULL THEN
    v_post_id := coalesce(p_parent_post_id, public.ensure_review_post(v_review_id));
    IF v_post_id IS NULL THEN
      RAISE EXCEPTION 'post_id o review_id obligatorio';
    END IF;
  ELSE
    v_review_id := NULL;
    SELECT CASE WHEN count(DISTINCT af.review_id) = 1 THEN min(af.review_id::text)::uuid END
      INTO v_review_id
      FROM public.activity_feed af
     WHERE af.post_id = v_post_id
       AND af.review_id IS NOT NULL;

    IF v_review_id IS NULL THEN
      SELECT p.review_id INTO v_review_id
        FROM public.feed_posts p
       WHERE p.id = v_post_id;
    END IF;
  END IF;

  post_id   := v_post_id;
  review_id := v_review_id;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_interaction_refs(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fill_interaction_refs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_refs record;
BEGIN
  SELECT * INTO v_refs
    FROM public.resolve_interaction_refs(NEW.post_id, NEW.review_id);

  NEW.post_id   := v_refs.post_id;
  NEW.review_id := v_refs.review_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fill_comment_refs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_parent_post uuid;
  v_refs        record;
BEGIN
  IF NEW.parent_comment_id IS NOT NULL THEN
    SELECT c.post_id INTO v_parent_post
      FROM public.review_comments c
     WHERE c.id = NEW.parent_comment_id;
  END IF;

  SELECT * INTO v_refs
    FROM public.resolve_interaction_refs(NEW.post_id, NEW.review_id, v_parent_post);

  NEW.post_id   := v_refs.post_id;
  NEW.review_id := v_refs.review_id;

  IF NEW.parent_comment_id IS NOT NULL
     AND (v_parent_post IS NULL OR v_parent_post IS DISTINCT FROM NEW.post_id) THEN
    RAISE EXCEPTION 'parent_comment_id debe pertenecer al mismo post (%)', NEW.post_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_refs_likes ON public.review_likes;
CREATE TRIGGER trg_fill_refs_likes
  BEFORE INSERT ON public.review_likes
  FOR EACH ROW EXECUTE FUNCTION public.fill_interaction_refs();

DROP TRIGGER IF EXISTS trg_fill_refs_comments ON public.review_comments;
CREATE TRIGGER trg_fill_refs_comments
  BEFORE INSERT ON public.review_comments
  FOR EACH ROW EXECUTE FUNCTION public.fill_comment_refs();
