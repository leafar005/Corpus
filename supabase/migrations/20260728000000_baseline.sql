--
-- PostgreSQL database dump
--

\restrict 0cDrm7FoDe6HlmT2s9dUrgvsspdJksfxM3Mz5DdjB0RA261uTPkvtrDFQqt4HnY

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: game_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.game_status AS ENUM (
    'playing',
    'beaten',
    'wishlist',
    'abandoned',
    'on_hold'
);


--
-- Name: calculate_user_xp(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_user_xp(uid uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    library_xp integer := 0;
    reviews_xp integer := 0;
    achievements_xp integer := 0;
    total_xp integer := 0;
BEGIN
    -- 1. XP por tu biblioteca completa (tabla user_games: tus 255 juegos)
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir juego a biblioteca (wishlist, playing, dropped, abandoned...): 5 XP
        END
    ), 0) INTO library_xp
    FROM public.user_games
    WHERE user_id = uid;

    -- 2. XP por escribir reseñas y completar al 100% (tabla reviews: tus 65 reseñas)
    SELECT COALESCE(SUM(
        CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END -- Escribir una reseña: 10 XP
        + CASE WHEN completion_type = '100%' THEN 50 ELSE 0 END                          -- Bonus por 100%: 50 XP
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- 3. XP por logros desbloqueados (tabla user_achievements: 3.250 XP)
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- 4. 50 XP base por crear la cuenta
    total_xp := library_xp + reviews_xp + achievements_xp + 50;

    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;


--
-- Name: check_user_achievements(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_achievements(uid uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    valid_ids text[] := ARRAY[]::text[];
    
    -- Variables para conteo de sagas
    v_kojima_count INT;
    v_fromsoftware_count INT;
    v_nintendo_count INT;
    v_capcom_count INT;
    v_naughty_dog_count INT;
    v_rockstar_count INT;
    v_cd_projekt_count INT;
    
    v_valve_count INT;
    v_remedy_count INT;
    v_team_ninja_count INT;
    v_konami_count INT;

    v_zelda_count INT;
    v_mario_count INT;
    v_pokemon_count INT;
    v_re_count INT;
    v_ds_count INT;
    v_ac_count INT;
    v_ff_count INT;
    v_cod_count INT;
    v_tes_count INT;
    v_gow_count INT;
    v_sonic_count INT;
    v_tr_count INT;
    v_mh_count INT;
    v_kh_count INT;
    v_sh_count INT;
    v_metroid_count INT;
    v_kirby_count INT;
    v_dmc_count INT;
    v_castlevania_count INT;
    v_me_count INT;
    v_doom_count INT;
    v_bioshock_count INT;
    v_borderlands_count INT;
    v_metro_count INT;
    v_dead_space_count INT;
BEGIN
    -- ---------------------------------------------------------
    -- LOGROS ORIGINALES (General)
    -- ---------------------------------------------------------
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
    -- 5. PC Master Race
    IF (SELECT count(*) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'pc_master_race');
    END IF;
    -- 6. Multiplataforma
    IF (SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL) >= 15 THEN
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

    -- ---------------------------------------------------------
    -- CONTEOS PARA SAGAS / COMPAÑÍAS
    -- ---------------------------------------------------------
    -- Compañías
    SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Kojima%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%FromSoftware%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Nintendo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Capcom%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Naughty Dog%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Rockstar%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%CD Projekt%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    SELECT count(*) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Valve%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Remedy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Team Ninja%' OR g.developer::text ILIKE '%Koei Tecmo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Konami%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer::text ILIKE '%Game Freak%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- Sagas
    SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%' OR g.collection::text ILIKE '%Elden Ring%' OR g.franchises::text ILIKE '%Elden Ring%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_cod_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Call of Duty%' OR g.franchises::text ILIKE '%Call of Duty%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_tes_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Elder Scrolls%' OR g.franchises::text ILIKE '%Elder Scrolls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_gow_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%God of War%' OR g.franchises::text ILIKE '%God of War%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_sonic_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Sonic%' OR g.franchises::text ILIKE '%Sonic%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_tr_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Tomb Raider%' OR g.franchises::text ILIKE '%Tomb Raider%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_mh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Monster Hunter%' OR g.franchises::text ILIKE '%Monster Hunter%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_kh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kingdom Hearts%' OR g.franchises::text ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_sh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Silent Hill%' OR g.franchises::text ILIKE '%Silent Hill%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_metroid_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metroid%' OR g.franchises::text ILIKE '%Metroid%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_kirby_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kirby%' OR g.franchises::text ILIKE '%Kirby%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_dmc_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Devil May Cry%' OR g.franchises::text ILIKE '%Devil May Cry%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_castlevania_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Castlevania%' OR g.franchises::text ILIKE '%Castlevania%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_me_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mass Effect%' OR g.franchises::text ILIKE '%Mass Effect%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_doom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Doom%' OR g.franchises::text ILIKE '%Doom%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(*) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- ---------------------------------------------------------
    -- ASIGNACIÓN A VALID_IDS
    -- ---------------------------------------------------------
    -- Kojima
    IF v_kojima_count >= 1 THEN valid_ids := array_append(valid_ids, 'kojima_1'); END IF;
    IF v_kojima_count >= 3 THEN valid_ids := array_append(valid_ids, 'kojima_3'); END IF;
    IF v_kojima_count >= 5 THEN valid_ids := array_append(valid_ids, 'kojima_5'); END IF;
    -- FromSoftware
    IF v_fromsoftware_count >= 1 THEN valid_ids := array_append(valid_ids, 'fromsoftware_1'); END IF;
    IF v_fromsoftware_count >= 3 THEN valid_ids := array_append(valid_ids, 'fromsoftware_3'); END IF;
    IF v_fromsoftware_count >= 7 THEN valid_ids := array_append(valid_ids, 'fromsoftware_all'); END IF;
    -- Nintendo
    IF v_nintendo_count >= 1 THEN valid_ids := array_append(valid_ids, 'nintendo_1'); END IF;
    IF v_nintendo_count >= 5 THEN valid_ids := array_append(valid_ids, 'nintendo_5'); END IF;
    IF v_nintendo_count >= 10 THEN valid_ids := array_append(valid_ids, 'nintendo_10'); END IF;
    -- Capcom
    IF v_capcom_count >= 1 THEN valid_ids := array_append(valid_ids, 'capcom_1'); END IF;
    IF v_capcom_count >= 5 THEN valid_ids := array_append(valid_ids, 'capcom_5'); END IF;
    IF v_capcom_count >= 10 THEN valid_ids := array_append(valid_ids, 'capcom_10'); END IF;
    -- Naughty Dog
    IF v_naughty_dog_count >= 1 THEN valid_ids := array_append(valid_ids, 'naughty_dog_1'); END IF;
    IF v_naughty_dog_count >= 3 THEN valid_ids := array_append(valid_ids, 'naughty_dog_3'); END IF;
    IF v_naughty_dog_count >= 5 THEN valid_ids := array_append(valid_ids, 'naughty_dog_5'); END IF;
    -- Rockstar
    IF v_rockstar_count >= 1 THEN valid_ids := array_append(valid_ids, 'rockstar_1'); END IF;
    IF v_rockstar_count >= 3 THEN valid_ids := array_append(valid_ids, 'rockstar_3'); END IF;
    -- CD Projekt
    IF v_cd_projekt_count >= 1 THEN valid_ids := array_append(valid_ids, 'cd_projekt_1'); END IF;
    IF v_cd_projekt_count >= 3 THEN valid_ids := array_append(valid_ids, 'cd_projekt_3'); END IF;
    -- Valve
    IF v_valve_count >= 1 THEN valid_ids := array_append(valid_ids, 'valve_1'); END IF;
    IF v_valve_count >= 3 THEN valid_ids := array_append(valid_ids, 'valve_3'); END IF;
    -- Remedy
    IF v_remedy_count >= 1 THEN valid_ids := array_append(valid_ids, 'remedy_1'); END IF;
    IF v_remedy_count >= 3 THEN valid_ids := array_append(valid_ids, 'remedy_3'); END IF;
    -- Team Ninja
    IF v_team_ninja_count >= 1 THEN valid_ids := array_append(valid_ids, 'team_ninja_1'); END IF;
    IF v_team_ninja_count >= 3 THEN valid_ids := array_append(valid_ids, 'team_ninja_3'); END IF;
    -- Konami
    IF v_konami_count >= 1 THEN valid_ids := array_append(valid_ids, 'konami_1'); END IF;
    IF v_konami_count >= 5 THEN valid_ids := array_append(valid_ids, 'konami_5'); END IF;
    -- Pokemon
    IF v_pokemon_count >= 1 THEN valid_ids := array_append(valid_ids, 'pokemon_1'); END IF;
    IF v_pokemon_count >= 3 THEN valid_ids := array_append(valid_ids, 'pokemon_3'); END IF;
    IF v_pokemon_count >= 5 THEN valid_ids := array_append(valid_ids, 'pokemon_5'); END IF;
    
    -- Zelda
    IF v_zelda_count >= 1 THEN valid_ids := array_append(valid_ids, 'zelda_1'); END IF;
    IF v_zelda_count >= 3 THEN valid_ids := array_append(valid_ids, 'zelda_3'); END IF;
    IF v_zelda_count >= 7 THEN valid_ids := array_append(valid_ids, 'zelda_all'); END IF;
    -- Mario
    IF v_mario_count >= 1 THEN valid_ids := array_append(valid_ids, 'mario_1'); END IF;
    IF v_mario_count >= 5 THEN valid_ids := array_append(valid_ids, 'mario_5'); END IF;
    IF v_mario_count >= 10 THEN valid_ids := array_append(valid_ids, 'mario_10'); END IF;
    -- Resident Evil
    IF v_re_count >= 1 THEN valid_ids := array_append(valid_ids, 'resident_evil_1'); END IF;
    IF v_re_count >= 3 THEN valid_ids := array_append(valid_ids, 'resident_evil_3'); END IF;
    IF v_re_count >= 5 THEN valid_ids := array_append(valid_ids, 'resident_evil_5'); END IF;
    -- Dark Souls
    IF v_ds_count >= 1 THEN valid_ids := array_append(valid_ids, 'dark_souls_1'); END IF;
    IF v_ds_count >= 3 THEN valid_ids := array_append(valid_ids, 'dark_souls_all'); END IF;
    -- Assassin's Creed
    IF v_ac_count >= 1 THEN valid_ids := array_append(valid_ids, 'assassins_creed_1'); END IF;
    IF v_ac_count >= 3 THEN valid_ids := array_append(valid_ids, 'assassins_creed_3'); END IF;
    IF v_ac_count >= 6 THEN valid_ids := array_append(valid_ids, 'assassins_creed_6'); END IF;
    -- Final Fantasy
    IF v_ff_count >= 1 THEN valid_ids := array_append(valid_ids, 'final_fantasy_1'); END IF;
    IF v_ff_count >= 3 THEN valid_ids := array_append(valid_ids, 'final_fantasy_3'); END IF;
    IF v_ff_count >= 5 THEN valid_ids := array_append(valid_ids, 'final_fantasy_5'); END IF;
    -- Call of Duty
    IF v_cod_count >= 1 THEN valid_ids := array_append(valid_ids, 'call_of_duty_1'); END IF;
    IF v_cod_count >= 5 THEN valid_ids := array_append(valid_ids, 'call_of_duty_5'); END IF;
    -- Elder Scrolls
    IF v_tes_count >= 1 THEN valid_ids := array_append(valid_ids, 'elder_scrolls_1'); END IF;
    IF v_tes_count >= 3 THEN valid_ids := array_append(valid_ids, 'elder_scrolls_3'); END IF;
    -- God of War
    IF v_gow_count >= 1 THEN valid_ids := array_append(valid_ids, 'god_of_war_1'); END IF;
    IF v_gow_count >= 3 THEN valid_ids := array_append(valid_ids, 'god_of_war_3'); END IF;
    -- Sonic
    IF v_sonic_count >= 1 THEN valid_ids := array_append(valid_ids, 'sonic_1'); END IF;
    IF v_sonic_count >= 5 THEN valid_ids := array_append(valid_ids, 'sonic_5'); END IF;
    -- Tomb Raider
    IF v_tr_count >= 1 THEN valid_ids := array_append(valid_ids, 'tomb_raider_1'); END IF;
    IF v_tr_count >= 3 THEN valid_ids := array_append(valid_ids, 'tomb_raider_3'); END IF;
    -- Monster Hunter
    IF v_mh_count >= 1 THEN valid_ids := array_append(valid_ids, 'monster_hunter_1'); END IF;
    IF v_mh_count >= 3 THEN valid_ids := array_append(valid_ids, 'monster_hunter_3'); END IF;
    -- Kingdom Hearts
    IF v_kh_count >= 1 THEN valid_ids := array_append(valid_ids, 'kingdom_hearts_1'); END IF;
    IF v_kh_count >= 3 THEN valid_ids := array_append(valid_ids, 'kingdom_hearts_3'); END IF;
    -- Silent Hill
    IF v_sh_count >= 1 THEN valid_ids := array_append(valid_ids, 'silent_hill_1'); END IF;
    IF v_sh_count >= 3 THEN valid_ids := array_append(valid_ids, 'silent_hill_3'); END IF;
    -- Metroid
    IF v_metroid_count >= 1 THEN valid_ids := array_append(valid_ids, 'metroid_1'); END IF;
    IF v_metroid_count >= 3 THEN valid_ids := array_append(valid_ids, 'metroid_3'); END IF;
    -- Kirby
    IF v_kirby_count >= 1 THEN valid_ids := array_append(valid_ids, 'kirby_1'); END IF;
    IF v_kirby_count >= 3 THEN valid_ids := array_append(valid_ids, 'kirby_3'); END IF;
    -- Devil May Cry
    IF v_dmc_count >= 1 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_1'); END IF;
    IF v_dmc_count >= 3 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_3'); END IF;
    -- Castlevania
    IF v_castlevania_count >= 1 THEN valid_ids := array_append(valid_ids, 'castlevania_1'); END IF;
    IF v_castlevania_count >= 3 THEN valid_ids := array_append(valid_ids, 'castlevania_3'); END IF;
    -- Mass Effect
    IF v_me_count >= 1 THEN valid_ids := array_append(valid_ids, 'mass_effect_1'); END IF;
    IF v_me_count >= 3 THEN valid_ids := array_append(valid_ids, 'mass_effect_3'); END IF;
    -- Doom
    IF v_doom_count >= 1 THEN valid_ids := array_append(valid_ids, 'doom_1'); END IF;
    IF v_doom_count >= 3 THEN valid_ids := array_append(valid_ids, 'doom_3'); END IF;
    -- Bioshock
    IF v_bioshock_count >= 1 THEN valid_ids := array_append(valid_ids, 'bioshock_1'); END IF;
    IF v_bioshock_count >= 3 THEN valid_ids := array_append(valid_ids, 'bioshock_3'); END IF;
    -- Borderlands
    IF v_borderlands_count >= 1 THEN valid_ids := array_append(valid_ids, 'borderlands_1'); END IF;
    IF v_borderlands_count >= 3 THEN valid_ids := array_append(valid_ids, 'borderlands_3'); END IF;
    -- Metro
    IF v_metro_count >= 1 THEN valid_ids := array_append(valid_ids, 'metro_1'); END IF;
    IF v_metro_count >= 3 THEN valid_ids := array_append(valid_ids, 'metro_3'); END IF;
    -- Dead Space
    IF v_dead_space_count >= 1 THEN valid_ids := array_append(valid_ids, 'dead_space_1'); END IF;
    IF v_dead_space_count >= 3 THEN valid_ids := array_append(valid_ids, 'dead_space_3'); END IF;

    -- ELIMINAR los logros que ya no se cumplen
    DELETE FROM public.user_achievements 
    WHERE user_id = uid AND achievement_id != ALL(valid_ids);

    -- INSERTAR los que se cumplen (ignorando los que ya estaba para mantener su fecha original)
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT uid, unnest(valid_ids)
    ON CONFLICT (user_id, achievement_id) DO NOTHING;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Inserta una nueva fila en nuestra tabla pública 'users'
  INSERT INTO public.users (id, username, avatar_url)
  VALUES (
    new.id, 
    -- Extrae el 'username' que le enviaremos desde la app de Flutter
    new.raw_user_meta_data->>'username',
    -- De regalo, le generamos un avatar temporal con sus iniciales usando una API gratuita
    'https://ui-avatars.com/api/?name=' || (new.raw_user_meta_data->>'username') || '&background=random'
  );
  RETURN new;
END;
$$;


--
-- Name: on_review_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_review_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM public.activity_feed
    WHERE user_id = OLD.user_id 
      AND game_id = OLD.game_id 
      AND action_type = 'reviewed'
      AND metadata->>'review_id' = OLD.id::text;
    RETURN OLD;
END;
$$;


--
-- Name: on_review_upsert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_review_upsert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: on_user_game_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_user_game_delete() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM public.activity_feed
    WHERE user_id = OLD.user_id 
      AND game_id = OLD.game_id 
      AND action_type = 'status_change';
    RETURN OLD;
END;
$$;


--
-- Name: on_user_game_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_user_game_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: trigger_review_gamification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_review_gamification() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
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


--
-- Name: update_modified_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_modified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.achievements (
    id text NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    xp_reward integer DEFAULT 0 NOT NULL,
    rarity text NOT NULL,
    icon_name text NOT NULL
);


--
-- Name: active_bundles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_bundles (
    id text NOT NULL,
    title text NOT NULL,
    store_name text NOT NULL,
    url text NOT NULL,
    end_date timestamp with time zone,
    tiers jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: activity_feed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_feed (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    action_type text NOT NULL,
    game_id integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT activity_feed_action_type_check CHECK ((action_type = ANY (ARRAY['status_change'::text, 'reviewed'::text, 'achievement'::text])))
);


--
-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    requester_id uuid NOT NULL,
    addressee_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT friendships_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text]))),
    CONSTRAINT no_self_friend CHECK ((requester_id <> addressee_id))
);


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    igdb_id integer NOT NULL,
    title text NOT NULL,
    cover_url text,
    release_date date,
    genres jsonb,
    steam_app_id integer,
    summary text,
    platforms jsonb,
    developer text,
    category integer,
    parent_game integer,
    themes jsonb,
    game_modes jsonb,
    player_perspectives jsonb,
    collection text,
    franchises text[],
    game_engines text[]
);


