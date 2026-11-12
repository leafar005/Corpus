-- =============================================================================
-- Migration 2/3: Feed Posts Backfill (Aditivo, Idempotente y Auditable)
-- =============================================================================
-- Propósito:
-- 1. Crear copias íntegras de respaldo en el esquema privado `backup` antes de
--    tocar cualquier fila existente.
-- 2. Asignar `post_id` a todos los eventos históricos de `activity_feed`.
-- 3. Reasignar comentarios (`review_comments`) y likes (`review_likes`) al post
--    correspondiente por fecha (`created_at`), preservando la jerarquía de
--    respuestas (`parent_comment_id`) y creando posts implícitos para reseñas
--    sin evento en el feed.
-- 4. Resolver colisiones de `(user_id, post_id)` en `review_likes` cuando dos
--    reseñas escuetas antiguas quedan agrupadas en el mismo post, registrando
--    cada fila afectada en `backup.feed_posts_backfill_report`.
-- 5. Asignar `post_id` a `notifications`.
-- 6. Ejecutar aserciones automáticas que abortan la transacción si algún
--    invariante falla.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Esquema de respaldo y tablas de auditoría
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS backup;
REVOKE ALL ON SCHEMA backup FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS backup.review_comments_20261110 AS
  TABLE public.review_comments;

CREATE TABLE IF NOT EXISTS backup.review_likes_20261110 AS
  TABLE public.review_likes;

CREATE TABLE IF NOT EXISTS backup.activity_feed_20261110 AS
  TABLE public.activity_feed;

CREATE TABLE IF NOT EXISTS backup.notifications_20261110 AS
  TABLE public.notifications;

