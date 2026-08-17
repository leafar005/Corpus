-- =============================================================================
-- Cleanup: eliminar trigger muerto + deduplicar status_change en activity_feed
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Eliminar touch_review_updated_at (codigo muerto)
--    Se creo para alimentar el feed con reviews.updated_at, pero desde
--    20260818000010 el feed usa reviews.created_at. Nada lee updated_at.
-- ─────────────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_review_touch_updated_at ON public.reviews;
DROP FUNCTION IF EXISTS public.touch_review_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Deduplicar on_user_game_status_change
--    Problema: cada INSERT/UPDATE en user_games genera un INSERT ciego en
--    activity_feed sin control de duplicados. Si sync_user_games hace un
--    upsert que no cambia el status, el trigger aun asi evalua la condicion
--    y puede generar duplicados (ej. re-guardar la misma resena).
--
--    Fix: antes de insertar, comprobar si ya existe un status_change
--    identico (mismo user, game, status) en los ultimos 5 minutos.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    latest_review_id uuid;
    already_exists boolean;
BEGIN
    IF (TG_OP = 'INSERT') OR (OLD.status IS DISTINCT FROM NEW.status) THEN
        -- Dedup: no crear entrada si ya existe una identica reciente (5 min)
        SELECT EXISTS (
            SELECT 1 FROM public.activity_feed
            WHERE user_id = NEW.user_id
              AND game_id = NEW.game_id
              AND action_type = 'status_change'
              AND (metadata->>'status') = NEW.status::text
              AND created_at > now() - interval '5 minutes'
        ) INTO already_exists;

        IF already_exists THEN
            RETURN NEW;
        END IF;

        SELECT id INTO latest_review_id
        FROM public.reviews
        WHERE user_id = NEW.user_id AND game_id = NEW.game_id
        ORDER BY created_at DESC
        LIMIT 1;

        INSERT INTO public.activity_feed (user_id, action_type, game_id, review_id, metadata, created_at)
        VALUES (
            NEW.user_id, 'status_change', NEW.game_id, latest_review_id,
            jsonb_build_object('status', NEW.status),
            now()
        );
    END IF;
    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Backfill: limpiar status_change duplicados ya existentes.
--    Para cada (user_id, game_id, status), conservar solo la entrada mas
--    reciente y borrar las anteriores.
-- ─────────────────────────────────────────────────────────────────────────────

DELETE FROM public.activity_feed a
USING (
    SELECT id, ROW_NUMBER() OVER (
        PARTITION BY user_id, game_id, metadata->>'status'
        ORDER BY created_at DESC
    ) AS rn
    FROM public.activity_feed
    WHERE action_type = 'status_change'
) ranked
WHERE a.id = ranked.id
  AND ranked.rn > 1;
