-- 1. Arreglamos el trigger de comentarios para incluir el cover del juego

CREATE OR REPLACE FUNCTION public.notify_review_comment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
    AS $$
DECLARE
  v_recipient uuid;
  v_type text;
  v_game_title text;
  v_game_cover text;
  v_snippet text;
BEGIN
  v_snippet := left(coalesce(NEW.content, ''), 140);

  IF NEW.parent_comment_id IS NULL THEN
    -- Comentario de primer nivel → notifica al autor de la reseña.
    v_type := 'comment';
    SELECT r.user_id, g.title, g.cover_url INTO v_recipient, v_game_title, v_game_cover
    FROM public.reviews r
    LEFT JOIN public.games g ON g.igdb_id = r.game_id
    WHERE r.id = NEW.review_id;
  ELSE
    -- Respuesta dentro de un hilo → notifica al autor del comentario padre.
    v_type := 'reply';
    SELECT c.user_id INTO v_recipient
    FROM public.review_comments c
    WHERE c.id = NEW.parent_comment_id;

    SELECT g.title, g.cover_url INTO v_game_title, v_game_cover
    FROM public.reviews r
    LEFT JOIN public.games g ON g.igdb_id = r.game_id
    WHERE r.id = NEW.review_id;
  END IF;

  IF v_recipient IS NULL OR v_recipient = NEW.user_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications
    (recipient_id, actor_id, type, review_id, comment_id, metadata, created_at)
  VALUES (
    v_recipient,
    NEW.user_id,
    v_type,
    NEW.review_id,
    NEW.id,
    jsonb_build_object('game_title', v_game_title, 'game_cover_url', v_game_cover, 'comment_snippet', v_snippet),
    NEW.created_at
  );

  RETURN NEW;
END;
$$;


-- 2. Hacemos el backfill de notificaciones pasadas
-- Como es backfill histórico, marcamos todo lo anterior a hoy como leído para no saturar al usuario con un badge gigante.

-- Backfill: Likes
INSERT INTO public.notifications (recipient_id, actor_id, type, review_id, metadata, created_at, read_at)
SELECT 
    r.user_id AS recipient_id,
    rl.user_id AS actor_id,
    'like' AS type,
    rl.review_id,
    jsonb_build_object('game_title', g.title, 'game_cover_url', g.cover_url) AS metadata,
    rl.created_at,
    rl.created_at AS read_at -- marcamos como leídas
FROM public.review_likes rl
JOIN public.reviews r ON r.id = rl.review_id
LEFT JOIN public.games g ON g.igdb_id = r.game_id
WHERE r.user_id != rl.user_id
ON CONFLICT DO NOTHING;

-- Backfill: Comentarios de primer nivel
INSERT INTO public.notifications (recipient_id, actor_id, type, review_id, comment_id, metadata, created_at, read_at)
SELECT 
    r.user_id AS recipient_id,
    rc.user_id AS actor_id,
    'comment' AS type,
    rc.review_id,
    rc.id AS comment_id,
    jsonb_build_object('game_title', g.title, 'game_cover_url', g.cover_url, 'comment_snippet', left(coalesce(rc.content, ''), 140)) AS metadata,
    rc.created_at,
    rc.created_at AS read_at
FROM public.review_comments rc
JOIN public.reviews r ON r.id = rc.review_id
LEFT JOIN public.games g ON g.igdb_id = r.game_id
WHERE rc.parent_comment_id IS NULL AND r.user_id != rc.user_id
ON CONFLICT DO NOTHING;

-- Backfill: Respuestas a comentarios
INSERT INTO public.notifications (recipient_id, actor_id, type, review_id, comment_id, metadata, created_at, read_at)
SELECT 
    parent.user_id AS recipient_id,
    rc.user_id AS actor_id,
    'reply' AS type,
    rc.review_id,
    rc.id AS comment_id,
    jsonb_build_object('game_title', g.title, 'game_cover_url', g.cover_url, 'comment_snippet', left(coalesce(rc.content, ''), 140)) AS metadata,
    rc.created_at,
    rc.created_at AS read_at
FROM public.review_comments rc
JOIN public.review_comments parent ON parent.id = rc.parent_comment_id
JOIN public.reviews r ON r.id = rc.review_id
LEFT JOIN public.games g ON g.igdb_id = r.game_id
WHERE rc.parent_comment_id IS NOT NULL AND parent.user_id != rc.user_id
ON CONFLICT DO NOTHING;

-- Backfill: Solicitudes de amistad aceptadas
INSERT INTO public.notifications (recipient_id, actor_id, type, metadata, created_at, read_at)
SELECT 
    requester_id AS recipient_id,
    addressee_id AS actor_id,
    'friend_request_accepted' AS type,
    '{}'::jsonb AS metadata,
    created_at,
    created_at AS read_at
FROM public.friendships
WHERE status = 'accepted'
ON CONFLICT DO NOTHING;

-- Backfill: Solicitudes de amistad pendientes
INSERT INTO public.notifications (recipient_id, actor_id, type, metadata, created_at, read_at)
SELECT 
    addressee_id AS recipient_id,
    requester_id AS actor_id,
    'friend_request' AS type,
    '{}'::jsonb AS metadata,
    created_at,
    created_at AS read_at
FROM public.friendships
WHERE status = 'pending'
ON CONFLICT DO NOTHING;