CREATE TABLE IF NOT EXISTS backup.feed_posts_backfill_report (
  id              bigserial PRIMARY KEY,
  kind            text NOT NULL, -- 'comment_multi_post' | 'like_multi_post' | 'implicit_post' | 'deduped_group_like'
  row_id          uuid,
  review_id       uuid,
  assigned_post   uuid,
  posts_in_review int,
  details         jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 1. Asignar post_id a activity_feed
-- -----------------------------------------------------------------------------
-- Orden: primero todos los status_change y achievement_unlocked en orden
-- cronológico por usuario, y al final los reviewed para que se enganchen al
-- último post de su reseña si existe.
DO $$
DECLARE
  r      public.activity_feed;
  v_post uuid;
BEGIN
  FOR r IN
    SELECT * FROM public.activity_feed
    WHERE post_id IS NULL
    ORDER BY (action_type = 'reviewed'), user_id, created_at, id
  LOOP
    v_post := public.compute_feed_post(r);
    UPDATE public.activity_feed
    SET post_id = v_post
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. Asignar post_id a review_comments (por fecha y preservando hilos)
-- -----------------------------------------------------------------------------

-- 2a. Comentarios raíz (parent_comment_id IS NULL): último status_change de esa
--     reseña con created_at <= comentario.created_at.
UPDATE public.review_comments c
SET post_id = (
  SELECT af.post_id
  FROM public.activity_feed af
  WHERE af.review_id = c.review_id
    AND af.action_type = 'status_change'
    AND af.post_id IS NOT NULL
    AND af.created_at <= c.created_at
  ORDER BY af.created_at DESC, af.id DESC
  LIMIT 1
)
WHERE c.parent_comment_id IS NULL
  AND c.post_id IS NULL;

-- 2b. Fallback para comentarios raíz anteriores al primer status_change (o de
--     reseñas que solo tienen fila reviewed): primer post de la reseña.
UPDATE public.review_comments c
SET post_id = (
  SELECT af.post_id
  FROM public.activity_feed af
  WHERE af.review_id = c.review_id
    AND af.post_id IS NOT NULL
  ORDER BY (af.action_type = 'status_change') DESC, af.created_at ASC, af.id ASC
  LIMIT 1
)
WHERE c.parent_comment_id IS NULL
  AND c.post_id IS NULL;

-- 2c. Fallback para comentarios raíz cuya reseña no tiene ningún evento en
--     activity_feed: post implícito (ensure_review_post).
UPDATE public.review_comments c
SET post_id = public.ensure_review_post(c.review_id)
WHERE c.parent_comment_id IS NULL
  AND c.post_id IS NULL
  AND c.review_id IS NOT NULL;

-- 2d. Respuestas (parent_comment_id IS NOT NULL): heredan el post_id de su
--     comentario padre para garantizar el invariante de que un hilo nunca se
--     parta entre dos posts aunque la respuesta sea posterior a un cambio de
--     estado. Iteramos por si hubiera varios niveles de anidamiento.
DO $$
DECLARE
  v_updated int;
BEGIN
  LOOP
    UPDATE public.review_comments child
    SET post_id = parent.post_id
    FROM public.review_comments parent
    WHERE child.parent_comment_id = parent.id
      AND child.post_id IS NULL
      AND parent.post_id IS NOT NULL;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    EXIT WHEN v_updated = 0;
  END LOOP;
END;
$$;

-- 2e. Fallback defensivo si quedase alguna respuesta cuyo padre no tuviera post:
UPDATE public.review_comments c
SET post_id = COALESCE(
  (
    SELECT af.post_id
    FROM public.activity_feed af
    WHERE af.review_id = c.review_id
      AND af.action_type = 'status_change'
      AND af.post_id IS NOT NULL
      AND af.created_at <= c.created_at
    ORDER BY af.created_at DESC, af.id DESC
    LIMIT 1
  ),
  (
    SELECT af.post_id
    FROM public.activity_feed af
    WHERE af.review_id = c.review_id
      AND af.post_id IS NOT NULL
    ORDER BY (af.action_type = 'status_change') DESC, af.created_at ASC, af.id ASC
    LIMIT 1
  ),
  public.ensure_review_post(c.review_id)
)
WHERE c.post_id IS NULL
  AND c.review_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. Asignar post_id a review_likes por fecha
-- -----------------------------------------------------------------------------

-- 3a. Último status_change de esa reseña con created_at <= like.created_at.
--     Si created_at fuese NULL en filas antiguas, coalesce a '-infinity' cae al 3b.
UPDATE public.review_likes l
SET post_id = (
  SELECT af.post_id
  FROM public.activity_feed af
  WHERE af.review_id = l.review_id
    AND af.action_type = 'status_change'
    AND af.post_id IS NOT NULL
    AND af.created_at <= COALESCE(l.created_at, '-infinity'::timestamptz)
  ORDER BY af.created_at DESC, af.id DESC
  LIMIT 1
)
WHERE l.post_id IS NULL;

-- 3b. Fallback: primer post de la reseña en el feed.
UPDATE public.review_likes l
SET post_id = (
  SELECT af.post_id
  FROM public.activity_feed af
  WHERE af.review_id = l.review_id
    AND af.post_id IS NOT NULL
  ORDER BY (af.action_type = 'status_change') DESC, af.created_at ASC, af.id ASC
  LIMIT 1
)
WHERE l.post_id IS NULL;

-- 3c. Fallback: post implícito para reseñas sin evento en el feed.
UPDATE public.review_likes l
SET post_id = public.ensure_review_post(l.review_id)
WHERE l.post_id IS NULL
  AND l.review_id IS NOT NULL;

-- 3d. Deduplicación auditada de colisiones (user_id, post_id) en posts agrupados:
--     Si en el pasado un usuario dio like por separado a dos reseñas escuetas
--     que ahora comparten el mismo post agrupado, ambas filas tienen el mismo
--     (user_id, post_id). Registramos las filas redundantes en el informe de
--     auditoría y conservamos el like más antiguo por (user_id, post_id) para
--     que la clave primaria (user_id, post_id) sea válida.
WITH ranked_likes AS (
  SELECT
    ctid AS row_ctid,
    user_id,
    review_id,
    post_id,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, post_id
      ORDER BY created_at ASC NULLS LAST, review_id ASC
    ) AS rn
  FROM public.review_likes
  WHERE post_id IS NOT NULL
),
duplicates AS (
  DELETE FROM public.review_likes l
  USING ranked_likes rl
  WHERE l.ctid = rl.row_ctid
    AND rl.rn > 1
  RETURNING l.user_id, l.review_id, l.post_id, l.created_at
)
INSERT INTO backup.feed_posts_backfill_report (
  kind,
  row_id,
  review_id,
  assigned_post,
  posts_in_review,
  details
)
SELECT
  'deduped_group_like',
  d.user_id,
  d.review_id,
  d.post_id,
  1,
  jsonb_build_object(
    'user_id', d.user_id,
    'review_id', d.review_id,
    'post_id', d.post_id,
    'like_created_at', d.created_at
  )
