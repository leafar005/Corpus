-- Arreglar el bug de 100_percent vs 100%
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
    -- XP por juegos en biblioteca (tabla user_games)
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir juego a tu biblioteca (wishlist, playing, dropped, abandoned...): 5 XP
        END
    ), 0) INTO library_xp
    FROM public.user_games
    WHERE user_id = uid;

    -- XP por reseñas escritas y bonus de 100%
    SELECT COALESCE(SUM(
        CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END -- Escribir una reseña: 10 XP
        + CASE WHEN completion_type = '100_percent' THEN 50 ELSE 0 END                 -- Bonus por 100%: 50 XP
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- XP por logros desbloqueados (Variable según suma de xp_reward)
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- 50 XP base por crear la cuenta (siempre presentes)
    total_xp := library_xp + reviews_xp + achievements_xp + 50;

    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;
