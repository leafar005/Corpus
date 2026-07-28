-- =====================================================================
-- CORPUS: QUICK WINS MIGRATION
-- Aplica: bugfix calculate_user_xp + índices de rendimiento
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- 1. BUGFIX: 'dropped' no existe en game_status enum → corregir a 'abandoned'
--    IMPORTANTE: usamos CASCADE porque el trigger_review_gamification depende
--    de esta función. El CASCADE borra la cadena entera y la recreamos abajo.
-- ─────────────────────────────────────────────────────────────────────

-- Paso 1: Borrar con CASCADE (elimina también trigger_review_gamification
--         y el trigger on_review_changed_gamification que dependen de ella)
DROP FUNCTION IF EXISTS public.calculate_user_xp(uuid) CASCADE;

-- Paso 2: Recrear la función con la firma original (RETURNS void) y el fix
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

-- Paso 3: Recrear la función de trigger (puede haberse borrado por CASCADE)
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

    PERFORM calculate_user_xp(target_uid);
    PERFORM check_user_achievements(target_uid);

    RETURN NULL;
END;
$$;

-- Paso 4: Recrear el trigger (puede haberse borrado por CASCADE)
DROP TRIGGER IF EXISTS on_review_changed_gamification ON public.reviews;
CREATE TRIGGER on_review_changed_gamification
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.trigger_review_gamification();

-- ─────────────────────────────────────────────────────────────────────
-- 2. ÍNDICES DE RENDIMIENTO
--    Todos usan IF NOT EXISTS — seguros de ejecutar varias veces
-- ─────────────────────────────────────────────────────────────────────

-- 2a. Friendships: acelera el EXISTS de la RLS policy en activity_feed
--     Sin estos, la policy hace O(n) por cada fila del feed
CREATE INDEX IF NOT EXISTS idx_friendships_req_status
  ON friendships(requester_id, status);

CREATE INDEX IF NOT EXISTS idx_friendships_addr_status
  ON friendships(addressee_id, status);

-- 2b. Reviews: queries por juego ordenadas por fecha (pantalla de detalles)
CREATE INDEX IF NOT EXISTS idx_reviews_game_created
  ON reviews(game_id, created_at DESC);

-- 2c. Stash community reviews: filtrado por juego
CREATE INDEX IF NOT EXISTS idx_stash_reviews_game_id
  ON stash_community_reviews(game_id);

-- 2d. User games: ordenar por última actualización (perfil del usuario)
CREATE INDEX IF NOT EXISTS idx_user_games_updated
  ON user_games(user_id, updated_at DESC);

-- 2e. Activity feed: compound index para merge de eventos
CREATE INDEX IF NOT EXISTS idx_activity_feed_compound
  ON activity_feed(user_id, game_id, created_at DESC);
