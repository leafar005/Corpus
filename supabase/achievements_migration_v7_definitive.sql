-- =====================================================================
-- CORPUS: MIGRACIÓN DE LOGROS DEFINITIVA (v7 - BLINDADA)
-- 1. Actualiza TODAS las descripciones genéricas con nombres reales.
-- 2. Arregla el falso positivo de Metro vs Metroid.
-- 3. Arregla el conteo de FromSoftware (incluyendo remakes externos).
-- 4. Arregla el conteo duplicado (DISTINCT) en Zelda y demás sagas.
-- =====================================================================

-- 1. Actualizar descripciones para que sean explícitas y claras
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
-- Compañías
('kojima_1', 'Devoto de Kojima (Nivel 1)', 'Completa 1 juego de Kojima Productions / Metal Gear.', 'psychology', 'common', 10, 'companies'),
('kojima_3', 'Devoto de Kojima (Nivel 2)', 'Completa 3 juegos de Kojima Productions / Metal Gear.', 'psychology', 'rare', 50, 'companies'),
('kojima_5', 'Devoto de Kojima (Maestro)', 'Completa 5 juegos de Kojima Productions / Metal Gear.', 'psychology', 'epic', 100, 'companies'),

('fromsoftware_1', 'Abraza el Sufrimiento (Nivel 1)', 'Completa 1 juego de FromSoftware / Soulsborne.', 'fireplace', 'common', 10, 'companies'),
('fromsoftware_3', 'Abraza el Sufrimiento (Nivel 2)', 'Completa 3 juegos de FromSoftware / Soulsborne.', 'fireplace', 'rare', 50, 'companies'),
('fromsoftware_all', 'Alma Oscura (Maestro)', 'Completa 7 juegos de FromSoftware / Soulsborne.', 'fireplace', 'epic', 200, 'companies'),

('nintendo_1', 'Sello de Calidad (Nivel 1)', 'Completa 1 juego desarrollado por Nintendo.', 'sports_esports', 'common', 10, 'companies'),
('nintendo_5', 'Sello de Calidad (Nivel 2)', 'Completa 5 juegos desarrollados por Nintendo.', 'sports_esports', 'rare', 50, 'companies'),
('nintendo_10', 'Sello de Calidad (Maestro)', 'Completa 10 juegos desarrollados por Nintendo.', 'sports_esports', 'epic', 100, 'companies'),

('capcom_1', 'Superviviente Nato (Nivel 1)', 'Completa 1 juego de Capcom (Resident Evil, Monster Hunter, etc).', 'pets', 'common', 10, 'companies'),
('capcom_5', 'Superviviente Nato (Nivel 2)', 'Completa 5 juegos de Capcom (Resident Evil, Monster Hunter, etc).', 'pets', 'rare', 50, 'companies'),
('capcom_10', 'Superviviente Nato (Maestro)', 'Completa 10 juegos de Capcom (Resident Evil, Monster Hunter, etc).', 'pets', 'epic', 100, 'companies'),

('naughty_dog_1', 'Cazatesoros (Nivel 1)', 'Completa 1 juego de Naughty Dog (Uncharted, TLOU, Crash, Jak).', 'explore', 'common', 10, 'companies'),
('naughty_dog_3', 'Cazatesoros (Nivel 2)', 'Completa 3 juegos de Naughty Dog.', 'explore', 'rare', 50, 'companies'),
('naughty_dog_5', 'Cazatesoros (Maestro)', 'Completa 5 juegos de Naughty Dog.', 'explore', 'epic', 100, 'companies'),

('rockstar_1', 'Forajido (Nivel 1)', 'Completa 1 juego de Rockstar Games (GTA, Red Dead, etc).', 'local_police', 'common', 10, 'companies'),
('rockstar_3', 'Forajido de Leyenda (Maestro)', 'Completa 3 juegos de Rockstar Games.', 'local_police', 'rare', 50, 'companies'),

('cd_projekt_1', 'Brujo (Nivel 1)', 'Completa 1 juego de CD Projekt RED (The Witcher, Cyberpunk).', 'science', 'common', 10, 'companies'),
('cd_projekt_3', 'Lobo Blanco (Maestro)', 'Completa 3 juegos de CD Projekt RED.', 'science', 'rare', 50, 'companies'),

('konami_1', 'Up Up Down Down (Nivel 1)', 'Completa 1 juego de Konami (Metal Gear, Silent Hill, Castlevania).', 'sports_esports', 'common', 10, 'companies'),
('konami_5', 'Konami Code (Maestro)', 'Completa 5 juegos de Konami.', 'sports_esports', 'rare', 50, 'companies'),

