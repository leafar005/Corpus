-- =============================================================================
-- Sistema de notificaciones sociales in-app: likes, solicitudes de amistad,
-- comentarios en tu reseña y respuestas a tu comentario.
--
-- Tabla nueva `notifications`, poblada exclusivamente por triggers (los
-- clientes no pueden insertar/actualizar/borrar filas directamente, solo
-- leer las suyas y marcarlas como leídas vía RPC).
-- =============================================================================

CREATE TABLE public.notifications (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    actor_id     uuid REFERENCES public.users(id) ON DELETE SET NULL,
    type         text NOT NULL CHECK (
                   type IN ('like', 'friend_request', 'friend_request_accepted', 'comment', 'reply')
                 ),
    review_id    uuid REFERENCES public.reviews(id) ON DELETE CASCADE,
    comment_id   uuid REFERENCES public.review_comments(id) ON DELETE CASCADE,
    metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
    read_at      timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notifications IS
  'Notificaciones sociales in-app (likes, solicitudes de amistad, comentarios '
  'y respuestas). Solo se escribe desde triggers y desde las funciones '
  'mark_notification_read()/mark_all_notifications_read(); los clientes no '
  'tienen INSERT/UPDATE/DELETE directo.';

COMMENT ON COLUMN public.notifications.metadata IS
  'Datos ligeros para pintar la fila sin joins adicionales: game_title, '
  'game_cover_url, comment_snippet. Es una foto fija tomada en el momento '
  'de crear la notificación (no se actualiza si el título del juego cambia '
  'después, por ejemplo).';

CREATE INDEX idx_notifications_recipient_created
  ON public.notifications (recipient_id, created_at DESC);

CREATE INDEX idx_notifications_recipient_unread
  ON public.notifications (recipient_id)
  WHERE read_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- RLS: los usuarios solo pueden LEER sus propias notificaciones. Ninguna
-- escritura directa está permitida — todo pasa por triggers (SECURITY
-- DEFINER, bypasan RLS) o por las RPC de la sección siguiente (también
-- SECURITY DEFINER, acotadas siempre a auth.uid()).
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = recipient_id);

CREATE POLICY "No direct user insert into notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (false);

CREATE POLICY "No direct user update on notifications"
  ON public.notifications FOR UPDATE
  USING (false);

CREATE POLICY "No direct user delete on notifications"
  ON public.notifications FOR DELETE
  USING (false);

-- Necesario para que los cambios en esta tabla lleguen por Realtime
-- (postgres_changes) a los clientes suscritos. Sigue el mismo patrón que
-- la migración 20260730000002_enable_realtime_steam_jobs.sql.
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ═════════════════════════════════════════════════════════════════════════
-- Triggers: creación de notificaciones
-- ═════════════════════════════════════════════════════════════════════════

-- ─── LIKE ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_review_like() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
DECLARE
  v_owner uuid;
  v_game_title text;
  v_game_cover text;