--
-- Name: TABLE games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.games IS 'Catalogo de juegos (solo lectura para usuarios). INSERT permitido para autenticados. UPDATE/DELETE solo por service_role o funciones SECURITY DEFINER.';


--
-- Name: hall_of_fame; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hall_of_fame (
    user_id uuid NOT NULL,
    game_id integer,
    pin_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hall_of_fame_pin_order_check CHECK (((pin_order >= 1) AND (pin_order <= 5)))
);


--
-- Name: review_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    review_id uuid NOT NULL,
    image_url text,
    attached_game jsonb,
    CONSTRAINT review_comments_content_check CHECK (((char_length(content) <= 500) AND (char_length(content) > 0))),
    CONSTRAINT review_comments_content_or_image_check CHECK ((((content IS NOT NULL) AND (char_length(content) > 0)) OR ((image_url IS NOT NULL) AND (char_length(image_url) > 0)) OR (attached_game IS NOT NULL)))
);


--
-- Name: review_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_likes (
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    review_id uuid NOT NULL
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    game_id integer NOT NULL,
    rating double precision,
    rating_gameplay double precision,
    rating_narrative double precision,
    rating_soundtrack double precision,
    rating_visuals double precision,
    comment text,
    status text DEFAULT 'beaten'::text NOT NULL,
    completion_type text DEFAULT 'story'::text NOT NULL,
    is_replay boolean DEFAULT false NOT NULL,
    replay_number integer,
    platform text,
    play_time_hours double precision,
    played_from date,
    played_until date,
    progress_percent integer,
    created_at timestamp with time zone DEFAULT now(),
    image_urls text[] DEFAULT '{}'::text[],
    CONSTRAINT reviews_progress_percent_check CHECK (((progress_percent >= 0) AND (progress_percent <= 100))),
    CONSTRAINT reviews_rating_check CHECK (((rating >= (1)::double precision) AND (rating <= (10)::double precision))),
    CONSTRAINT reviews_rating_gameplay_check CHECK (((rating_gameplay >= (1)::double precision) AND (rating_gameplay <= (10)::double precision))),
    CONSTRAINT reviews_rating_narrative_check CHECK (((rating_narrative >= (1)::double precision) AND (rating_narrative <= (10)::double precision))),
    CONSTRAINT reviews_rating_soundtrack_check CHECK (((rating_soundtrack >= (1)::double precision) AND (rating_soundtrack <= (10)::double precision))),
    CONSTRAINT reviews_rating_visuals_check CHECK (((rating_visuals >= (1)::double precision) AND (rating_visuals <= (10)::double precision)))
);


