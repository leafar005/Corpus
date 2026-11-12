-- =============================================================================
-- Migration 3/3: Feed Posts Constraints, PK Switch & Notification Triggers
-- =============================================================================
-- Propósito:
-- 1. Verificar antes de aplicar restricciones que no queden post_id nulos ni
--    colisiones (user_id, post_id) en review_likes.
-- 2. Hacer post_id NOT NULL y review_id nullable en review_likes y review_comments.
-- 3. Cambiar la clave primaria de review_likes a (user_id, post_id).
-- 4. Actualizar los triggers de notificaciones (notify_review_like,
--    notify_review_unlike, notify_review_comment) para resolver el destinatario
--    y metadatos del post vía public.post_summary(post_id).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Comprobación previa de seguridad
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_null_likes    bigint;
  v_null_comments bigint;
  v_dup_likes     bigint;
BEGIN
  SELECT count(*) INTO v_null_likes    FROM public.review_likes    WHERE post_id IS NULL;
  SELECT count(*) INTO v_null_comments FROM public.review_comments WHERE post_id IS NULL;
  SELECT count(*) INTO v_dup_likes
  FROM (
    SELECT user_id, post_id
    FROM public.review_likes
    GROUP BY user_id, post_id
    HAVING count(*) > 1
  ) d;

  IF v_null_likes > 0 OR v_null_comments > 0 OR v_dup_likes > 0 THEN
    RAISE EXCEPTION
      'Cannot apply feed_posts constraints: null_likes=%, null_comments=%, duplicate_likes=%',
      v_null_likes, v_null_comments, v_dup_likes;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 1. Restricciones NOT NULL y nueva clave primaria
-- -----------------------------------------------------------------------------
ALTER TABLE public.review_likes
  DROP CONSTRAINT review_likes_pkey,
  ADD CONSTRAINT review_likes_pkey PRIMARY KEY (user_id, post_id);

ALTER TABLE public.review_likes
  ALTER COLUMN post_id SET NOT NULL,
  ALTER COLUMN review_id DROP NOT NULL;

ALTER TABLE public.review_comments
  ALTER COLUMN post_id SET NOT NULL,
  ALTER COLUMN review_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS review_likes_post_idx
  ON public.review_likes (post_id);

CREATE INDEX IF NOT EXISTS review_comments_post_idx
  ON public.review_comments (post_id, created_at);

CREATE INDEX IF NOT EXISTS notifications_post_idx
  ON public.notifications (post_id);

-- -----------------------------------------------------------------------------
-- 2. Triggers de notificaciones basados en post_summary(post_id)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_review_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s record;
BEGIN
  SELECT * INTO s FROM public.post_summary(NEW.post_id);

  IF s.owner_id IS NULL OR s.owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (
    recipient_id,
    actor_id,
    type,
    review_id,
    post_id,
    metadata
  )
  VALUES (
    s.owner_id,
    NEW.user_id,
    'like',
    NEW.review_id,
    NEW.post_id,
    jsonb_strip_nulls(jsonb_build_object(
      'game_title',     CASE WHEN s.games_count = 1 THEN s.first_title END,
      'game_cover_url', s.first_cover,
      'games_count',    s.games_count
    ))
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_review_unlike()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.notifications
  WHERE type     = 'like'
    AND actor_id = OLD.user_id
    AND post_id  = OLD.post_id;

  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_review_comment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s           record;
  v_recipient uuid;
  v_type      text;
  v_snippet   text := left(coalesce(NEW.content, ''), 140);
BEGIN
  SELECT * INTO s FROM public.post_summary(NEW.post_id);

  IF NEW.parent_comment_id IS NULL THEN
    v_type      := 'comment';
    v_recipient := s.owner_id;
  ELSE
    v_type      := 'reply';
    SELECT c.user_id INTO v_recipient
    FROM public.review_comments c
    WHERE c.id = NEW.parent_comment_id;
  END IF;

  IF v_recipient IS NULL OR v_recipient = NEW.user_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (
    recipient_id,
    actor_id,
    type,
    review_id,
    post_id,
    comment_id,
    metadata,
    created_at
  )
  VALUES (
    v_recipient,
    NEW.user_id,
    v_type,
    NEW.review_id,
    NEW.post_id,
    NEW.id,
    jsonb_strip_nulls(jsonb_build_object(
      'game_title',      CASE WHEN s.games_count = 1 THEN s.first_title END,
      'game_cover_url',  s.first_cover,
      'games_count',     s.games_count,
      'comment_snippet', v_snippet
    )),
    NEW.created_at
  );

  RETURN NEW;
END;
$$;
