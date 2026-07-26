-- =====================================================================
-- CORPUS: CÁLCULO DE LOGROS Y XP DEFINITIVO (v6)
-- Reconstruye la función que usa el Trigger y recalcula todo el XP
-- =====================================================================

-- 1. Eliminar la función sin parámetros por si se creó accidentalmente
DROP FUNCTION IF EXISTS public.check_user_achievements();

-- 2. Reescribir la función real que SÍ usa el trigger (la que recibe uuid)
CREATE OR REPLACE FUNCTION public.check_user_achievements(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    valid_ids text[] := ARRAY[]::text[];
    
    -- Compañías
    v_kojima_count INT;
    v_fromsoftware_count INT;
    v_nintendo_count INT;
    v_capcom_count INT;
    v_naughty_dog_count INT;
    v_rockstar_count INT;
    v_cd_projekt_count INT;
    v_konami_count INT;
    v_valve_count INT;
    v_remedy_count INT;
    v_team_ninja_count INT;
    
    -- Colecciones
    v_zelda_count INT;
    v_mario_count INT;
    v_pokemon_count INT;
    v_re_count INT;
    v_ds_count INT;
    v_ac_count INT;
    v_ff_count INT;
    v_bioshock_count INT;
    v_borderlands_count INT;
    v_metro_count INT;
    v_dead_space_count INT;
    v_yakuza_count INT;
    v_xenoblade_count INT;
    v_persona_count INT;
BEGIN
    -- ---------------------------------------------------------
    -- LOGROS ORIGINALES (General)
    -- ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') THEN
        valid_ids := array_append(valid_ids, 'time_traveler');
    END IF;
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') >= 20 THEN
        valid_ids := array_append(valid_ids, 'scholar_20th');
    END IF;
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND extract(year from r.created_at) = extract(year from g.release_date::date)) >= 10 THEN
        valid_ids := array_append(valid_ids, 'vanguard');
    END IF;
    IF (SELECT count(*) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'pc_master_race');
    END IF;
    IF (SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL) >= 15 THEN
        valid_ids := array_append(valid_ids, 'multiplatform');
    END IF;
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.genres::text ILIKE '%Role-playing%') >= 30 THEN
        valid_ids := array_append(valid_ids, 'rpg_veteran');
    END IF;
    IF (SELECT count(*) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.game_modes::text ILIKE '%Single player%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'lone_wolf');
    END IF;

    -- ---------------------------------------------------------
    -- CONTEOS PARA SAGAS / COMPAÑÍAS
    -- ---------------------------------------------------------
    SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Kojima%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%FromSoftware%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Capcom%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Naughty Dog%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Rockstar%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%CD Projekt%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Konami%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Valve%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Remedy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%' OR g.collection::text ILIKE '%Elden Ring%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_yakuza_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_xenoblade_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_persona_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- ---------------------------------------------------------
    -- ASIGNACIÓN A VALID_IDS
    -- ---------------------------------------------------------
    -- Compañías
    IF v_kojima_count >= 1 THEN valid_ids := array_append(valid_ids, 'kojima_1'); END IF;
    IF v_kojima_count >= 3 THEN valid_ids := array_append(valid_ids, 'kojima_3'); END IF;
    IF v_kojima_count >= 5 THEN valid_ids := array_append(valid_ids, 'kojima_5'); END IF;

    IF v_fromsoftware_count >= 1 THEN valid_ids := array_append(valid_ids, 'fromsoftware_1'); END IF;
    IF v_fromsoftware_count >= 3 THEN valid_ids := array_append(valid_ids, 'fromsoftware_3'); END IF;
    IF v_fromsoftware_count >= 7 THEN valid_ids := array_append(valid_ids, 'fromsoftware_all'); END IF;

    IF v_nintendo_count >= 1 THEN valid_ids := array_append(valid_ids, 'nintendo_1'); END IF;
    IF v_nintendo_count >= 5 THEN valid_ids := array_append(valid_ids, 'nintendo_5'); END IF;
    IF v_nintendo_count >= 10 THEN valid_ids := array_append(valid_ids, 'nintendo_10'); END IF;

    IF v_capcom_count >= 1 THEN valid_ids := array_append(valid_ids, 'capcom_1'); END IF;
    IF v_capcom_count >= 5 THEN valid_ids := array_append(valid_ids, 'capcom_5'); END IF;
    IF v_capcom_count >= 10 THEN valid_ids := array_append(valid_ids, 'capcom_10'); END IF;

    IF v_naughty_dog_count >= 1 THEN valid_ids := array_append(valid_ids, 'naughty_dog_1'); END IF;
    IF v_naughty_dog_count >= 3 THEN valid_ids := array_append(valid_ids, 'naughty_dog_3'); END IF;
    IF v_naughty_dog_count >= 5 THEN valid_ids := array_append(valid_ids, 'naughty_dog_5'); END IF;

    IF v_rockstar_count >= 1 THEN valid_ids := array_append(valid_ids, 'rockstar_1'); END IF;
    IF v_rockstar_count >= 3 THEN valid_ids := array_append(valid_ids, 'rockstar_3'); END IF;

    IF v_cd_projekt_count >= 1 THEN valid_ids := array_append(valid_ids, 'cd_projekt_1'); END IF;
    IF v_cd_projekt_count >= 3 THEN valid_ids := array_append(valid_ids, 'cd_projekt_3'); END IF;

    IF v_konami_count >= 1 THEN valid_ids := array_append(valid_ids, 'konami_1'); END IF;
    IF v_konami_count >= 5 THEN valid_ids := array_append(valid_ids, 'konami_5'); END IF;

    IF v_valve_count >= 1 THEN valid_ids := array_append(valid_ids, 'valve_1'); END IF;
    IF v_valve_count >= 3 THEN valid_ids := array_append(valid_ids, 'valve_3'); END IF;

    IF v_remedy_count >= 1 THEN valid_ids := array_append(valid_ids, 'remedy_1'); END IF;
    IF v_remedy_count >= 3 THEN valid_ids := array_append(valid_ids, 'remedy_3'); END IF;

    IF v_team_ninja_count >= 1 THEN valid_ids := array_append(valid_ids, 'team_ninja_1'); END IF;
    IF v_team_ninja_count >= 5 THEN valid_ids := array_append(valid_ids, 'team_ninja_5'); END IF;

    -- Franquicias
    IF v_zelda_count >= 1 THEN valid_ids := array_append(valid_ids, 'zelda_1'); END IF;
    IF v_zelda_count >= 3 THEN valid_ids := array_append(valid_ids, 'zelda_3'); END IF;
    IF v_zelda_count >= 7 THEN valid_ids := array_append(valid_ids, 'zelda_all'); END IF;

    IF v_mario_count >= 1 THEN valid_ids := array_append(valid_ids, 'mario_1'); END IF;
    IF v_mario_count >= 5 THEN valid_ids := array_append(valid_ids, 'mario_5'); END IF;
    IF v_mario_count >= 10 THEN valid_ids := array_append(valid_ids, 'mario_10'); END IF;

    IF v_pokemon_count >= 1 THEN valid_ids := array_append(valid_ids, 'pokemon_1'); END IF;
    IF v_pokemon_count >= 3 THEN valid_ids := array_append(valid_ids, 'pokemon_3'); END IF;
    IF v_pokemon_count >= 5 THEN valid_ids := array_append(valid_ids, 'pokemon_5'); END IF;

    IF v_re_count >= 1 THEN valid_ids := array_append(valid_ids, 'resident_evil_1'); END IF;
    IF v_re_count >= 3 THEN valid_ids := array_append(valid_ids, 'resident_evil_3'); END IF;
    IF v_re_count >= 5 THEN valid_ids := array_append(valid_ids, 'resident_evil_5'); END IF;

    IF v_ds_count >= 1 THEN valid_ids := array_append(valid_ids, 'dark_souls_1'); END IF;
    IF v_ds_count >= 3 THEN valid_ids := array_append(valid_ids, 'dark_souls_all'); END IF;

    IF v_ac_count >= 1 THEN valid_ids := array_append(valid_ids, 'assassins_creed_1'); END IF;
    IF v_ac_count >= 3 THEN valid_ids := array_append(valid_ids, 'assassins_creed_3'); END IF;
    IF v_ac_count >= 6 THEN valid_ids := array_append(valid_ids, 'assassins_creed_6'); END IF;

    IF v_ff_count >= 1 THEN valid_ids := array_append(valid_ids, 'final_fantasy_1'); END IF;
    IF v_ff_count >= 3 THEN valid_ids := array_append(valid_ids, 'final_fantasy_3'); END IF;
    IF v_ff_count >= 5 THEN valid_ids := array_append(valid_ids, 'final_fantasy_5'); END IF;

    IF v_bioshock_count >= 1 THEN valid_ids := array_append(valid_ids, 'bioshock_1'); END IF;
    IF v_bioshock_count >= 3 THEN valid_ids := array_append(valid_ids, 'bioshock_3'); END IF;

    IF v_borderlands_count >= 1 THEN valid_ids := array_append(valid_ids, 'borderlands_1'); END IF;
    IF v_borderlands_count >= 3 THEN valid_ids := array_append(valid_ids, 'borderlands_3'); END IF;

    IF v_metro_count >= 1 THEN valid_ids := array_append(valid_ids, 'metro_1'); END IF;
    IF v_metro_count >= 3 THEN valid_ids := array_append(valid_ids, 'metro_3'); END IF;

    IF v_dead_space_count >= 1 THEN valid_ids := array_append(valid_ids, 'dead_space_1'); END IF;
    IF v_dead_space_count >= 3 THEN valid_ids := array_append(valid_ids, 'dead_space_3'); END IF;

    IF v_yakuza_count >= 1 THEN valid_ids := array_append(valid_ids, 'yakuza_1'); END IF;
    IF v_yakuza_count >= 3 THEN valid_ids := array_append(valid_ids, 'yakuza_3'); END IF;
    IF v_yakuza_count >= 6 THEN valid_ids := array_append(valid_ids, 'yakuza_6'); END IF;

    IF v_xenoblade_count >= 1 THEN valid_ids := array_append(valid_ids, 'xenoblade_1'); END IF;
    IF v_xenoblade_count >= 3 THEN valid_ids := array_append(valid_ids, 'xenoblade_3'); END IF;

    IF v_persona_count >= 1 THEN valid_ids := array_append(valid_ids, 'persona_1'); END IF;
    IF v_persona_count >= 3 THEN valid_ids := array_append(valid_ids, 'persona_3'); END IF;
    IF v_persona_count >= 5 THEN valid_ids := array_append(valid_ids, 'persona_5'); END IF;

    -- ---------------------------------------------------------
    -- ELIMINAR los logros que ya no se cumplen
    -- ---------------------------------------------------------
    DELETE FROM public.user_achievements 
    WHERE user_id = uid AND achievement_id != ALL(valid_ids);

    -- ---------------------------------------------------------
    -- INSERTAR los que se cumplen
    -- ---------------------------------------------------------
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT uid, unnest(valid_ids)
    ON CONFLICT (user_id, achievement_id) DO NOTHING;
END;
$$;


-- 3. Asegurar que la función del trigger llama primero a los logros y luego a la XP
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
    
    -- PRIMERO: Calcular los logros (usando la función que pasamos por parámetro)
    PERFORM check_user_achievements(target_uid);
    
    -- SEGUNDO: Calcular la XP sumando esos logros
    PERFORM calculate_user_xp(target_uid);
    
    RETURN NULL; -- AFTER trigger
END;
$$;

-- 4. Ejecutar el recálculo retroactivo para TODOS los usuarios existentes
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT id FROM auth.users LOOP
        PERFORM public.check_user_achievements(r.id);
        PERFORM public.calculate_user_xp(r.id);
    END LOOP;
END $$;
