-- =========================================================================
-- CORPUS: FASE SOCIAL - AMIGOS Y FEED DE ACTIVIDAD
-- =========================================================================

-- 1. Tabla de amistades (relaciones 1 a 1)
CREATE TABLE IF NOT EXISTS public.friendships (
    requester_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    addressee_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (requester_id, addressee_id),
    CONSTRAINT no_self_friend CHECK (requester_id <> addressee_id)
);

-- Índices para consultas eficientes
CREATE INDEX IF NOT EXISTS friendships_addressee_idx ON public.friendships (addressee_id);
CREATE INDEX IF NOT EXISTS friendships_status_idx    ON public.friendships (status);

-- 2. Feed de actividad
CREATE TABLE IF NOT EXISTS public.activity_feed (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN ('status_change', 'reviewed', 'achievement')),
    game_id     INTEGER REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    metadata    JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices para el feed
CREATE INDEX IF NOT EXISTS activity_feed_user_idx    ON public.activity_feed (user_id);
CREATE INDEX IF NOT EXISTS activity_feed_created_idx ON public.activity_feed (created_at DESC);

-- =========================================================================
-- TRIGGERS para poblar el feed automáticamente
-- =========================================================================

-- Función: insertar evento cuando cambia el estado de un juego
CREATE OR REPLACE FUNCTION public.on_user_game_status_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- Solo registramos si el estado realmente cambió o es una inserción nueva
    IF (TG_OP = 'INSERT') OR (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.activity_feed (user_id, action_type, game_id, metadata)
        VALUES (
            NEW.user_id,
            'status_change',
            NEW.game_id,
            jsonb_build_object('status', NEW.status)
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_user_game_status_change
AFTER INSERT OR UPDATE ON public.user_games
FOR EACH ROW EXECUTE FUNCTION public.on_user_game_status_change();


-- Función: insertar evento cuando se crea o actualiza una reseña
CREATE OR REPLACE FUNCTION public.on_review_upsert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.activity_feed (user_id, action_type, game_id, metadata)
    VALUES (
        NEW.user_id,
        'reviewed',
        NEW.game_id,
        jsonb_build_object(
            'rating',        NEW.rating,
            'comment',       NEW.comment,
            'review_id',     NEW.id
        )
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_review_upsert
AFTER INSERT ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.on_review_upsert();


-- =========================================================================
-- ROW LEVEL SECURITY (RLS)
-- =========================================================================

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

-- Friendships: puedes ver tus propias solicitudes y las que te llegaron
CREATE POLICY "Users can view their own friendships"
    ON public.friendships FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Friendships: solo puedes crear solicitudes siendo el requester
CREATE POLICY "Users can send friend requests"
    ON public.friendships FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

-- Friendships: solo el addressee puede aceptar (UPDATE status)
-- y cualquiera de los dos puede borrar (cancelar/eliminar amistad)
CREATE POLICY "Users can update friendships they are part of"
    ON public.friendships FOR UPDATE
    USING (auth.uid() = addressee_id);

CREATE POLICY "Users can delete friendships they are part of"
    ON public.friendships FOR DELETE
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Activity feed: puedes ver tu propia actividad y la de tus amigos aceptados
CREATE POLICY "Users can view their own and friends activity"
    ON public.activity_feed FOR SELECT
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE f.status = 'accepted'
              AND (
                    (f.requester_id = auth.uid() AND f.addressee_id = activity_feed.user_id)
                 OR (f.addressee_id = auth.uid() AND f.requester_id = activity_feed.user_id)
              )
        )
    );

-- Activity feed: solo el trigger (SECURITY DEFINER) inserta; los usuarios no insertan directamente
CREATE POLICY "No direct user insert into activity_feed"
    ON public.activity_feed FOR INSERT
    WITH CHECK (false);

-- =========================================================================
-- Habilitar Realtime para el feed
-- =========================================================================
-- Ejecutar en el panel de Supabase o con el CLI:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_feed;
