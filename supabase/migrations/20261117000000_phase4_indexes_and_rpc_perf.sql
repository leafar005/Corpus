-- =============================================================================
-- Fase 4: Columnas Metacritic faltantes, limpieza de índices duplicados,
-- índices compuestos y agregación en set para get_post_stats / get_review_post_stats.
-- =============================================================================

-- 1. Columnas de conteos de Metacritic usadas por el cliente y get-metacritic-score
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS metacritic_critic_count integer,
  ADD COLUMN IF NOT EXISTS metacritic_user_rating_count integer;

-- 2. Eliminar índices duplicados respecto a review_likes_post_idx,
--    review_comments_post_idx y notifications_post_idx
DROP INDEX IF EXISTS public.idx_review_likes_post_id;
DROP INDEX IF EXISTS public.idx_review_comments_post_id;
DROP INDEX IF EXISTS public.idx_notifications_post_id;

-- 3. Índices compuestos para acelerar perfil, biblioteca y feed
CREATE INDEX IF NOT EXISTS user_games_user_status_updated_idx
  ON public.user_games (user_id, status, updated_at DESC);

CREATE INDEX IF NOT EXISTS user_games_user_status_last_played_idx
  ON public.user_games (user_id, status, last_played_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS activity_feed_user_created_idx
  ON public.activity_feed (user_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS activity_feed_created_id_idx
  ON public.activity_feed (created_at DESC, id DESC);

-- 4. Reescritura en set (GROUP BY post_id) de get_post_stats y get_review_post_stats
CREATE OR REPLACE FUNCTION public.get_post_stats(p_post_ids uuid[])
RETURNS TABLE (post_id uuid, likes_count int, comments_count int, liked_by_me boolean)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  WITH input_ids AS (
    SELECT DISTINCT u.id
      FROM unnest(p_post_ids) AS u(id)
     WHERE u.id IS NOT NULL
  ),
  likes_agg AS (
    SELECT l.post_id,
           count(*)::int AS likes_count,
           bool_or(l.user_id = (SELECT auth.uid())) AS liked_by_me
      FROM public.review_likes l
      JOIN input_ids i ON i.id = l.post_id
     GROUP BY l.post_id
  ),
  comments_agg AS (
    SELECT c.post_id,
           count(*)::int AS comments_count
      FROM public.review_comments c
      JOIN input_ids i ON i.id = c.post_id
     GROUP BY c.post_id
  )
  SELECT i.id AS post_id,
         coalesce(la.likes_count, 0) AS likes_count,
         coalesce(ca.comments_count, 0) AS comments_count,
         coalesce(la.liked_by_me, false) AS liked_by_me
    FROM input_ids i
    LEFT JOIN likes_agg la ON la.post_id = i.id
    LEFT JOIN comments_agg ca ON ca.post_id = i.id;
$$;

CREATE OR REPLACE FUNCTION public.get_review_post_stats(p_review_ids uuid[])
RETURNS TABLE (review_id uuid, post_id uuid, likes_count int, comments_count int, liked_by_me boolean)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  WITH resolved_posts AS (
    SELECT r.id AS review_id,
           public.current_post_for_review(r.id) AS post_id
      FROM (
        SELECT DISTINCT u.id
          FROM unnest(p_review_ids) AS u(id)
         WHERE u.id IS NOT NULL
      ) r
  ),
  stats AS (
    SELECT *
      FROM public.get_post_stats(
        coalesce(
          (SELECT array_agg(DISTINCT rp.post_id) FROM resolved_posts rp WHERE rp.post_id IS NOT NULL),
          ARRAY[]::uuid[]
        )
      )
  )
  SELECT rp.review_id,
         rp.post_id,
         coalesce(s.likes_count, 0) AS likes_count,
         coalesce(s.comments_count, 0) AS comments_count,
         coalesce(s.liked_by_me, false) AS liked_by_me
    FROM resolved_posts rp
    LEFT JOIN stats s ON s.post_id = rp.post_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_post_stats(uuid[]), public.get_review_post_stats(uuid[])
  TO anon, authenticated;

