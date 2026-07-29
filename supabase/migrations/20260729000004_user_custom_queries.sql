ALTER TABLE public.review_comments ALTER COLUMN content DROP NOT NULL;

-- Usamos un bloque anónimo para añadir la columna de forma segura si no existe, 
-- o puedes usar IF NOT EXISTS si tu versión de Postgres lo soporta directamente en el ADD COLUMN.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'reviews' AND column_name = 'partner_id'
    ) THEN
        ALTER TABLE public.reviews ADD COLUMN partner_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.calculate_user_xp(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    reviews_xp integer := 0;
    achievements_xp integer := 0;
    total_xp integer := 0;
BEGIN
    -- 1. XP por juegos en biblioteca y reseñas escritas (Guía "¿Cómo ganar XP?")
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir juego a tu biblioteca (wishlist, playing, dropped, abandoned...): 5 XP
        END
        + CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END -- Escribir una reseña: 10 XP
        + CASE WHEN completion_type IN ('100%', '100_percent') THEN 50 ELSE 0 END        -- Bonus por completado 100%: 50 XP
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- 2. XP por logros desbloqueados (Variable según la suma de xp_reward del logro)
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- 3. Añadimos 50 XP base por crear la cuenta (siempre)
    total_xp := reviews_xp + achievements_xp + 50;

    -- Actualizamos los XP del usuario en la tabla users
    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;