--
-- Name: stash_community_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_community_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    game_id integer,
    stash_user_display_name text,
    stash_user_avatar_url text,
    comment text,
    rating numeric(3,1),
    source_context text,
    stash_created_at timestamp with time zone,
    imported_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    CONSTRAINT stash_community_reviews_source_context_check CHECK ((source_context = ANY (ARRAY['game_reviews'::text, 'recent_activity_feed'::text])))
);


--
-- Name: stash_game_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_game_stats (
    game_id integer NOT NULL,
    stash_rating numeric,
    want_count integer,
    playing_count integer,
    played_count integer,
    reviews_count integer,
    last_stats_checked_at timestamp with time zone,
    last_reviews_total_checked_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: stash_sync_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_sync_metadata (
    game_id integer NOT NULL,
    last_checked_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);


--
-- Name: user_achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_achievements (
    user_id uuid NOT NULL,
    achievement_id text NOT NULL,
    unlocked_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: user_games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_games (
    user_id uuid NOT NULL,
    game_id integer NOT NULL,
    status public.game_status DEFAULT 'wishlist'::public.game_status NOT NULL,
    rating numeric(3,1),
    rating_gameplay numeric(3,1),
    rating_soundtrack numeric(3,1),
    rating_visuals numeric(3,1),
    comment text,
    partner_id uuid,
    play_count integer DEFAULT 1 NOT NULL,
    play_time_hours numeric,
    last_played_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    rating_narrative real,
    CONSTRAINT user_games_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (10)::numeric))),
    CONSTRAINT user_games_rating_gameplay_check CHECK (((rating_gameplay >= (1)::numeric) AND (rating_gameplay <= (10)::numeric))),
    CONSTRAINT user_games_rating_soundtrack_check CHECK (((rating_soundtrack >= (1)::numeric) AND (rating_soundtrack <= (10)::numeric))),
    CONSTRAINT user_games_rating_visuals_check CHECK (((rating_visuals >= (1)::numeric) AND (rating_visuals <= (10)::numeric)))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username text NOT NULL,
    avatar_url text,
    banner_url text,
    steam_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    display_name text,
    bio text,
    platforms jsonb DEFAULT '[]'::jsonb,
    xp integer DEFAULT 0 NOT NULL
);