('valve_1', 'Apertura de Ciencia (Nivel 1)', 'Completa 1 juego del universo Valve (Half-Life, Portal, L4D).', 'science', 'common', 10, 'companies'),
('valve_3', 'GabeN (Maestro)', 'Completa 3 juegos del universo Valve.', 'science', 'rare', 50, 'companies'),

('remedy_1', 'Control Alterado (Nivel 1)', 'Completa 1 juego de Remedy (Alan Wake, Control, Max Payne).', 'visibility', 'common', 10, 'companies'),
('remedy_3', 'Alan Wake (Maestro)', 'Completa 3 juegos de Remedy Entertainment.', 'visibility', 'rare', 50, 'companies'),

('team_ninja_1', 'Ninja de Élite (Nivel 1)', 'Completa 1 juego de Team Ninja / Koei Tecmo (Ninja Gaiden, Nioh).', 'colorize', 'common', 10, 'companies'),
('team_ninja_5', 'Maestro del Dojo (Maestro)', 'Completa 5 juegos de Team Ninja / Koei Tecmo.', 'colorize', 'rare', 50, 'companies'),

-- Franquicias y Sagas
('zelda_1', 'Héroe del Tiempo (Nivel 1)', 'Completa 1 juego de la saga The Legend of Zelda.', 'shield', 'common', 10, 'franchises'),
('zelda_3', 'Héroe del Tiempo (Nivel 2)', 'Completa 3 juegos de la saga The Legend of Zelda.', 'shield', 'rare', 50, 'franchises'),
('zelda_all', 'Portador de la Trifuerza (Maestro)', 'Completa 7 juegos de la saga The Legend of Zelda.', 'shield', 'epic', 200, 'franchises'),

('mario_1', '¡Mamma Mia! (Nivel 1)', 'Completa 1 juego de la saga Super Mario.', 'plumbing', 'common', 10, 'franchises'),
('mario_5', '¡Mamma Mia! (Nivel 2)', 'Completa 5 juegos de la saga Super Mario.', 'plumbing', 'rare', 50, 'franchises'),
('mario_10', '¡Mamma Mia! (Maestro)', 'Completa 10 juegos de la saga Super Mario.', 'plumbing', 'epic', 100, 'franchises'),

('pokemon_1', 'Entrenador (Nivel 1)', 'Completa 1 juego de la saga Pokémon.', 'catching_pokemon', 'common', 10, 'franchises'),
('pokemon_3', 'Entrenador Pokémon (Nivel 2)', 'Completa 3 juegos de la saga Pokémon.', 'catching_pokemon', 'rare', 50, 'franchises'),
('pokemon_5', 'Entrenador Pokémon (Maestro)', 'Completa 5 juegos de la saga Pokémon.', 'catching_pokemon', 'epic', 100, 'franchises'),

('resident_evil_1', 'Agente de S.T.A.R.S. (Nivel 1)', 'Completa 1 juego de Resident Evil.', 'biotech', 'common', 10, 'franchises'),
('resident_evil_3', 'Agente de S.T.A.R.S. (Nivel 2)', 'Completa 3 juegos de Resident Evil.', 'biotech', 'rare', 50, 'franchises'),
('resident_evil_5', 'Agente de S.T.A.R.S. (Maestro)', 'Completa 5 juegos de Resident Evil.', 'biotech', 'epic', 100, 'franchises'),

('dark_souls_1', 'Hueco (Nivel 1)', 'Completa 1 juego de Dark Souls / Elden Ring / Sekiro.', 'local_fire_department', 'common', 10, 'franchises'),
('dark_souls_all', 'Señor de la Ceniza (Maestro)', 'Completa 3 juegos de Dark Souls / Elden Ring / Sekiro.', 'local_fire_department', 'epic', 100, 'franchises'),

('assassins_creed_1', 'Asesino (Nivel 1)', 'Completa 1 juego de Assassin''s Creed.', 'visibility_off', 'common', 10, 'franchises'),
('assassins_creed_3', 'Maestro Asesino (Nivel 2)', 'Completa 3 juegos de Assassin''s Creed.', 'visibility_off', 'rare', 50, 'franchises'),
('assassins_creed_6', 'Maestro Asesino (Maestro)', 'Completa 6 juegos de Assassin''s Creed.', 'visibility_off', 'epic', 100, 'franchises'),

('final_fantasy_1', 'Cristal (Nivel 1)', 'Completa 1 juego de Final Fantasy.', 'auto_awesome', 'common', 10, 'franchises'),
('final_fantasy_3', 'Guerrero de la Luz (Nivel 2)', 'Completa 3 juegos de Final Fantasy.', 'auto_awesome', 'rare', 50, 'franchises'),
('final_fantasy_5', 'Guerrero de la Luz (Maestro)', 'Completa 5 juegos de Final Fantasy.', 'auto_awesome', 'epic', 100, 'franchises'),