BEGIN
  SELECT r.user_id, g.title, g.cover_url
    INTO v_owner, v_game_title, v_game_cover
  FROM public.reviews r
  LEFT JOIN public.games g ON g.igdb_id = r.game_id
  WHERE r.id = NEW.review_id;

  IF v_owner IS NULL OR v_owner = NEW.user_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (recipient_id, actor_id, type, review_id, metadata)
  VALUES (
    v_owner,
    NEW.user_id,
    'like',
    NEW.review_id,
    jsonb_build_object('game_title', v_game_title, 'game_cover_url', v_game_cover)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_review_like
  AFTER INSERT ON public.review_likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_review_like();

CREATE OR REPLACE FUNCTION public.notify_review_unlike() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
BEGIN
  DELETE FROM public.notifications
  WHERE type = 'like'
    AND actor_id = OLD.user_id
    AND review_id = OLD.review_id;
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_notify_review_unlike
  AFTER DELETE ON public.review_likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_review_unlike();

-- ─── COMENTARIO (de primer nivel) Y RESPUESTA (dentro de un hilo) ───────
CREATE OR REPLACE FUNCTION public.notify_review_comment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
DECLARE
  v_recipient uuid;
  v_type text;
  v_game_title text;
  v_snippet text;
BEGIN
  v_snippet := left(coalesce(NEW.content, ''), 140);

  IF NEW.parent_comment_id IS NULL THEN
    -- Comentario de primer nivel → notifica al autor de la reseña.
    v_type := 'comment';
    SELECT r.user_id, g.title INTO v_recipient, v_game_title
    FROM public.reviews r
    LEFT JOIN public.games g ON g.igdb_id = r.game_id
    WHERE r.id = NEW.review_id;
  ELSE
    -- Respuesta dentro de un hilo → notifica al autor del comentario padre.
    v_type := 'reply';
    SELECT c.user_id INTO v_recipient
    FROM public.review_comments c
    WHERE c.id = NEW.parent_comment_id;

    SELECT g.title INTO v_game_title
    FROM public.reviews r
    LEFT JOIN public.games g ON g.igdb_id = r.game_id
    WHERE r.id = NEW.review_id;
  END IF;

  IF v_recipient IS NULL OR v_recipient = NEW.user_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications
    (recipient_id, actor_id, type, review_id, comment_id, metadata)
  VALUES (
    v_recipient,
    NEW.user_id,
    v_type,
    NEW.review_id,
    NEW.id,
    jsonb_build_object('game_title', v_game_title, 'comment_snippet', v_snippet)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_review_comment
  AFTER INSERT ON public.review_comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_review_comment();

-- (Borrar un comentario limpia su notificación automáticamente vía la FK
-- notifications.comment_id ON DELETE CASCADE — no hace falta trigger.)

-- ─── SOLICITUD DE AMISTAD: nueva, aceptada, retirada/rechazada ─────────
CREATE OR REPLACE FUNCTION public.notify_friend_request() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
BEGIN
  IF NEW.status = 'pending' THEN
    INSERT INTO public.notifications (recipient_id, actor_id, type, metadata)
    VALUES (NEW.addressee_id, NEW.requester_id, 'friend_request', '{}'::jsonb);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_friend_request
  AFTER INSERT ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friend_request();

CREATE OR REPLACE FUNCTION public.notify_friend_request_response() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    DELETE FROM public.notifications
    WHERE type = 'friend_request'
      AND recipient_id = NEW.addressee_id
      AND actor_id = NEW.requester_id;

    INSERT INTO public.notifications (recipient_id, actor_id, type, metadata)
    VALUES (NEW.requester_id, NEW.addressee_id, 'friend_request_accepted', '{}'::jsonb);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_friend_request_response
  AFTER UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friend_request_response();

CREATE OR REPLACE FUNCTION public.notify_friend_request_removed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
BEGIN
  IF OLD.status = 'pending' THEN
    DELETE FROM public.notifications
    WHERE type = 'friend_request'
      AND recipient_id = OLD.addressee_id
      AND actor_id = OLD.requester_id;
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_notify_friend_request_removed
  AFTER DELETE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.notify_friend_request_removed();

-- ═════════════════════════════════════════════════════════════════════════
-- RPCs para el cliente: contar no-leídas y marcar como leídas.
--
-- SECURITY DEFINER + siempre acotadas a auth.uid() internamente (nunca
-- reciben un user_id como parámetro), así que son seguras aunque la tabla
-- no tenga policy de UPDATE para usuarios normales.
-- ═════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_unread_notifications_count()
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM public.notifications
  WHERE recipient_id = auth.uid()
    AND read_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.notifications
  SET read_at = now()
  WHERE recipient_id = auth.uid()
    AND read_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.notifications
  SET read_at = now()
  WHERE id = p_notification_id
    AND recipient_id = auth.uid()
    AND read_at IS NULL;
$$;