FROM duplicates d;

-- -----------------------------------------------------------------------------
-- 4. Asignar post_id a notifications
-- -----------------------------------------------------------------------------

-- 4a. Notificaciones de comentario o respuesta: mismo post_id que el comentario.
UPDATE public.notifications n
SET post_id = c.post_id
FROM public.review_comments c
WHERE n.comment_id = c.id
  AND n.post_id IS NULL;

-- 4b. Notificaciones de like con fila activa en review_likes:
UPDATE public.notifications n
SET post_id = l.post_id
FROM public.review_likes l
WHERE n.type = 'like'
  AND l.user_id = n.actor_id
  AND l.review_id = n.review_id
  AND n.post_id IS NULL;

-- 4c. Fallback para cualquier notificación restante con review_id:
UPDATE public.notifications n
SET post_id = COALESCE(
  public.current_post_for_review(n.review_id),
  public.ensure_review_post(n.review_id)
)
WHERE n.review_id IS NOT NULL
  AND n.post_id IS NULL;

-- -----------------------------------------------------------------------------
-- 5. Poblar el informe de auditoría (backup.feed_posts_backfill_report)
-- -----------------------------------------------------------------------------

-- 5a. Comentarios en reseñas que tenían más de un post:
INSERT INTO backup.feed_posts_backfill_report (
  kind,
  row_id,
  review_id,
  assigned_post,
  posts_in_review,
  details
)
SELECT
  'comment_multi_post',
  c.id,
  c.review_id,
  c.post_id,
  stats.posts_count,
  jsonb_build_object(
    'comment_created_at', c.created_at,
    'parent_comment_id', c.parent_comment_id
  )
FROM public.review_comments c
JOIN (
  SELECT review_id, count(DISTINCT post_id)::int AS posts_count
  FROM public.activity_feed
  WHERE review_id IS NOT NULL AND post_id IS NOT NULL
  GROUP BY review_id
  HAVING count(DISTINCT post_id) > 1
) stats ON stats.review_id = c.review_id
WHERE NOT EXISTS (
  SELECT 1 FROM backup.feed_posts_backfill_report r
  WHERE r.kind = 'comment_multi_post' AND r.row_id = c.id
);

-- 5b. Likes en reseñas que tenían más de un post:
INSERT INTO backup.feed_posts_backfill_report (
  kind,
  row_id,
  review_id,
  assigned_post,
  posts_in_review,
  details
)
SELECT
  'like_multi_post',
  l.user_id,
  l.review_id,
  l.post_id,
  stats.posts_count,
  jsonb_build_object(
    'user_id', l.user_id,
    'like_created_at', l.created_at
  )
FROM public.review_likes l
JOIN (
  SELECT review_id, count(DISTINCT post_id)::int AS posts_count
  FROM public.activity_feed
  WHERE review_id IS NOT NULL AND post_id IS NOT NULL
  GROUP BY review_id
  HAVING count(DISTINCT post_id) > 1
) stats ON stats.review_id = l.review_id
WHERE NOT EXISTS (
  SELECT 1 FROM backup.feed_posts_backfill_report r
  WHERE r.kind = 'like_multi_post'
    AND r.row_id = l.user_id
    AND r.review_id = l.review_id
);

-- 5c. Posts implícitos creados para reseñas sin eventos en activity_feed:
INSERT INTO backup.feed_posts_backfill_report (
  kind,
  row_id,
  review_id,
  assigned_post,
  posts_in_review,
  details
)
SELECT
  'implicit_post',
  fp.id,
  fp.review_id,
  fp.id,
  0,
  jsonb_build_object(
    'user_id', fp.user_id,
    'status', fp.status,
    'starts_at', fp.starts_at
  )