('bioshock_1', 'Bienvenido a Rapture (Nivel 1)', 'Completa 1 juego de la saga BioShock.', 'science', 'common', 10, 'franchises'),
('bioshock_3', '¿Un hombre elige... (Maestro)', 'Completa 3 juegos de la saga BioShock.', 'science', 'epic', 100, 'franchises'),

('borderlands_1', 'Buscavidas (Nivel 1)', 'Completa 1 juego de la saga Borderlands.', 'explore', 'common', 10, 'franchises'),
('borderlands_3', 'Vault Hunter (Maestro)', 'Completa 3 juegos de la saga Borderlands.', 'explore', 'rare', 50, 'franchises'),

('metro_1', 'Superviviente del Metro (Nivel 1)', 'Completa 1 juego de la saga postapocalíptica Metro (2033, Last Light, Exodus).', 'hourglass_empty', 'common', 10, 'franchises'),
('metro_3', 'Artyom (Maestro)', 'Completa 3 juegos de la saga Metro.', 'hourglass_empty', 'epic', 100, 'franchises'),

('dead_space_1', 'Ingeniero a bordo (Nivel 1)', 'Completa 1 juego de Dead Space.', 'science', 'common', 10, 'franchises'),
('dead_space_3', 'Isaac Clarke (Maestro)', 'Completa 3 juegos de Dead Space.', 'science', 'epic', 100, 'franchises'),

('yakuza_1', 'Yakuza de Barrio (Nivel 1)', 'Completa 1 juego de Yakuza / Like a Dragon.', 'local_police', 'common', 10, 'franchises'),
('yakuza_3', 'Dragón de Dojima (Nivel 2)', 'Completa 3 juegos de Yakuza / Like a Dragon.', 'local_police', 'rare', 50, 'franchises'),
('yakuza_6', 'Kiryu Kazuma (Maestro)', 'Completa 6 juegos de Yakuza / Like a Dragon.', 'local_police', 'epic', 100, 'franchises'),

('xenoblade_1', 'Monado (Nivel 1)', 'Completa 1 juego de la saga Xenoblade Chronicles.', 'menu_book', 'common', 10, 'franchises'),
('xenoblade_3', 'Ponspect (Maestro)', 'Completa 3 juegos de la saga Xenoblade Chronicles.', 'menu_book', 'rare', 50, 'franchises'),

('persona_1', 'Explorador de Sombras (Nivel 1)', 'Completa 1 juego de Persona o Shin Megami Tensei.', 'psychology', 'common', 10, 'franchises'),
('persona_3', 'Wild Card (Nivel 2)', 'Completa 3 juegos de Persona o Shin Megami Tensei.', 'psychology', 'rare', 50, 'franchises'),
('persona_5', 'Phantom Thief (Maestro)', 'Completa 5 juegos de Persona o Shin Megami Tensei.', 'psychology', 'epic', 100, 'franchises'),

('halo_1', 'Spartan (Nivel 1)', 'Completa 1 juego de la saga Halo.', 'shield', 'common', 10, 'franchises'),
('halo_3', 'Jefe Maestro (Maestro)', 'Completa 3 juegos de la saga Halo.', 'shield', 'epic', 100, 'franchises'),

('sonic_1', 'Erizo Azul (Nivel 1)', 'Completa 1 juego de Sonic the Hedgehog.', 'rocket_launch', 'common', 10, 'franchises'),
('sonic_3', 'Súper Sonic (Maestro)', 'Completa 3 juegos de Sonic the Hedgehog.', 'rocket_launch', 'rare', 50, 'franchises')

ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name, 
  description = EXCLUDED.description, 
  xp_reward = EXCLUDED.xp_reward,
  rarity = EXCLUDED.rarity;


-- 2. Función SQL con conteos estrictos sin duplicados (DISTINCT r.game_id)
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
    
    -- Franquicias y Sagas
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
    v_halo_count INT;
    v_sonic_count INT;
