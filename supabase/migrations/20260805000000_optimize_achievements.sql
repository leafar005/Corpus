-- =============================================================================
-- Migración: B-C3 Optimizar check_user_achievements (Patrón N+1)
-- =============================================================================
-- La función original realizaba casi 50 queries individuales (SELECT COUNT) 
-- para comprobar los logros de compañías y sagas.
-- Esta versión reescribe la lógica para que todo se calcule en 1 única query
-- mediante count condicional (CASE WHEN).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.check_user_achievements(uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    valid_ids text[] := ARRAY[]::text[];
    
    -- Compañías
    v_kojima_count INT; v_fromsoftware_count INT; v_nintendo_count INT; v_capcom_count INT;
    v_naughty_dog_count INT; v_rockstar_count INT; v_cd_projekt_count INT; v_konami_count INT;
    v_valve_count INT; v_remedy_count INT; v_team_ninja_count INT; v_square_enix_count INT; v_bethesda_count INT;
    
    -- Franquicias
    v_zelda_count INT; v_mario_count INT; v_pokemon_count INT; v_re_count INT; v_ds_count INT;
    v_ac_count INT; v_ff_count INT; v_cod_count INT; v_es_count INT; v_gow_count INT;
    v_tomb_count INT; v_mh_count INT; v_kh_count INT; v_sh_count INT; v_metroid_count INT;
    v_kirby_count INT; v_dmc_count INT; v_castlevania_count INT; v_me_count INT; v_doom_count INT;
    v_bioshock_count INT; v_borderlands_count INT; v_metro_count INT; v_dead_space_count INT;
    v_yakuza_count INT; v_xenoblade_count INT; v_persona_count INT; v_halo_count INT; v_sonic_count INT;
BEGIN

    -- 1. CONSULTA PRINCIPAL (TODO EN UNO)
    SELECT 
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Kojima%' OR g.collection::text ILIKE '%Metal Gear%' OR g.collection::text ILIKE '%Zone of the Enders%' OR g.collection::text ILIKE '%Boktai%' OR g.title ILIKE '%Metal Gear%' OR g.title ILIKE '%Death Stranding%' OR g.title ILIKE '%Snatcher%' OR g.title ILIKE '%Policenauts%' OR g.title ILIKE '%Zone of the Enders%' OR g.title ILIKE '%Boktai%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%FromSoftware%' OR g.title ILIKE '%Demon''s Souls%' OR g.title ILIKE '%Demon Souls%' OR g.title ILIKE '%Dark Souls%' OR g.title ILIKE '%Elden Ring%' OR g.title ILIKE '%Bloodborne%' OR g.title ILIKE '%Sekiro%' OR g.title ILIKE '%Armored Core%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Nintendo%' OR g.developer ILIKE '%HAL Laboratory%' OR g.developer ILIKE '%Intelligent Systems%' OR g.developer ILIKE '%Game Freak%' OR g.developer ILIKE '%Monolith Soft%' OR g.developer ILIKE '%Retro Studios%' OR g.developer ILIKE '%Next Level Games%' OR g.developer ILIKE '%Grezzo%' OR g.developer ILIKE '%Good-Feel%' OR g.developer ILIKE '%ND Cube%' OR g.developer ILIKE '%Sora Ltd%' OR g.developer ILIKE '%Camelot%' OR g.developer ILIKE '%Creatures Inc%' OR g.collection::text ILIKE '%Mario%' OR g.collection::text ILIKE '%Zelda%' OR g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%' OR g.collection::text ILIKE '%Metroid%' OR g.collection::text ILIKE '%Kirby%' OR g.collection::text ILIKE '%Donkey Kong%' OR g.collection::text ILIKE '%Fire Emblem%' OR g.collection::text ILIKE '%Splatoon%' OR g.collection::text ILIKE '%Pikmin%' OR g.collection::text ILIKE '%Animal Crossing%' OR g.collection::text ILIKE '%Star Fox%' OR g.collection::text ILIKE '%Xenoblade%' OR g.collection::text ILIKE '%Smash Bros%' OR g.franchises::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Pokemon%' OR g.franchises::text ILIKE '%Pokémon%' OR g.franchises::text ILIKE '%Metroid%' OR g.franchises::text ILIKE '%Kirby%' OR g.franchises::text ILIKE '%Donkey Kong%' OR g.franchises::text ILIKE '%Fire Emblem%' OR g.franchises::text ILIKE '%Splatoon%' OR g.franchises::text ILIKE '%Pikmin%' OR g.franchises::text ILIKE '%Animal Crossing%' OR g.franchises::text ILIKE '%Star Fox%' OR g.franchises::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Smash Bros%' OR g.title ILIKE '%Mario%' OR g.title ILIKE '%Zelda%' OR g.title ILIKE '%Pokemon%' OR g.title ILIKE '%Pokémon%' OR g.title ILIKE '%Metroid%' OR g.title ILIKE '%Kirby%' OR g.title ILIKE '%Donkey Kong%' OR g.title ILIKE '%Fire Emblem%' OR g.title ILIKE '%Splatoon%' OR g.title ILIKE '%Pikmin%' OR g.title ILIKE '%Animal Crossing%' OR g.title ILIKE '%Star Fox%' OR g.title ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Capcom%' OR g.developer ILIKE '%Blue Castle%' OR g.developer ILIKE '%Ninja Theory%' OR g.developer ILIKE '%NeoBards%' OR g.developer ILIKE '%M-Two%' OR g.developer ILIKE '%HexaDrive%' OR g.developer ILIKE '%QLOC%' OR g.developer ILIKE '%TOSE%' OR g.collection::text ILIKE '%Resident Evil%' OR g.collection::text ILIKE '%Monster Hunter%' OR g.collection::text ILIKE '%Devil May Cry%' OR g.collection::text ILIKE '%Street Fighter%' OR g.collection::text ILIKE '%Mega Man%' OR g.collection::text ILIKE '%Ace Attorney%' OR g.collection::text ILIKE '%Dead Rising%' OR g.collection::text ILIKE '%Dragon''s Dogma%' OR g.collection::text ILIKE '%Onimusha%' OR g.collection::text ILIKE '%Dino Crisis%' OR g.collection::text ILIKE '%Okami%' OR g.collection::text ILIKE '%Darkstalkers%' OR g.franchises::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Monster Hunter%' OR g.franchises::text ILIKE '%Devil May Cry%' OR g.franchises::text ILIKE '%Street Fighter%' OR g.franchises::text ILIKE '%Mega Man%' OR g.franchises::text ILIKE '%Ace Attorney%' OR g.franchises::text ILIKE '%Dead Rising%' OR g.franchises::text ILIKE '%Dragon''s Dogma%' OR g.franchises::text ILIKE '%Onimusha%' OR g.franchises::text ILIKE '%Dino Crisis%' OR g.franchises::text ILIKE '%Okami%' OR g.franchises::text ILIKE '%Darkstalkers%' OR g.title ILIKE '%Resident Evil%' OR g.title ILIKE '%Monster Hunter%' OR g.title ILIKE '%Devil May Cry%' OR g.title ILIKE '%Street Fighter%' OR g.title ILIKE '%Mega Man%' OR g.title ILIKE '%Ace Attorney%' OR g.title ILIKE '%Dead Rising%' OR g.title ILIKE '%Dragon''s Dogma%' OR g.title ILIKE '%Onimusha%' OR g.title ILIKE '%Dino Crisis%' OR g.title ILIKE '%Okami%' OR g.title ILIKE '%Darkstalkers%') AND g.title NOT ILIKE '%Smash Bros%' AND g.title NOT ILIKE '%Project X Zone%' AND g.title NOT ILIKE '%Vs. Capcom%' AND g.title NOT ILIKE '%Vs Capcom%' AND g.title NOT ILIKE '%All-Stars%' AND g.title NOT ILIKE '%Fortnite%' AND g.title NOT ILIKE '%Dead by Daylight%' AND g.title NOT ILIKE '%Teppen%' AND g.title NOT ILIKE '%Poker Night%' AND g.title NOT ILIKE '%Cross Tag%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Naughty Dog%' OR g.collection::text ILIKE '%Uncharted%' OR g.collection::text ILIKE '%The Last of Us%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Rockstar%' OR g.collection::text ILIKE '%Grand Theft Auto%' OR g.collection::text ILIKE '%Red Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%CD Projekt%' OR g.collection::text ILIKE '%Witcher%' OR g.collection::text ILIKE '%Cyberpunk%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Konami%' OR g.developer ILIKE '%Bloober Team%' OR g.developer ILIKE '%MercurySteam%' OR g.developer ILIKE '%PlatinumGames%' OR g.developer ILIKE '%HexaDrive%' OR g.developer ILIKE '%Double Helix%' OR g.developer ILIKE '%Climax%' OR g.developer ILIKE '%WayForward%' OR g.collection::text ILIKE '%Metal Gear%' OR g.collection::text ILIKE '%Silent Hill%' OR g.collection::text ILIKE '%Castlevania%' OR g.collection::text ILIKE '%Contra%' OR g.collection::text ILIKE '%Pro Evolution%' OR g.collection::text ILIKE '%eFootball%' OR g.collection::text ILIKE '%Suikoden%' OR g.collection::text ILIKE '%Bomberman%' OR g.collection::text ILIKE '%Frogger%' OR g.collection::text ILIKE '%Zone of the Enders%' OR g.franchises::text ILIKE '%Metal Gear%' OR g.franchises::text ILIKE '%Silent Hill%' OR g.franchises::text ILIKE '%Castlevania%' OR g.franchises::text ILIKE '%Contra%' OR g.franchises::text ILIKE '%Pro Evolution%' OR g.franchises::text ILIKE '%eFootball%' OR g.franchises::text ILIKE '%Suikoden%' OR g.franchises::text ILIKE '%Bomberman%' OR g.franchises::text ILIKE '%Frogger%' OR g.franchises::text ILIKE '%Zone of the Enders%' OR g.title ILIKE '%Metal Gear%' OR g.title ILIKE '%Silent Hill%' OR g.title ILIKE '%Castlevania%' OR g.title ILIKE '%Contra%' OR g.title ILIKE '%Pro Evolution%' OR g.title ILIKE '%eFootball%' OR g.title ILIKE '%Suikoden%' OR g.title ILIKE '%Bomberman%' OR g.title ILIKE '%Frogger%' OR g.title ILIKE '%Zone of the Enders%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Valve%' OR g.developer ILIKE '%Crowbar Collective%' OR g.title ILIKE '%Black Mesa%' OR g.collection::text ILIKE '%Half-Life%' OR g.collection::text ILIKE '%Portal%' OR g.collection::text ILIKE '%Left 4 Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Remedy%' OR g.collection::text ILIKE '%Alan Wake%' OR g.title ILIKE '%Control%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%' OR g.collection::text ILIKE '%Ninja Gaiden%' OR g.collection::text ILIKE '%Nioh%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Square Enix%' OR g.developer ILIKE '%Squaresoft%' OR g.developer ILIKE '%Enix%' OR g.collection::text ILIKE '%Final Fantasy%' OR g.collection::text ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.developer ILIKE '%Bethesda%' OR g.developer ILIKE '%ZeniMax%' OR g.developer ILIKE '%Arkane%' OR g.developer ILIKE '%id Software%' OR g.developer ILIKE '%MachineGames%' OR g.collection::text ILIKE '%Elder Scrolls%' OR g.collection::text ILIKE '%Fallout%' OR g.collection::text ILIKE '%DOOM%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%' OR g.title ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%' OR g.title ILIKE '%Super Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%' OR g.title ILIKE '%Pokemon%' OR g.title ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%' OR g.title ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%' OR g.title ILIKE '%Dark Souls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%' OR g.title ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%' OR g.title ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Call of Duty%' OR g.franchises::text ILIKE '%Call of Duty%' OR g.title ILIKE '%Call of Duty%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Elder Scrolls%' OR g.franchises::text ILIKE '%Elder Scrolls%' OR g.title ILIKE '%Elder Scrolls%' OR g.title ILIKE '%Skyrim%' OR g.title ILIKE '%Oblivion%' OR g.title ILIKE '%Morrowind%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%God of War%' OR g.franchises::text ILIKE '%God of War%' OR g.title ILIKE '%God of War%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Tomb Raider%' OR g.franchises::text ILIKE '%Tomb Raider%' OR g.title ILIKE '%Tomb Raider%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Monster Hunter%' OR g.franchises::text ILIKE '%Monster Hunter%' OR g.title ILIKE '%Monster Hunter%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Kingdom Hearts%' OR g.franchises::text ILIKE '%Kingdom Hearts%' OR g.title ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Silent Hill%' OR g.franchises::text ILIKE '%Silent Hill%' OR g.title ILIKE '%Silent Hill%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Metroid%' OR g.franchises::text ILIKE '%Metroid%' OR g.title ILIKE '%Metroid%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Kirby%' OR g.franchises::text ILIKE '%Kirby%' OR g.title ILIKE '%Kirby%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Devil May Cry%' OR g.franchises::text ILIKE '%Devil May Cry%' OR g.title ILIKE '%Devil May Cry%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Castlevania%' OR g.franchises::text ILIKE '%Castlevania%' OR g.title ILIKE '%Castlevania%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Mass Effect%' OR g.franchises::text ILIKE '%Mass Effect%' OR g.title ILIKE '%Mass Effect%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%DOOM%' OR g.franchises::text ILIKE '%DOOM%' OR g.title ILIKE '%DOOM%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%' OR g.title ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%' OR g.title ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%' OR g.title ILIKE '%Metro 2033%' OR g.title ILIKE '%Metro: Last Light%' OR g.title ILIKE '%Metro Exodus%') AND g.title NOT ILIKE '%Metroid%' AND g.collection::text NOT ILIKE '%Metroid%' AND g.franchises::text NOT ILIKE '%Metroid%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%' OR g.title ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%' OR g.title ILIKE '%Yakuza%' OR g.title ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Xenoblade%' OR g.title ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%' OR g.title ILIKE '%Persona%' OR g.title ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Halo%' OR g.franchises::text ILIKE '%Halo%' OR g.title ILIKE '%Halo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END),
        count(DISTINCT CASE WHEN (g.collection::text ILIKE '%Sonic%' OR g.franchises::text ILIKE '%Sonic%' OR g.title ILIKE '%Sonic%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL) THEN r.game_id END)
    INTO
        v_kojima_count,
        v_fromsoftware_count,
        v_nintendo_count,
        v_capcom_count,
        v_naughty_dog_count,
        v_rockstar_count,
        v_cd_projekt_count,
        v_konami_count,
        v_valve_count,
        v_remedy_count,
        v_team_ninja_count,
        v_square_enix_count,
        v_bethesda_count,
        v_zelda_count,
        v_mario_count,
        v_pokemon_count,
        v_re_count,
        v_ds_count,
        v_ac_count,
        v_ff_count,
        v_cod_count,
        v_es_count,
        v_gow_count,
        v_tomb_count,
        v_mh_count,
        v_kh_count,
        v_sh_count,
        v_metroid_count,
        v_kirby_count,
        v_dmc_count,
        v_castlevania_count,
        v_me_count,
        v_doom_count,
        v_bioshock_count,
        v_borderlands_count,
        v_metro_count,
        v_dead_space_count,
        v_yakuza_count,
        v_xenoblade_count,
        v_persona_count,
        v_halo_count,
        v_sonic_count
    FROM reviews r 
    JOIN games g ON r.game_id = g.igdb_id
    WHERE r.user_id = uid AND r.status = 'beaten';

    -- GENERALES (Optimizadas con IF EXISTS donde aplique en futuras pasadas, de momento se mantienen separadas por brevedad
    -- o las unimos si es simple). Las generales ya se comprobaban con COUNT o EXISTS así:
    IF EXISTS (SELECT 1 FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') THEN valid_ids := array_append(valid_ids, 'time_traveler'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') >= 20 THEN valid_ids := array_append(valid_ids, 'scholar_20th'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND extract(year from r.created_at) = extract(year from g.release_date::date)) >= 10 THEN valid_ids := array_append(valid_ids, 'vanguard'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN valid_ids := array_append(valid_ids, 'pc_master_race'); END IF;
    IF (SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL) >= 15 THEN valid_ids := array_append(valid_ids, 'multiplatform'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.genres::text ILIKE '%Role-playing%') >= 30 THEN valid_ids := array_append(valid_ids, 'rpg_veteran'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.game_modes::text ILIKE '%Single player%') >= 50 THEN valid_ids := array_append(valid_ids, 'lone_wolf'); END IF;

    -- ASIGNACIÓN DE LOGROS (Igual que antes, ya que los counts están populados)
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

    IF v_square_enix_count >= 1 THEN valid_ids := array_append(valid_ids, 'square_enix_1'); END IF;
    IF v_square_enix_count >= 5 THEN valid_ids := array_append(valid_ids, 'square_enix_5'); END IF;
    IF v_square_enix_count >= 10 THEN valid_ids := array_append(valid_ids, 'square_enix_10'); END IF;

    IF v_bethesda_count >= 1 THEN valid_ids := array_append(valid_ids, 'bethesda_1'); END IF;
    IF v_bethesda_count >= 3 THEN valid_ids := array_append(valid_ids, 'bethesda_3'); END IF;
    IF v_bethesda_count >= 5 THEN valid_ids := array_append(valid_ids, 'bethesda_5'); END IF;

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

    IF v_cod_count >= 1 THEN valid_ids := array_append(valid_ids, 'call_of_duty_1'); END IF;
    IF v_cod_count >= 3 THEN valid_ids := array_append(valid_ids, 'call_of_duty_3'); END IF;
    IF v_cod_count >= 5 THEN valid_ids := array_append(valid_ids, 'call_of_duty_5'); END IF;

    IF v_es_count >= 1 THEN valid_ids := array_append(valid_ids, 'elder_scrolls_1'); END IF;
    IF v_es_count >= 3 THEN valid_ids := array_append(valid_ids, 'elder_scrolls_3'); END IF;
    IF v_es_count >= 5 THEN valid_ids := array_append(valid_ids, 'elder_scrolls_5'); END IF;

    IF v_gow_count >= 1 THEN valid_ids := array_append(valid_ids, 'god_of_war_1'); END IF;
    IF v_gow_count >= 3 THEN valid_ids := array_append(valid_ids, 'god_of_war_3'); END IF;
    IF v_gow_count >= 5 THEN valid_ids := array_append(valid_ids, 'god_of_war_5'); END IF;

    IF v_tomb_count >= 1 THEN valid_ids := array_append(valid_ids, 'tomb_raider_1'); END IF;
    IF v_tomb_count >= 3 THEN valid_ids := array_append(valid_ids, 'tomb_raider_3'); END IF;
    IF v_tomb_count >= 5 THEN valid_ids := array_append(valid_ids, 'tomb_raider_5'); END IF;

    IF v_mh_count >= 1 THEN valid_ids := array_append(valid_ids, 'monster_hunter_1'); END IF;
    IF v_mh_count >= 3 THEN valid_ids := array_append(valid_ids, 'monster_hunter_3'); END IF;
    IF v_mh_count >= 5 THEN valid_ids := array_append(valid_ids, 'monster_hunter_5'); END IF;

    IF v_kh_count >= 1 THEN valid_ids := array_append(valid_ids, 'kingdom_hearts_1'); END IF;
    IF v_kh_count >= 3 THEN valid_ids := array_append(valid_ids, 'kingdom_hearts_3'); END IF;
    IF v_kh_count >= 5 THEN valid_ids := array_append(valid_ids, 'kingdom_hearts_5'); END IF;

    IF v_sh_count >= 1 THEN valid_ids := array_append(valid_ids, 'silent_hill_1'); END IF;
    IF v_sh_count >= 3 THEN valid_ids := array_append(valid_ids, 'silent_hill_3'); END IF;
    IF v_sh_count >= 5 THEN valid_ids := array_append(valid_ids, 'silent_hill_5'); END IF;

    IF v_metroid_count >= 1 THEN valid_ids := array_append(valid_ids, 'metroid_1'); END IF;
    IF v_metroid_count >= 3 THEN valid_ids := array_append(valid_ids, 'metroid_3'); END IF;

    IF v_kirby_count >= 1 THEN valid_ids := array_append(valid_ids, 'kirby_1'); END IF;
    IF v_kirby_count >= 3 THEN valid_ids := array_append(valid_ids, 'kirby_3'); END IF;

    IF v_dmc_count >= 1 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_1'); END IF;
    IF v_dmc_count >= 3 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_3'); END IF;

    IF v_castlevania_count >= 1 THEN valid_ids := array_append(valid_ids, 'castlevania_1'); END IF;
    IF v_castlevania_count >= 3 THEN valid_ids := array_append(valid_ids, 'castlevania_3'); END IF;

    IF v_me_count >= 1 THEN valid_ids := array_append(valid_ids, 'mass_effect_1'); END IF;
    IF v_me_count >= 3 THEN valid_ids := array_append(valid_ids, 'mass_effect_3'); END IF;

    IF v_doom_count >= 1 THEN valid_ids := array_append(valid_ids, 'doom_1'); END IF;
    IF v_doom_count >= 3 THEN valid_ids := array_append(valid_ids, 'doom_3'); END IF;

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

    IF v_xenoblade_count >= 1 THEN valid_ids := array_append(valid_ids, 'xenoblade_1'); END IF;
    IF v_xenoblade_count >= 3 THEN valid_ids := array_append(valid_ids, 'xenoblade_3'); END IF;

    IF v_persona_count >= 1 THEN valid_ids := array_append(valid_ids, 'persona_1'); END IF;
    IF v_persona_count >= 3 THEN valid_ids := array_append(valid_ids, 'persona_3'); END IF;

    IF v_halo_count >= 1 THEN valid_ids := array_append(valid_ids, 'halo_1'); END IF;
    IF v_halo_count >= 3 THEN valid_ids := array_append(valid_ids, 'halo_3'); END IF;

    IF v_sonic_count >= 1 THEN valid_ids := array_append(valid_ids, 'sonic_1'); END IF;
    IF v_sonic_count >= 3 THEN valid_ids := array_append(valid_ids, 'sonic_3'); END IF;

    -- Upsert final de logros
    DELETE FROM user_achievements WHERE user_id = uid;
    IF array_length(valid_ids, 1) > 0 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        SELECT uid, unnest(valid_ids)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;
    END IF;

END;
$$;