--
-- Name: v_friend_pairs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_friend_pairs WITH (security_invoker='true') AS
 SELECT friendships.requester_id AS user_id,
    friendships.addressee_id AS friend_id
   FROM public.friendships
  WHERE (friendships.status = 'accepted'::text)
UNION ALL
 SELECT friendships.addressee_id AS user_id,
    friendships.requester_id AS friend_id
   FROM public.friendships
  WHERE (friendships.status = 'accepted'::text);


--
-- Name: VIEW v_friend_pairs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_friend_pairs IS 'Vista simetrica de amistades aceptadas. Para cada par (A,B) genera dos filas: (A->B) y (B->A). Usala para obtener todos los amigos de un usuario con una sola query: SELECT friend_id FROM v_friend_pairs WHERE user_id = $1';


--
-- Name: achievements achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT achievements_pkey PRIMARY KEY (id);


--
-- Name: active_bundles active_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_bundles
    ADD CONSTRAINT active_bundles_pkey PRIMARY KEY (id);


--
-- Name: activity_feed activity_feed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_pkey PRIMARY KEY (id);


--
-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (requester_id, addressee_id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (igdb_id);


--
-- Name: hall_of_fame hall_of_fame_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_pkey PRIMARY KEY (user_id, pin_order);


--
-- Name: review_comments review_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_pkey PRIMARY KEY (id);


--
-- Name: review_likes review_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_pkey PRIMARY KEY (user_id, review_id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: stash_community_reviews stash_community_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT stash_community_reviews_pkey PRIMARY KEY (id);


--
-- Name: stash_game_stats stash_game_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_game_stats
    ADD CONSTRAINT stash_game_stats_pkey PRIMARY KEY (game_id);


--
-- Name: stash_sync_metadata stash_sync_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_sync_metadata
    ADD CONSTRAINT stash_sync_metadata_pkey PRIMARY KEY (game_id);


--
-- Name: stash_community_reviews uq_game_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT uq_game_user UNIQUE (game_id, stash_user_display_name);


--
-- Name: user_achievements user_achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_pkey PRIMARY KEY (user_id, achievement_id);


--
-- Name: user_games user_games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_pkey PRIMARY KEY (user_id, game_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: activity_feed_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_feed_created_idx ON public.activity_feed USING btree (created_at DESC);


--
-- Name: activity_feed_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_feed_user_idx ON public.activity_feed USING btree (user_id);


--
-- Name: friendships_addressee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX friendships_addressee_idx ON public.friendships USING btree (addressee_id);


--
-- Name: friendships_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX friendships_status_idx ON public.friendships USING btree (status);


--
-- Name: idx_activity_feed_compound; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_feed_compound ON public.activity_feed USING btree (user_id, game_id, created_at DESC);


--
-- Name: idx_friendships_addr_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_addr_status ON public.friendships USING btree (addressee_id, status);


--
-- Name: idx_friendships_req_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_req_status ON public.friendships USING btree (requester_id, status);


--
-- Name: idx_review_comments_review_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_review_comments_review_id ON public.review_comments USING btree (review_id);


--
-- Name: idx_review_likes_review_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_review_likes_review_id ON public.review_likes USING btree (review_id);


--
-- Name: idx_reviews_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_created_at ON public.reviews USING btree (created_at DESC);


--
-- Name: idx_reviews_game_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_game_created ON public.reviews USING btree (game_id, created_at DESC);


--
-- Name: idx_reviews_user_game; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_user_game ON public.reviews USING btree (user_id, game_id);


--
-- Name: idx_stash_reviews_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stash_reviews_game_id ON public.stash_community_reviews USING btree (game_id);


--
-- Name: idx_user_games_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_games_updated ON public.user_games USING btree (user_id, updated_at DESC);


--
-- Name: reviews on_review_changed_gamification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_review_changed_gamification AFTER INSERT OR DELETE OR UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.trigger_review_gamification();


--
-- Name: reviews trg_review_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_review_delete AFTER DELETE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.on_review_delete();


--
-- Name: reviews trg_review_upsert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_review_upsert AFTER INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.on_review_upsert();


--
-- Name: user_games trg_user_game_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_game_delete AFTER DELETE ON public.user_games FOR EACH ROW EXECUTE FUNCTION public.on_user_game_delete();


--
-- Name: user_games trg_user_game_status_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_game_status_change AFTER INSERT OR UPDATE ON public.user_games FOR EACH ROW EXECUTE FUNCTION public.on_user_game_status_change();


--
-- Name: active_bundles update_active_bundles_modtime; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_active_bundles_modtime BEFORE UPDATE ON public.active_bundles FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- Name: activity_feed activity_feed_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--
-- Name: activity_feed activity_feed_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships friendships_addressee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_addressee_id_fkey FOREIGN KEY (addressee_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships friendships_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: hall_of_fame hall_of_fame_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--
-- Name: hall_of_fame hall_of_fame_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: review_comments review_comments_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--
-- Name: review_comments review_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: review_likes review_likes_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--
-- Name: review_likes review_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_user_id_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_users_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: stash_community_reviews stash_community_reviews_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT stash_community_reviews_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--
-- Name: stash_game_stats stash_game_stats_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_game_stats
    ADD CONSTRAINT stash_game_stats_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--
-- Name: user_achievements user_achievements_achievement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievements(id) ON DELETE CASCADE;


--
-- Name: user_achievements user_achievements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_games user_games_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--
-- Name: user_games user_games_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_games user_games_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: games Allow all for authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all for authenticated" ON public.games TO authenticated USING (true) WITH CHECK (true);


--
-- Name: active_bundles Allow public read access on active_bundles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read access on active_bundles" ON public.active_bundles FOR SELECT USING (true);


--
-- Name: stash_community_reviews Anyone can insert stash community reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can insert stash community reviews" ON public.stash_community_reviews FOR INSERT WITH CHECK (true);


--
-- Name: stash_sync_metadata Anyone can insert stash sync metadata; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can insert stash sync metadata" ON public.stash_sync_metadata USING (true) WITH CHECK (true);


--
-- Name: reviews Anyone can read reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read reviews" ON public.reviews FOR SELECT USING (true);


--
-- Name: review_comments Anyone can view comments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view comments" ON public.review_comments FOR SELECT USING (true);


--
-- Name: games Anyone can view games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view games" ON public.games FOR SELECT USING (true);


--
-- Name: hall_of_fame Anyone can view hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view hall_of_fame" ON public.hall_of_fame FOR SELECT USING (true);


--
-- Name: review_likes Anyone can view likes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view likes" ON public.review_likes FOR SELECT USING (true);


--
-- Name: stash_community_reviews Anyone can view stash community reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view stash community reviews" ON public.stash_community_reviews FOR SELECT USING (true);


--
-- Name: stash_sync_metadata Anyone can view stash sync metadata; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view stash sync metadata" ON public.stash_sync_metadata FOR SELECT USING (true);


--
-- Name: achievements Logros son públicos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Logros son públicos" ON public.achievements FOR SELECT USING (true);


--
-- Name: activity_feed No direct user insert into activity_feed; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No direct user insert into activity_feed" ON public.activity_feed FOR INSERT WITH CHECK (false);


--
-- Name: games No user DELETE on games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No user DELETE on games" ON public.games FOR DELETE USING (false);


--
-- Name: games No user UPDATE on games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No user UPDATE on games" ON public.games FOR UPDATE USING (false);


--
-- Name: user_achievements Trigger maneja user_achievements; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Trigger maneja user_achievements" ON public.user_achievements USING ((auth.uid() = user_id));


--
-- Name: friendships Users can delete friendships they are part of; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete friendships they are part of" ON public.friendships FOR DELETE USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));


--
-- Name: review_comments Users can delete own comment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own comment" ON public.review_comments FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: user_games Users can delete own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own games" ON public.user_games FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: hall_of_fame Users can delete own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own hall_of_fame" ON public.hall_of_fame FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: review_likes Users can delete own like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own like" ON public.review_likes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: reviews Users can delete own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own reviews" ON public.reviews FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: games Users can insert games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert games" ON public.games FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: review_comments Users can insert own comment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own comment" ON public.review_comments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_games Users can insert own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own games" ON public.user_games FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: hall_of_fame Users can insert own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own hall_of_fame" ON public.hall_of_fame FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: review_likes Users can insert own like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own like" ON public.review_likes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: reviews Users can insert own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own reviews" ON public.reviews FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: friendships Users can send friend requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can send friend requests" ON public.friendships FOR INSERT WITH CHECK ((auth.uid() = requester_id));


--
-- Name: friendships Users can update friendships they are part of; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update friendships they are part of" ON public.friendships FOR UPDATE USING ((auth.uid() = addressee_id));


--
-- Name: user_games Users can update own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own games" ON public.user_games FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: hall_of_fame Users can update own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own hall_of_fame" ON public.hall_of_fame FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: users Users can update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING ((auth.uid() = id));


--
-- Name: reviews Users can update own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own reviews" ON public.reviews FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: user_games Users can view all user_games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view all user_games" ON public.user_games FOR SELECT USING (true);


--
-- Name: users Users can view all users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view all users" ON public.users FOR SELECT USING (true);


--
-- Name: activity_feed Users can view their own and friends activity; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own and friends activity" ON public.activity_feed FOR SELECT USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.friendships f
  WHERE ((f.status = 'accepted'::text) AND (((f.requester_id = auth.uid()) AND (f.addressee_id = activity_feed.user_id)) OR ((f.addressee_id = auth.uid()) AND (f.requester_id = activity_feed.user_id))))))));


