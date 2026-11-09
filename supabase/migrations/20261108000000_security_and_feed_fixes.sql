-- =============================================================================
-- Migración: Endurecimiento de seguridad (SEC-02, SEC-04, SEC-05) y fix de feed
-- para estado 'to_play' (DAT-03).
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. SEC-04: Proteger columna `xp` en `public.users` frente a edición directa
-- ─────────────────────────────────────────────────────────────────────────────
-- La función `public.calculate_user_xp(uid)` es SECURITY DEFINER (se ejecuta
-- como `postgres`), por lo que cuando el servidor recalcula el XP, `current_user`
-- no es `authenticated` ni `anon`. Si un cliente intenta modificar `xp`
-- directamente vía PostgREST (`PATCH /rest/v1/users`), el trigger preserva el
-- valor anterior de `xp` sin romper actualizaciones legítimas del perfil.

CREATE OR REPLACE FUNCTION public.protect_user_xp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF current_user IN ('authenticated', 'anon')
       AND NEW.xp IS DISTINCT FROM OLD.xp THEN
        NEW.xp := OLD.xp;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_xp ON public.users;
CREATE TRIGGER trg_protect_user_xp
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_user_xp();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. SEC-02: Restringir políticas de Storage en `avatars` y `banners` al dueño
-- ─────────────────────────────────────────────────────────────────────────────
-- El cliente sube avatares y banners siempre bajo la ruta `<userId>/<ts>.<ext>`
-- (`edit_profile_screen.dart`). Se exige que la carpeta raíz coincida con
-- `auth.uid()` (o que `owner = auth.uid()` para objetos existentes).

DROP POLICY IF EXISTS "Avatars Upload Policy" ON storage.objects;
CREATE POLICY "Avatars Upload Policy" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Avatars Update Policy" ON storage.objects;
CREATE POLICY "Avatars Update Policy" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR owner = auth.uid()
    )
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Avatars Delete Policy" ON storage.objects;
CREATE POLICY "Avatars Delete Policy" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR owner = auth.uid()
    )
);

DROP POLICY IF EXISTS "Banners Upload Policy" ON storage.objects;
CREATE POLICY "Banners Upload Policy" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'banners'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Banners Update Policy" ON storage.objects;
CREATE POLICY "Banners Update Policy" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'banners'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR owner = auth.uid()
    )
)
WITH CHECK (
    bucket_id = 'banners'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Banners Delete Policy" ON storage.objects;
CREATE POLICY "Banners Delete Policy" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'banners'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR owner = auth.uid()
    )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DAT-03 + SEC-05: Incluir 'to_play' en `on_review_upsert` y fijar search_path
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.on_review_upsert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Wishlist, playing y to_play no son reseñas finalizadas: su presencia en
    -- el feed la gestiona on_user_game_status_change con action_type='status_change'.
    IF NEW.status IN ('wishlist', 'playing', 'to_play') THEN
        DELETE FROM public.activity_feed
        WHERE review_id = NEW.id
          AND action_type = 'reviewed';
        RETURN NEW;
    END IF;

    INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
    VALUES (
        NEW.user_id, 'reviewed', NEW.game_id, NEW.id,
        jsonb_build_object('rating', NEW.rating, 'comment', NEW.comment, 'review_id', NEW.id),
        COALESCE(NEW.created_at, now())
    )
    ON CONFLICT (review_id) WHERE action_type = 'reviewed' AND review_id IS NOT NULL
    DO UPDATE SET
        game_id    = EXCLUDED.game_id,
        metadata   = EXCLUDED.metadata,
        created_at = EXCLUDED.created_at;
    RETURN NEW;
END;
$$;

-- Limpiar posibles entradas 'reviewed' duplicadas para juegos en 'to_play'
DELETE FROM public.activity_feed af
USING public.reviews r
WHERE af.review_id = r.id
  AND af.action_type = 'reviewed'
  AND r.status IN ('wishlist', 'playing', 'to_play');