FROM public.feed_posts fp
WHERE fp.review_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM backup.feed_posts_backfill_report r
    WHERE r.kind = 'implicit_post' AND r.assigned_post = fp.id
  );

-- -----------------------------------------------------------------------------
-- 6. Verificaciones de integridad en transacción (abortan si algo falla)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_null_feed          bigint;
  v_null_comments      bigint;
  v_null_likes         bigint;
  v_comments_before    bigint;
  v_comments_after     bigint;
  v_likes_before       bigint;
  v_likes_after        bigint;
  v_likes_deduped      bigint;
  v_split_threads      bigint;
  v_mismatched_owners  bigint;
  v_orphan_posts       bigint;
BEGIN
  -- 1. Ninguna fila sin post_id
  SELECT count(*) INTO v_null_feed     FROM public.activity_feed   WHERE post_id IS NULL;
  SELECT count(*) INTO v_null_comments FROM public.review_comments WHERE post_id IS NULL;
  SELECT count(*) INTO v_null_likes    FROM public.review_likes    WHERE post_id IS NULL;

  IF v_null_feed > 0 OR v_null_comments > 0 OR v_null_likes > 0 THEN
    RAISE EXCEPTION
      'Backfill verification failed: NULL post_id remaining (activity_feed=%, review_comments=%, review_likes=%)',
      v_null_feed, v_null_comments, v_null_likes;
  END IF;

  -- 2. Conservación exacta del total de comentarios y likes
  SELECT count(*) INTO v_comments_before FROM backup.review_comments_20261110;
  SELECT count(*) INTO v_comments_after  FROM public.review_comments;
  IF v_comments_before <> v_comments_after THEN
    RAISE EXCEPTION
      'Backfill verification failed: review_comments count mismatch (before=%, after=%)',
      v_comments_before, v_comments_after;
  END IF;

  SELECT count(*) INTO v_likes_before  FROM backup.review_likes_20261110;
  SELECT count(*) INTO v_likes_after   FROM public.review_likes;
  SELECT count(*) INTO v_likes_deduped FROM backup.feed_posts_backfill_report WHERE kind = 'deduped_group_like';
  IF v_likes_after + v_likes_deduped <> v_likes_before THEN
    RAISE EXCEPTION
      'Backfill verification failed: review_likes count mismatch (before=%, after=%, deduped=%)',
      v_likes_before, v_likes_after, v_likes_deduped;
  END IF;

  -- 3. Ninguna respuesta en distinto post que su comentario padre
  SELECT count(*) INTO v_split_threads
  FROM public.review_comments child
  JOIN public.review_comments parent ON parent.id = child.parent_comment_id
  WHERE child.post_id IS DISTINCT FROM parent.post_id;

  IF v_split_threads > 0 THEN
    RAISE EXCEPTION
      'Backfill verification failed: % reply comments have a different post_id than their parent',
      v_split_threads;
  END IF;

  -- 4. Todos los comentarios apuntan a un post del mismo autor que su reseña
  SELECT count(*) INTO v_mismatched_owners
  FROM public.review_comments c
  JOIN public.feed_posts p ON p.id = c.post_id
  JOIN public.reviews r    ON r.id = c.review_id
  WHERE p.user_id <> r.user_id;

  IF v_mismatched_owners > 0 THEN
    RAISE EXCEPTION
      'Backfill verification failed: % comments belong to a post whose user_id differs from the review owner',
      v_mismatched_owners;
  END IF;

  -- 5. Ningún post no implícito vacío
  SELECT count(*) INTO v_orphan_posts
  FROM public.feed_posts p
  WHERE p.review_id IS NULL
    AND NOT EXISTS (SELECT 1 FROM public.activity_feed af WHERE af.post_id = p.id);

  IF v_orphan_posts > 0 THEN
    RAISE EXCEPTION
      'Backfill verification failed: % non-implicit feed_posts have no activity_feed items',
      v_orphan_posts;
  END IF;
END;
$$;