--
-- Name: friendships Users can view their own friendships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own friendships" ON public.friendships FOR SELECT USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));


--
-- Name: user_achievements Usuarios pueden ver todos los logros desbloqueados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Usuarios pueden ver todos los logros desbloqueados" ON public.user_achievements FOR SELECT USING (true);


--
-- Name: achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

--
-- Name: active_bundles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.active_bundles ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_feed; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

--
-- Name: friendships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

--
-- Name: games; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;

--
-- Name: hall_of_fame; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hall_of_fame ENABLE ROW LEVEL SECURITY;

--
-- Name: review_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.review_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: review_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.review_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: stash_community_reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_community_reviews ENABLE ROW LEVEL SECURITY;

--
-- Name: stash_game_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_game_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: stash_game_stats stash_game_stats_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stash_game_stats_select_authenticated ON public.stash_game_stats FOR SELECT TO authenticated USING (true);


--
-- Name: stash_sync_metadata; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_sync_metadata ENABLE ROW LEVEL SECURITY;

--
-- Name: user_achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

--
-- Name: user_games; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_games ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION calculate_user_xp(uid uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.calculate_user_xp(uid uuid) TO authenticated;
GRANT ALL ON FUNCTION public.calculate_user_xp(uid uuid) TO service_role;


--
-- Name: FUNCTION check_user_achievements(uid uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_user_achievements(uid uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_user_achievements(uid uuid) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION on_review_delete(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_review_delete() TO anon;
GRANT ALL ON FUNCTION public.on_review_delete() TO authenticated;
GRANT ALL ON FUNCTION public.on_review_delete() TO service_role;


--
-- Name: FUNCTION on_review_upsert(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_review_upsert() TO anon;
GRANT ALL ON FUNCTION public.on_review_upsert() TO authenticated;
GRANT ALL ON FUNCTION public.on_review_upsert() TO service_role;


--
-- Name: FUNCTION on_user_game_delete(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_user_game_delete() TO anon;
GRANT ALL ON FUNCTION public.on_user_game_delete() TO authenticated;
GRANT ALL ON FUNCTION public.on_user_game_delete() TO service_role;


--
-- Name: FUNCTION on_user_game_status_change(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_user_game_status_change() TO anon;
GRANT ALL ON FUNCTION public.on_user_game_status_change() TO authenticated;
GRANT ALL ON FUNCTION public.on_user_game_status_change() TO service_role;


--
-- Name: FUNCTION trigger_review_gamification(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.trigger_review_gamification() TO anon;
GRANT ALL ON FUNCTION public.trigger_review_gamification() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_review_gamification() TO service_role;


--
-- Name: FUNCTION update_modified_column(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_modified_column() TO anon;
GRANT ALL ON FUNCTION public.update_modified_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_modified_column() TO service_role;


--
-- Name: TABLE achievements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.achievements TO anon;
GRANT ALL ON TABLE public.achievements TO authenticated;
GRANT ALL ON TABLE public.achievements TO service_role;


--
-- Name: TABLE active_bundles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.active_bundles TO anon;
GRANT ALL ON TABLE public.active_bundles TO authenticated;
GRANT ALL ON TABLE public.active_bundles TO service_role;


--
-- Name: TABLE activity_feed; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.activity_feed TO anon;
GRANT ALL ON TABLE public.activity_feed TO authenticated;
GRANT ALL ON TABLE public.activity_feed TO service_role;


--
-- Name: TABLE friendships; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.friendships TO anon;
GRANT ALL ON TABLE public.friendships TO authenticated;
GRANT ALL ON TABLE public.friendships TO service_role;


--
-- Name: TABLE games; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.games TO anon;
GRANT ALL ON TABLE public.games TO authenticated;
GRANT ALL ON TABLE public.games TO service_role;


--
-- Name: TABLE hall_of_fame; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.hall_of_fame TO anon;
GRANT ALL ON TABLE public.hall_of_fame TO authenticated;
GRANT ALL ON TABLE public.hall_of_fame TO service_role;


--
-- Name: TABLE review_comments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.review_comments TO anon;
GRANT ALL ON TABLE public.review_comments TO authenticated;
GRANT ALL ON TABLE public.review_comments TO service_role;


--
-- Name: TABLE review_likes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.review_likes TO anon;
GRANT ALL ON TABLE public.review_likes TO authenticated;
GRANT ALL ON TABLE public.review_likes TO service_role;


--
-- Name: TABLE reviews; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.reviews TO anon;
GRANT ALL ON TABLE public.reviews TO authenticated;
GRANT ALL ON TABLE public.reviews TO service_role;


--
-- Name: TABLE stash_community_reviews; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_community_reviews TO anon;
GRANT ALL ON TABLE public.stash_community_reviews TO authenticated;
GRANT ALL ON TABLE public.stash_community_reviews TO service_role;


--
-- Name: TABLE stash_game_stats; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_game_stats TO anon;
GRANT ALL ON TABLE public.stash_game_stats TO authenticated;
GRANT ALL ON TABLE public.stash_game_stats TO service_role;


--
-- Name: TABLE stash_sync_metadata; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_sync_metadata TO anon;
GRANT ALL ON TABLE public.stash_sync_metadata TO authenticated;
GRANT ALL ON TABLE public.stash_sync_metadata TO service_role;


--
-- Name: TABLE user_achievements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_achievements TO anon;
GRANT ALL ON TABLE public.user_achievements TO authenticated;
GRANT ALL ON TABLE public.user_achievements TO service_role;


--
-- Name: TABLE user_games; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_games TO anon;
GRANT ALL ON TABLE public.user_games TO authenticated;
GRANT ALL ON TABLE public.user_games TO service_role;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--
-- Name: TABLE v_friend_pairs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_friend_pairs TO anon;
GRANT ALL ON TABLE public.v_friend_pairs TO authenticated;
GRANT ALL ON TABLE public.v_friend_pairs TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict 0cDrm7FoDe6HlmT2s9dUrgvsspdJksfxM3Mz5DdjB0RA261uTPkvtrDFQqt4HnY