BEGIN
    -- ---------------------------------------------------------
    -- LOGROS GENERALES
    -- ---------------------------------------------------------
    IF EXISTS (SELECT 1 FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') THEN
        valid_ids := array_append(valid_ids, 'time_traveler');
    END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') >= 20 THEN
        valid_ids := array_append(valid_ids, 'scholar_20th');
    END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND extract(year from r.created_at) = extract(year from g.release_date::date)) >= 10 THEN
        valid_ids := array_append(valid_ids, 'vanguard');
    END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'pc_master_race');
    END IF;
    IF (SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL) >= 15 THEN
        valid_ids := array_append(valid_ids, 'multiplatform');
    END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.genres::text ILIKE '%Role-playing%') >= 30 THEN
        valid_ids := array_append(valid_ids, 'rpg_veteran');
    END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.game_modes::text ILIKE '%Single player%') >= 50 THEN
        valid_ids := array_append(valid_ids, 'lone_wolf');
    END IF;

    -- ---------------------------------------------------------
    -- CONTEOS PARA SAGAS / COMPAÑÍAS (DISTINCT game_id)
    -- ---------------------------------------------------------
    SELECT count(DISTINCT r.game_id) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Kojima%' OR g.title ILIKE '%Metal Gear%' OR g.title ILIKE '%Death Stranding%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%FromSoftware%' OR g.title ILIKE '%Demon''s Souls%' OR g.title ILIKE '%Demon Souls%' OR g.title ILIKE '%Dark Souls%' OR g.title ILIKE '%Elden Ring%' OR g.title ILIKE '%Bloodborne%' OR g.title ILIKE '%Sekiro%' OR g.title ILIKE '%Armored Core%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Capcom%' OR g.collection::text ILIKE '%Resident Evil%' OR g.collection::text ILIKE '%Monster Hunter%' OR g.collection::text ILIKE '%Devil May Cry%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Naughty Dog%' OR g.collection::text ILIKE '%Uncharted%' OR g.collection::text ILIKE '%The Last of Us%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Rockstar%' OR g.collection::text ILIKE '%Grand Theft Auto%' OR g.collection::text ILIKE '%Red Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%CD Projekt%' OR g.collection::text ILIKE '%Witcher%' OR g.collection::text ILIKE '%Cyberpunk%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Konami%' OR g.collection::text ILIKE '%Metal Gear%' OR g.collection::text ILIKE '%Silent Hill%' OR g.collection::text ILIKE '%Castlevania%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Valve%' OR g.developer ILIKE '%Crowbar Collective%' OR g.title ILIKE '%Black Mesa%' OR g.collection::text ILIKE '%Half-Life%' OR g.collection::text ILIKE '%Portal%' OR g.collection::text ILIKE '%Left 4 Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Remedy%' OR g.collection::text ILIKE '%Alan Wake%' OR g.title ILIKE '%Control%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%' OR g.collection::text ILIKE '%Ninja Gaiden%' OR g.collection::text ILIKE '%Nioh%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    SELECT count(DISTINCT r.game_id) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%' OR g.title ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%' OR g.title ILIKE '%Super Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%' OR g.title ILIKE '%Pokemon%' OR g.title ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%' OR g.title ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%' OR g.title ILIKE '%Dark Souls%' OR g.title ILIKE '%Elden Ring%' OR g.title ILIKE '%Sekiro%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%' OR g.title ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%' OR g.title ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%' OR g.title ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%' OR g.title ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    -- EXCLUSIÓN EXPLÍCITA DE METROID PARA EL LOGRO DE METRO
    SELECT count(DISTINCT r.game_id) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%' OR g.title ILIKE '%Metro 2033%' OR g.title ILIKE '%Metro: Last Light%' OR g.title ILIKE '%Metro Exodus%') AND g.title NOT ILIKE '%Metroid%' AND g.collection::text NOT ILIKE '%Metroid%' AND g.franchises::text NOT ILIKE '%Metroid%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    SELECT count(DISTINCT r.game_id) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%' OR g.title ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_yakuza_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%' OR g.title ILIKE '%Yakuza%' OR g.title ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    -- INCLUSIÓN EXPLÍCITA DE TÍTULO PARA XENOBLADE
    SELECT count(DISTINCT r.game_id) INTO v_xenoblade_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Xenoblade%' OR g.title ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    SELECT count(DISTINCT r.game_id) INTO v_persona_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%' OR g.title ILIKE '%Persona%' OR g.title ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_halo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Halo%' OR g.franchises::text ILIKE '%Halo%' OR g.title ILIKE '%Halo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_sonic_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Sonic%' OR g.franchises::text ILIKE '%Sonic%' OR g.title ILIKE '%Sonic%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- ---------------------------------------------------------
    -- ASIGNACIÓN A VALID_IDS
    -- ---------------------------------------------------------
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

    IF v_halo_count >= 1 THEN valid_ids := array_append(valid_ids, 'halo_1'); END IF;
    IF v_halo_count >= 3 THEN valid_ids := array_append(valid_ids, 'halo_3'); END IF;

    IF v_sonic_count >= 1 THEN valid_ids := array_append(valid_ids, 'sonic_1'); END IF;
    IF v_sonic_count >= 3 THEN valid_ids := array_append(valid_ids, 'sonic_3'); END IF;

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

-- 3. Recalcular retroactivamente para todos los usuarios
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT id FROM auth.users LOOP
        PERFORM public.check_user_achievements(r.id);
        PERFORM public.calculate_user_xp(r.id);
    END LOOP;
END $$;
