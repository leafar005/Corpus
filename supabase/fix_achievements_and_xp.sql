-- =====================================================================
-- CORRECCIÓN DE BUG: Revocación de Logros y Cálculo de XP
-- =====================================================================

-- 1. Eliminar la función 'muerta' que no recibe parámetros (la que no usaba el trigger)
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


-- 3. Reescribir la función calculate_user_xp
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
    -- XP por juegos y reviews (Ajustado a los valores del UI Dialog)
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'wishlist' THEN 5
            WHEN status = 'playing' THEN 10
            WHEN status = 'beaten' THEN 20
            WHEN status = 'dropped' THEN 10
            ELSE 0
        END
        + CASE WHEN length(comment) > 10 THEN 10 ELSE 0 END -- Reseña escrita: 10XP
        + CASE WHEN completion_type = '100%' THEN 50 ELSE 0 END
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- XP por logros desbloqueados
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- Añadimos 50 XP base por crear la cuenta (siempre)
    total_xp := reviews_xp + achievements_xp + 50;

    UPDATE public.users SET xp = total_xp WHERE id = uid;
END;
$$;


-- 4. CORREGIR el orden del Trigger maestro para que calcule los logros ANTES que la XP
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
    
    -- PRIMERO: Calcular los logros que tiene ahora mismo con el nuevo cambio
    PERFORM check_user_achievements(target_uid);
    
    -- SEGUNDO: Calcular la XP sumando todos esos logros actualizados + los juegos
    PERFORM calculate_user_xp(target_uid);
    
    RETURN NULL; -- AFTER trigger
END;
$$;

-- 5. Ejecutar para todos los usuarios actuales
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT id FROM auth.users LOOP
        PERFORM public.check_user_achievements(r.id);
        PERFORM public.calculate_user_xp(r.id);
    END LOOP;
END $$;
