-- =============================================================================
-- Aísla los hilos (likes/comentarios) de posts grupales frente a los juegos
-- individuales que forman parte del grupo.
--
-- Problema:
--   Cuando varios juegos escuetos (p. ej. varios "Por jugar" añadidos a la vez)
--   comparten un `post_id` grupal en `activity_feed`, `current_post_for_review`
--   devolvía ese `post_id` grupal al abrir cualquiera de esos juegos en solitario
--   (`ReviewDetailsScreen`), arrastrando likes y comentarios del grupo a todos
--   los juegos del lote.
--
-- Solución:
--   1. Si el último evento en `activity_feed` de una reseña pertenece a un post
--      compartido con otros juegos o reseñas (post grupal), `current_post_for_review`
--      NO devuelve ese post grupal ni retrocede a estados anteriores: busca
--      únicamente un post implícito propio (`feed_posts.review_id = p_review_id`)
--      vigente para este episodio (`created_at >= v_latest_af_ts`), o devuelve
--      `NULL` si nadie ha interactuado con el juego en solitario.
--   2. `ensure_review_post` usa `GREATEST(r.created_at, max(af.created_at), now())`
--      para que el post implícito creado al comentar/likear en solitario pertenezca
--      al episodio actual y siga siendo idempotente.
-- =============================================================================

CREATE INDEX IF NOT EXISTS activity_feed_review_post_idx
  ON public.activity_feed (review_id, created_at DESC, id DESC)
  WHERE review_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.current_post_for_review(p_review_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id        uuid;
  v_game_id        int;
  v_latest_af_post uuid;
  v_latest_af_ts   timestamptz;
  v_is_grouped     boolean := false;
  v_implicit_post  uuid;
BEGIN
  IF p_review_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT r.user_id, r.game_id
    INTO v_user_id, v_game_id
    FROM public.reviews r
   WHERE r.id = p_review_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT af.post_id, af.created_at
    INTO v_latest_af_post, v_latest_af_ts
    FROM public.activity_feed af
   WHERE af.review_id = p_review_id
     AND af.post_id IS NOT NULL
   ORDER BY af.created_at DESC, af.id DESC
   LIMIT 1;

  IF v_latest_af_post IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
        FROM public.activity_feed af_other
       WHERE af_other.post_id = v_latest_af_post
         AND (
              af_other.user_id IS DISTINCT FROM v_user_id
           OR af_other.game_id IS DISTINCT FROM v_game_id
           OR (af_other.review_id IS NOT NULL AND af_other.review_id IS DISTINCT FROM p_review_id)
         )
    ) INTO v_is_grouped;

    IF NOT v_is_grouped THEN
      RETURN v_latest_af_post;
    END IF;
  END IF;

  SELECT p.id
    INTO v_implicit_post
    FROM public.feed_posts p
   WHERE p.review_id = p_review_id
     AND (
          v_latest_af_ts IS NULL
       OR p.created_at >= v_latest_af_ts
     )
   ORDER BY p.created_at DESC, p.id DESC
   LIMIT 1;

  RETURN v_implicit_post;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_review_post(p_review_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v uuid;
  r record;
BEGIN
  IF p_review_id IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_review_id::text, 1));

  v := public.current_post_for_review(p_review_id);
  IF v IS NOT NULL THEN
    RETURN v;
  END IF;

  SELECT user_id,
         status,
         GREATEST(
           coalesce(created_at, now()),
           coalesce(
             (SELECT max(af.created_at)
                FROM public.activity_feed af
               WHERE af.review_id = p_review_id),
             '-infinity'::timestamptz
           ),
           now()
         ) AS ts
    INTO r
    FROM public.reviews
   WHERE id = p_review_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.feed_posts (user_id, status, groupable, starts_at, ends_at, review_id, created_at)
  VALUES (r.user_id, r.status, false, r.ts, r.ts, p_review_id, r.ts)
  RETURNING id INTO v;

  RETURN v;
END;
$$;

GRANT EXECUTE ON FUNCTION public.current_post_for_review(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_review_post(uuid) TO authenticated;

