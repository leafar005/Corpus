-- =============================================================================
-- Migración 1/3: Esquema de `feed_posts`, funciones, RPCs y triggers.
-- Spec: Posts del feed con hilo propio y posts agrupados (Fases 1 y 2).
--
-- Esta migración es 100 % aditiva y compatible con clientes antiguos (v1.2.4 /
-- v1.3.0): crea la tabla `feed_posts`, añade las columnas `post_id` como
-- anulables y activa los triggers que asignan `post_id` a eventos e
-- interacciones nuevas o heredadas por `review_id`.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Tabla `public.feed_posts` e índices
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.feed_posts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status     text,                                   -- NULL en logros
  groupable  boolean NOT NULL DEFAULT false,         -- acepta nuevos ítems sin información adicional
  starts_at  timestamptz NOT NULL DEFAULT now(),
  ends_at    timestamptz NOT NULL DEFAULT now(),
  review_id  uuid REFERENCES public.reviews(id) ON DELETE CASCADE, -- solo posts implícitos
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT feed_posts_window_chk CHECK (ends_at >= starts_at)
);

CREATE INDEX IF NOT EXISTS feed_posts_open_idx
  ON public.feed_posts (user_id, status, ends_at DESC)
  WHERE groupable;

CREATE INDEX IF NOT EXISTS feed_posts_review_idx
  ON public.feed_posts (review_id)
  WHERE review_id IS NOT NULL;

ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view feed posts" ON public.feed_posts;
CREATE POLICY "Anyone can view feed posts"
  ON public.feed_posts FOR SELECT
  USING (true);
-- Sin políticas de escritura directa: solo escriben triggers y funciones SECURITY DEFINER.

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Columnas `post_id` (anulables antes del backfill) e índices
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.activity_feed
  ADD COLUMN IF NOT EXISTS post_id uuid REFERENCES public.feed_posts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS activity_feed_post_idx
  ON public.activity_feed (post_id);

