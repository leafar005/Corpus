-- Nuevo archivo: supabase/migrations/20260818000001_restore_library_xp.sql

CREATE OR REPLACE FUNCTION public.calculate_user_xp(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    library_xp integer := 0;
    reviews_xp integer := 0;
    achievements_xp integer := 0;
    total_xp integer := 0;
BEGIN
    -- 1. XP por juegos en biblioteca (una vez por juego, independientemente de si
    --    tiene reseña o cuántas reseñas/replays tenga).
    SELECT COALESCE(SUM(
        CASE
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir juego a biblioteca: 5 XP
        END
    ), 0) INTO library_xp
    FROM public.user_games
    WHERE user_id = uid;

    -- 2. XP por reseñas escritas y bonus de 100% (una vez por reseña).
    SELECT COALESCE(SUM(
        CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END
        + CASE WHEN completion_type IN ('100%', '100_percent') THEN 50 ELSE 0 END
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- 3. XP por logros desbloqueados.
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;

    -- 4. 50 XP base por crear la cuenta.
    total_xp := library_xp + reviews_xp + achievements_xp + 50;

    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;

-- Recalcular XP de todos los usuarios existentes con la fórmula corregida.
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT id FROM auth.users LOOP
        PERFORM public.calculate_user_xp(r.id);
    END LOOP;
END $$;
