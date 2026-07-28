-- Script completo para implementar el Sistema de Progresión y Logros (Gamificación)

-- 1. Crear la tabla del catálogo de logros
CREATE TABLE IF NOT EXISTS public.achievements (
    id text PRIMARY KEY,
    name text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    xp_reward integer NOT NULL DEFAULT 0,
    rarity text NOT NULL,
    icon_name text NOT NULL
);

-- Habilitar RLS en achievements
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Logros son públicos" ON public.achievements FOR SELECT USING (true);

-- 2. Crear la tabla de logros desbloqueados por los usuarios
CREATE TABLE IF NOT EXISTS public.user_achievements (
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id text REFERENCES public.achievements(id) ON DELETE CASCADE,
    unlocked_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (user_id, achievement_id)
);

-- Habilitar RLS en user_achievements
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Usuarios pueden ver todos los logros desbloqueados" ON public.user_achievements FOR SELECT USING (true);
CREATE POLICY "Trigger maneja user_achievements" ON public.user_achievements FOR ALL USING (auth.uid() = user_id);

-- 3. Añadir columna XP a perfiles
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='xp') THEN
        ALTER TABLE public.users ADD COLUMN xp integer DEFAULT 0 NOT NULL;
    END IF;
END $$;

-- 4. Insertar los logros del diseño
INSERT INTO public.achievements (id, name, description, category, xp_reward, rarity, icon_name) VALUES
('time_traveler', 'Viajero del Tiempo', 'Registra y completa tu primer juego con fecha de lanzamiento retro (antes del año 2000).', 'history', 50, 'Fácil', 'hourglass_empty'),
('scholar_20th', 'Erudito del Siglo XX', 'Adquiere un profundo conocimiento completando 20 juegos lanzados antes del año 2000.', 'history', 150, 'Medio', 'menu_book'),
('vanguard', 'Vanguardia Absoluta', 'Demuestra estar a la última moda registrando 10 juegos en su mismo año exacto de lanzamiento.', 'history', 150, 'Medio', 'rocket_launch'),
('nintendo_loyalty', 'Lealtad a Kioto', 'Completa 25 juegos de consolas de Nintendo.', 'platforms', 150, 'Medio', 'gamepad'),
('pc_master_race', 'Aristocracia del Silicio', 'Abraza el PC Gaming completando 50 juegos jugados en ordenador (PC/Windows).', 'platforms', 500, 'Épico', 'computer'),
('multiplatform', 'Guerrero Multiplataforma', 'Demuestra un alcance global completando juegos en 15 plataformas de hardware distintas.', 'platforms', 500, 'Épico', 'devices'),
('rpg_veteran', 'Rolero Veterano', 'Invierte tu tiempo completando 30 títulos masivos de rol (RPG).', 'genres', 150, 'Medio', 'swords'),
('eclectic', 'Sibarita Ecléctico', 'Alcanza la iluminación lúdica completando juegos de 15 géneros radicalmente diferentes.', 'genres', 500, 'Épico', 'category'),
('lone_wolf', 'Lobo Solitario', 'Completa 50 juegos de un solo jugador (Single Player).', 'genres', 150, 'Medio', 'person'),
('kojima', 'Devoto de Kojima', 'Registra 5 juegos desarrollados por Kojima Productions.', 'companies', 150, 'Medio', 'visibility')
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name, description = EXCLUDED.description, 
    xp_reward = EXCLUDED.xp_reward, rarity = EXCLUDED.rarity;

-- 5. Función para recalcular XP
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
    -- XP por juegos en biblioteca y reseñas (Ajustado a la guía "¿Cómo ganar XP?")
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir un juego a tu biblioteca (wishlist, playing, dropped, abandoned...): 5 XP
        END
        + CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END -- Escribir una reseña: 10 XP
        + CASE WHEN completion_type = '100%' THEN 50 ELSE 0 END                          -- Bonus por 100%: 50 XP
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- XP por logros desbloqueados (Variable según suma de xp_reward)
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- 50 XP base por crear la cuenta (siempre presentes)
    total_xp := reviews_xp + achievements_xp + 50;

    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;

-- 6. Función pura de validación de logros (Evalúa, borra los no cumplidos e inserta los nuevos)
CREATE OR REPLACE FUNCTION public.check_user_achievements(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    valid_ids text[] := ARRAY[]::text[];
BEGIN
    -- 1. Viajero del tiempo
    IF EXISTS (SELECT 1 FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') THEN
        valid_ids := array_append(valid_ids, 'time_traveler');
    END IF;
    -- 2. Erudito del siglo XX
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') >= 20 THEN
        valid_ids := array_append(valid_ids, 'scholar_20th');
    END IF;
    -- 3. Vanguardia
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND extract(year from r.created_at) = extract(year from g.release_date::date)) >= 10 THEN
        valid_ids := array_append(valid_ids, 'vanguard');
    END IF;
    -- 4. Lealtad Nintendo
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.platforms::text ILIKE '%Nintendo%') >= 25 THEN
        valid_ids := array_append(valid_ids, 'nintendo_loyalty');
    END IF;
    -- 5. PC Master Race (usando la plataforma elegida por el usuario o la del juego)
    IF (SELECT count(*) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'pc_master_race');
    END IF;
    -- 6. Multiplataforma
    IF (
        SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL
    ) >= 15 THEN
        valid_ids := array_append(valid_ids, 'multiplatform');
    END IF;
    -- 7. Rolero veterano
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.genres::text ILIKE '%Role-playing%') >= 30 THEN
        valid_ids := array_append(valid_ids, 'rpg_veteran');
    END IF;
    -- 8. Lobo solitario
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.game_modes::text ILIKE '%Single player%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'lone_wolf');
    END IF;
    -- 9. Kojima
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND g.developer ILIKE '%Kojima%') >= 5 THEN
        valid_ids := array_append(valid_ids, 'kojima');
    END IF;

    -- ELIMINAR los logros que ya no se cumplen
    DELETE FROM public.user_achievements 
    WHERE user_id = uid AND achievement_id != ALL(valid_ids);

    -- INSERTAR los que se cumplen (ignorando los que ya estaban para mantener su fecha)
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT uid, unnest(valid_ids)
    ON CONFLICT (user_id, achievement_id) DO NOTHING;
END;
$$;

-- 7. Trigger maestro
CREATE OR REPLACE FUNCTION public.trigger_review_gamification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_uid uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_uid := OLD.user_id;
    ELSE
        target_uid := NEW.user_id;
    END IF;
    
    -- Computar asíncronamente o en el mismo hilo de la transacción
    PERFORM calculate_user_xp(target_uid);
    PERFORM check_user_achievements(target_uid);
    
    RETURN NULL; -- AFTER trigger
END;
$$;

DROP TRIGGER IF EXISTS on_review_changed_gamification ON public.reviews;
CREATE TRIGGER on_review_changed_gamification
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.trigger_review_gamification();

-- Opcional: Para forzar el cálculo inicial de todos los usuarios actuales
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT user_id FROM public.reviews LOOP
        PERFORM calculate_user_xp(r.user_id);
        PERFORM check_user_achievements(r.user_id);
    END LOOP;
END $$;