ALTER TABLE public.review_likes
  ADD COLUMN IF NOT EXISTS post_id uuid REFERENCES public.feed_posts(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_review_likes_post_id
  ON public.review_likes (post_id);

ALTER TABLE public.review_comments
  ADD COLUMN IF NOT EXISTS post_id uuid REFERENCES public.feed_posts(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_review_comments_post_id
  ON public.review_comments (post_id, created_at);

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS post_id uuid REFERENCES public.feed_posts(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_notifications_post_id
  ON public.notifications (post_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Regla centralizada «sin información adicional» y asignación de post
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_bare_activity(
  p_user_id uuid,
  p_game_id int,
  p_review_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.reviews r
     WHERE r.id = p_review_id AND (
           coalesce(r.rating, 0) > 0
        OR coalesce(r.rating_gameplay, 0) > 0
        OR coalesce(r.rating_narrative, 0) > 0
        OR coalesce(r.rating_soundtrack, 0) > 0
        OR coalesce(r.rating_visuals, 0) > 0
        OR btrim(coalesce(r.comment, '')) <> ''
        OR cardinality(coalesce(r.image_urls, '{}')) > 0
        OR cardinality(coalesce(r.partner_ids, '{}')) > 0
        OR coalesce(r.play_time_hours, 0) > 0
        OR coalesce(r.is_replay, false))
  ) AND NOT EXISTS (
    SELECT 1 FROM public.user_games ug
     WHERE ug.user_id = p_user_id
       AND ug.game_id = p_game_id
       AND cardinality(coalesce(ug.partner_ids, '{}')) > 0
  );
$$;

-- Cuerpo extraído para reutilizar exactamente la misma lógica en el trigger
-- `assign_feed_post` y en el backfill histórico (§6).
CREATE OR REPLACE FUNCTION public.compute_feed_post(p_row public.activity_feed)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
  v_bare   boolean := false;
  v_post   uuid;
  v_ts     timestamptz := coalesce(p_row.created_at, now());
  c_groupable text[] := ARRAY['wishlist', 'playing', 'to_play', 'beaten', 'completed'];
  c_gap    interval := interval '60 minutes';
BEGIN
  IF p_row.post_id IS NOT NULL THEN
    RETURN p_row.post_id;
  END IF;

  IF p_row.action_type = 'status_change' THEN
    v_status := p_row.metadata->>'status';
    v_bare := v_status = ANY (c_groupable)
              AND public.is_bare_activity(p_row.user_id, p_row.game_id, p_row.review_id);

    -- Serializa altas concurrentes del mismo usuario y estado (importaciones, doble toque).
    PERFORM pg_advisory_xact_lock(
      hashtextextended(p_row.user_id::text || ':' || coalesce(v_status, ''), 0)
    );

    IF v_bare THEN
      SELECT p.id INTO v_post
        FROM public.feed_posts p
       WHERE p.user_id = p_row.user_id
         AND p.status = v_status
         AND p.groupable
         AND v_ts BETWEEN p.starts_at - c_gap AND p.ends_at + c_gap
       ORDER BY p.ends_at DESC
       LIMIT 1;
    END IF;

    IF v_post IS NULL THEN
      INSERT INTO public.feed_posts (user_id, status, groupable, starts_at, ends_at, created_at)
      VALUES (p_row.user_id, v_status, v_bare, v_ts, v_ts, v_ts)
      RETURNING id INTO v_post;
    ELSE
      UPDATE public.feed_posts
         SET starts_at = LEAST(starts_at, v_ts),
             ends_at   = GREATEST(ends_at, v_ts)
       WHERE id = v_post;
    END IF;

  ELSIF p_row.action_type = 'reviewed' THEN
    IF p_row.review_id IS NOT NULL THEN
      SELECT af.post_id INTO v_post
        FROM public.activity_feed af
       WHERE af.review_id = p_row.review_id
         AND af.action_type = 'reviewed'
         AND af.post_id IS NOT NULL
       LIMIT 1; -- caso ON CONFLICT DO UPDATE

      IF v_post IS NULL THEN
        SELECT af.post_id INTO v_post
          FROM public.activity_feed af
         WHERE af.review_id = p_row.review_id
           AND af.action_type = 'status_change'
           AND af.post_id IS NOT NULL
         ORDER BY af.created_at DESC, af.id DESC
         LIMIT 1;
      END IF;
    END IF;

    IF v_post IS NULL THEN -- sin hermano: post propio
      INSERT INTO public.feed_posts (user_id, status, groupable, starts_at, ends_at, created_at)
      VALUES (
        p_row.user_id,
        (SELECT r.status FROM public.reviews r WHERE r.id = p_row.review_id),
        false,
        v_ts,
        v_ts,
        v_ts
      )
      RETURNING id INTO v_post;
    END IF;

  ELSE -- achievement
    INSERT INTO public.feed_posts (user_id, status, groupable, starts_at, ends_at, created_at)
    VALUES (p_row.user_id, NULL, false, v_ts, v_ts, v_ts)
    RETURNING id INTO v_post;
  END IF;

  RETURN v_post;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_feed_post()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.post_id IS NULL THEN
    NEW.post_id := public.compute_feed_post(NEW);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_feed_post ON public.activity_feed;
CREATE TRIGGER trg_assign_feed_post
  BEFORE INSERT ON public.activity_feed
  FOR EACH ROW EXECUTE FUNCTION public.assign_feed_post();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Seguimiento de `reviewed` y poda de posts huérfanos
-- ─────────────────────────────────────────────────────────────────────────────

-- Elimina un post sin ítems (salvo los implícitos, que cuelgan de una reseña).
CREATE OR REPLACE FUNCTION public.prune_feed_post(p_post_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  DELETE FROM public.feed_posts p
   WHERE p.id = p_post_id
     AND p.review_id IS NULL
     AND NOT EXISTS (SELECT 1 FROM public.activity_feed af WHERE af.post_id = p.id);
$$;

-- El «reviewed» sigue al último status_change de su reseña.
CREATE OR REPLACE FUNCTION public.follow_reviewed_to_post()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old uuid;
BEGIN
  IF NEW.action_type = 'status_change' AND NEW.review_id IS NOT NULL THEN
    SELECT af.post_id INTO v_old
      FROM public.activity_feed af
     WHERE af.action_type = 'reviewed'
       AND af.review_id = NEW.review_id;

    IF v_old IS NOT NULL AND v_old IS DISTINCT FROM NEW.post_id THEN
      UPDATE public.activity_feed
         SET post_id = NEW.post_id
       WHERE action_type = 'reviewed'
         AND review_id = NEW.review_id;

      -- Solo podar el post temporal de `reviewed` si no tenía interacciones
      -- propias ni otros eventos (evita perder likes/comentarios históricos si
      -- un post antiguo solo tenía fila `reviewed`).
      IF NOT EXISTS (SELECT 1 FROM public.review_likes l WHERE l.post_id = v_old)
         AND NOT EXISTS (SELECT 1 FROM public.review_comments c WHERE c.post_id = v_old) THEN
        PERFORM public.prune_feed_post(v_old);
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_follow_reviewed ON public.activity_feed;
CREATE TRIGGER trg_follow_reviewed
  AFTER INSERT ON public.activity_feed
  FOR EACH ROW EXECUTE FUNCTION public.follow_reviewed_to_post();

CREATE OR REPLACE FUNCTION public.prune_after_feed_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF OLD.post_id IS NOT NULL THEN
    -- Si se borra únicamente la fila satélite `reviewed` pero la reseña sigue
    -- viva (p. ej. cambio a playing/wishlist/to_play en `on_review_upsert`),
    -- no eliminar el post si ya acumula interacciones.
    IF OLD.action_type = 'reviewed'
       AND OLD.review_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.reviews r WHERE r.id = OLD.review_id)
       AND (EXISTS (SELECT 1 FROM public.review_likes l WHERE l.post_id = OLD.post_id)
            OR EXISTS (SELECT 1 FROM public.review_comments c WHERE c.post_id = OLD.post_id)) THEN
      RETURN NULL;
    END IF;

    PERFORM public.prune_feed_post(OLD.post_id);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_prune_feed_post ON public.activity_feed;
CREATE TRIGGER trg_prune_feed_post
  AFTER DELETE ON public.activity_feed
  FOR EACH ROW EXECUTE FUNCTION public.prune_after_feed_delete();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Escisión de un ítem que deja de estar «sin información adicional» (Fase 2)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.split_grouped_review_on_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sc_id        uuid;
  v_old_post     uuid;
  v_sc_created   timestamptz;
  v_new_post     uuid;
  v_has_siblings boolean;
BEGIN
  -- Si sigue siendo una actividad escueta (sin nota, comentario, fotos, horas,
  -- replay ni compañeros), permanece en su post actual.
  IF public.is_bare_activity(NEW.user_id, NEW.game_id, NEW.id) THEN
    RETURN NULL;
  END IF;

  -- Buscar el status_change más reciente de esta reseña.
  SELECT af.id, af.post_id, coalesce(af.created_at, now())
    INTO v_sc_id, v_old_post, v_sc_created
    FROM public.activity_feed af
   WHERE af.review_id = NEW.id
     AND af.action_type = 'status_change'
     AND af.post_id IS NOT NULL
   ORDER BY af.created_at DESC, af.id DESC
   LIMIT 1;

  IF v_old_post IS NULL THEN
    RETURN NULL;
  END IF;

  -- ¿Comparte post con otros juegos/eventos ajenos a esta reseña?
  SELECT EXISTS (
    SELECT 1 FROM public.activity_feed af
     WHERE af.post_id = v_old_post
       AND af.id <> v_sc_id
       AND (af.review_id IS DISTINCT FROM NEW.id OR af.action_type <> 'reviewed')
  ) INTO v_has_siblings;

  IF v_has_siblings THEN
    -- Escindir: crear post propio no agrupable y mover status_change + reviewed.
    INSERT INTO public.feed_posts (user_id, status, groupable, starts_at, ends_at, created_at)
    VALUES (NEW.user_id, NEW.status, false, v_sc_created, v_sc_created, v_sc_created)
    RETURNING id INTO v_new_post;

    UPDATE public.activity_feed
       SET post_id = v_new_post
     WHERE id = v_sc_id
        OR (review_id = NEW.id AND action_type = 'reviewed');

    -- Recalcular ventana temporal del grupo original con los ítems restantes.
    UPDATE public.feed_posts p
       SET starts_at = coalesce(sub.min_ts, p.starts_at),
           ends_at   = GREATEST(coalesce(sub.max_ts, p.ends_at), coalesce(sub.min_ts, p.starts_at))
      FROM (
        SELECT min(created_at) AS min_ts, max(created_at) AS max_ts
          FROM public.activity_feed
         WHERE post_id = v_old_post
      ) sub
     WHERE p.id = v_old_post;
  ELSE
    -- Era el único juego del post: simplemente marcarlo como no agrupable para
    -- que nuevas altas no se unan a él, conservando sus likes y comentarios.
    UPDATE public.feed_posts
       SET groupable = false
     WHERE id = v_old_post AND groupable;
  END IF;

  RETURN NULL;
END;
$$;

-- El prefijo `trg_zzz_` garantiza que se ejecute después de `trg_review_upsert`
-- y `trg_sync_user_games_on_review` en el orden alfabético de PostgreSQL.
DROP TRIGGER IF EXISTS trg_zzz_split_grouped_review ON public.reviews;
CREATE TRIGGER trg_zzz_split_grouped_review
  AFTER UPDATE ON public.reviews
  FOR EACH ROW
  WHEN (OLD.status IS NOT DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.split_grouped_review_on_update();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Resolución `review_id` -> `post_id` vigente y compatibilidad de escrituras
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.current_post_for_review(p_review_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    (SELECT af.post_id
       FROM public.activity_feed af
      WHERE af.review_id = p_review_id
        AND af.post_id IS NOT NULL
      ORDER BY af.created_at DESC, af.id DESC
      LIMIT 1),
    (SELECT p.id
       FROM public.feed_posts p
      WHERE p.review_id = p_review_id
      ORDER BY p.created_at DESC
      LIMIT 1)
  );
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

  SELECT user_id, status, coalesce(created_at, now()) AS ts
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

-- Resuelve la pareja (post_id, review_id) para cualquier interacción (likes y
-- comentarios), cubriendo tanto clientes antiguos (solo `review_id`) como
-- clientes nuevos (solo `post_id`).
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
    -- post_id manda; review_id se deriva si el post corresponde a una única reseña.
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

-- Trigger de relleno para `review_likes` (nunca referencia columnas exclusivas
-- de `review_comments`, evitando el error 42703 al compilar NEW en PostgreSQL).
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

-- Trigger de relleno y validación de hilo padre para `review_comments`.
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

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Resumen de post para notificaciones y RPCs de estadísticas por lote
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.post_summary(p_post_id uuid)
RETURNS TABLE (owner_id uuid, games_count int, first_title text, first_cover text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH items AS (
    SELECT af.game_id, af.created_at
      FROM public.activity_feed af
     WHERE af.post_id = p_post_id
       AND af.game_id IS NOT NULL
    UNION ALL
    SELECT r.game_id, r.created_at
      FROM public.feed_posts p
      JOIN public.reviews r ON r.id = p.review_id
     WHERE p.id = p_post_id
  )
  SELECT p.user_id,
         (SELECT count(DISTINCT game_id)::int FROM items),
         (SELECT g.title     FROM items i JOIN public.games g ON g.igdb_id = i.game_id ORDER BY i.created_at DESC LIMIT 1),
         (SELECT g.cover_url FROM items i JOIN public.games g ON g.igdb_id = i.game_id ORDER BY i.created_at DESC LIMIT 1)
    FROM public.feed_posts p
   WHERE p.id = p_post_id;
$$;

GRANT EXECUTE ON FUNCTION public.post_summary(uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_post_stats(p_post_ids uuid[])
RETURNS TABLE (post_id uuid, likes_count int, comments_count int, liked_by_me boolean)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT u.id,
         (SELECT count(*)::int FROM public.review_likes l WHERE l.post_id = u.id),
         (SELECT count(*)::int FROM public.review_comments c WHERE c.post_id = u.id),
         EXISTS (
           SELECT 1 FROM public.review_likes l
            WHERE l.post_id = u.id
              AND l.user_id = auth.uid()
         )
    FROM unnest(p_post_ids) AS u(id);
$$;

CREATE OR REPLACE FUNCTION public.get_review_post_stats(p_review_ids uuid[])
RETURNS TABLE (review_id uuid, post_id uuid, likes_count int, comments_count int, liked_by_me boolean)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT r.id,
         cp.post_id,
         coalesce(s.likes_count, 0),
         coalesce(s.comments_count, 0),
         coalesce(s.liked_by_me, false)
    FROM unnest(p_review_ids) AS r(id)
   CROSS JOIN LATERAL (SELECT public.current_post_for_review(r.id) AS post_id) cp
    LEFT JOIN LATERAL public.get_post_stats(
      CASE WHEN cp.post_id IS NOT NULL THEN ARRAY[cp.post_id] ELSE ARRAY[]::uuid[] END
    ) s ON true;
$$;

GRANT EXECUTE ON FUNCTION public.get_post_stats(uuid[]), public.get_review_post_stats(uuid[])
  TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Actualizar `get_unread_activity_summary` para contar por `post_id` (§7)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_unread_activity_summary()
RETURNS TABLE (unread_count integer, last_read_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_since timestamptz;
  v_count integer;
BEGIN
  SELECT u.last_activity_read_at INTO v_since
  FROM public.users u
  WHERE u.id = auth.uid();

  IF v_since IS NULL THEN
    RETURN QUERY SELECT 0, now();
    RETURN;
  END IF;

  SELECT COUNT(DISTINCT COALESCE(af.post_id, af.id))::integer
  INTO v_count
  FROM public.activity_feed af
  WHERE af.user_id <> auth.uid()
    AND af.created_at > v_since;

  RETURN QUERY SELECT COALESCE(v_count, 0), v_since;
END;
$$;

