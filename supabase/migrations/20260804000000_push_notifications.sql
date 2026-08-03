-- ─────────────────────────────────────────────────────────────────────────────
-- Push Notifications: tablas de tokens FCM y preferencias de notificación
-- ─────────────────────────────────────────────────────────────────────────────

-- Tabla para guardar los tokens FCM de cada dispositivo registrado por usuario
CREATE TABLE IF NOT EXISTS public.push_tokens (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token       text NOT NULL,
    platform    text NOT NULL CHECK (platform IN ('android', 'windows')),
    created_at  timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT push_tokens_token_unique UNIQUE (token)
);

COMMENT ON TABLE public.push_tokens IS 'FCM device tokens for push notifications. One token per device.';

-- Tabla de preferencias de notificación por usuario (un registro por usuario)
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id               uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    friend_started_playing boolean DEFAULT true NOT NULL,
    friend_finished_game   boolean DEFAULT true NOT NULL,
    new_bundle             boolean DEFAULT true NOT NULL,
    bundle_expiring        boolean DEFAULT true NOT NULL,
    comment_on_review      boolean DEFAULT true NOT NULL,
    reply_to_comment       boolean DEFAULT true NOT NULL,
    updated_at             timestamptz DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.notification_preferences IS 'Per-user notification preferences with individual toggles.';

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- push_tokens: el usuario solo puede ver/gestionar sus propios tokens
CREATE POLICY "user owns their push tokens"
    ON public.push_tokens FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role puede leer todos los tokens para enviar notificaciones
CREATE POLICY "service role reads all tokens"
    ON public.push_tokens FOR SELECT
    USING (auth.role() = 'service_role');

-- notification_preferences: el usuario gestiona sus propias preferencias
CREATE POLICY "user owns their notification preferences"
    ON public.notification_preferences FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role puede leer preferencias para filtrar a quién notificar
CREATE POLICY "service role reads all preferences"
    ON public.notification_preferences FOR SELECT
    USING (auth.role() = 'service_role');

-- ─────────────────────────────────────────────────────────────────────────────
-- Índices
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS push_tokens_user_id_idx ON public.push_tokens (user_id);
CREATE INDEX IF NOT EXISTS notification_preferences_user_id_idx ON public.notification_preferences (user_id);
