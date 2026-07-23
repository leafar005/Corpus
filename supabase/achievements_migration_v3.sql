-- =========================================================================
-- CORPUS: MIGRACIÓN DE LOGROS v3
-- Fusiones, nuevos hitos y nuevos logros de sagas
-- Ejecutar en Supabase SQL Editor
-- =========================================================================

-- =========================================================================
-- PARTE 1: FUSIONAR DARK SOULS (eliminar duplicado, crear hitos 1/2/3)
-- =========================================================================

-- Borrar los dos logros viejos (si no existen, los INSERT los crearán)
DELETE FROM user_achievements WHERE achievement_id IN ('dark_souls_1', 'dark_souls_all');
DELETE FROM achievements WHERE id IN ('dark_souls_1', 'dark_souls_all');

-- Crear los 3 hitos unificados
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('dark_souls_1',   'Hueco (Nivel 1)',          'Completa 1 juego de la saga Dark Souls / Elden Ring.', 'local_fire_department', 'common', 10,  'franchises'),
  ('dark_souls_2',   'No-muerto (Nivel 2)',       'Completa 2 juegos de la saga Dark Souls / Elden Ring.', 'local_fire_department', 'rare',   50,  'franchises'),
  ('dark_souls_all', 'Señor de la Ceniza (Maestro)', 'Completa la trilogía Dark Souls.',                  'local_fire_department', 'epic',  100,  'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, xp_reward = EXCLUDED.xp_reward, rarity = EXCLUDED.rarity;

-- =========================================================================
-- PARTE 2: AÑADIR HITOS INTERMEDIOS A SAGAS EXISTENTES
-- =========================================================================

-- Final Fantasy: hitos 1, 3, 6, 10 (hay más de 50 entradas)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('final_fantasy_6',  'Protector del Cristal (Nivel 3)', 'Completa 6 juegos de Final Fantasy.',  'auto_awesome', 'epic',    100, 'franchises'),
  ('final_fantasy_10', 'Guerrero Eterno (Maestro)',        'Completa 10 juegos de Final Fantasy.', 'auto_awesome', 'legendary', 300, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Capcom: hitos 1, 5, 10, 20 (hay más de 50 juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('capcom_10', 'Depredador Nato (Nivel 3)', 'Completa 10 juegos de Capcom.',  'pets', 'epic',    100, 'companies'),
  ('capcom_20', 'Élite de Capcom (Maestro)', 'Completa 20 juegos de Capcom.',  'pets', 'legendary', 300, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Assassin's Creed: hitos 1, 5, 10, 15 (hay más de 50 juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('assassins_creed_10', 'Gran Maestre (Nivel 3)',          'Completa 10 juegos de Assassin''s Creed.', 'visibility_off', 'epic',    100, 'franchises'),
  ('assassins_creed_15', 'Legado de los Asesinos (Maestro)','Completa 15 juegos de Assassin''s Creed.', 'visibility_off', 'legendary', 300, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Call of Duty: hitos 1, 5, 10 (hay más de 50 juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('call_of_duty_1',  'Recluta (Nivel 1)',        'Completa 1 juego de Call of Duty.',  'local_police', 'common', 10,  'franchises'),
  ('call_of_duty_5',  'Comandante (Nivel 2)',      'Completa 5 juegos de Call of Duty.', 'local_police', 'rare',   50,  'franchises'),
  ('call_of_duty_10', 'Leyenda de Guerra (Maestro)','Completa 10 juegos de Call of Duty.','local_police', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- God of War: hitos 1, 3, 6 (hay 38 juegos en IGDB incluyendo ports/remasters)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('god_of_war_1', 'Espartano (Nivel 1)',    'Completa 1 juego de God of War.', 'colorize', 'common', 10,  'franchises'),
  ('god_of_war_3', 'Azote de Dioses (Nivel 2)', 'Completa 3 juegos de God of War.', 'colorize', 'rare',  50,  'franchises'),
  ('god_of_war_6', 'Kratos (Maestro)',        'Completa 6 juegos de God of War.', 'colorize', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- The Elder Scrolls: hitos 1, 3, 5 (hay 22 entradas entre juegos base y ports)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('elder_scrolls_1', 'Forajido de Tamriel (Nivel 1)',  'Completa 1 juego de The Elder Scrolls.',  'menu_book', 'common', 10, 'franchises'),
  ('elder_scrolls_3', 'Dovahkiin (Nivel 2)',             'Completa 3 juegos de The Elder Scrolls.', 'menu_book', 'rare',   50, 'franchises'),
  ('elder_scrolls_5', 'Campeón del Cielo (Maestro)',     'Completa 5 juegos de The Elder Scrolls.', 'menu_book', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Halo: hitos 1, 3, 6 (la saga principal tiene 6 juegos numerados + extras)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('halo_1', 'Marine UNSC (Nivel 1)',    'Completa 1 juego de Halo.',  'shield', 'common', 10,  'franchises'),
  ('halo_3', 'Spartan II (Nivel 2)',     'Completa 3 juegos de Halo.', 'shield', 'rare',   50,  'franchises'),
  ('halo_6', 'Jefe Maestro (Maestro)',   'Completa 6 juegos de Halo.', 'shield', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Sonic: hitos 1, 5, 10 (hay más de 50)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('sonic_1',  'Más rápido que el sonido (Nivel 1)', 'Completa 1 juego de Sonic.', 'rocket_launch', 'common', 10,  'franchises'),
  ('sonic_5',  'Speed Demon (Nivel 2)',               'Completa 5 juegos de Sonic.', 'rocket_launch', 'rare',   50,  'franchises'),
  ('sonic_10', 'Corredor Definitivo (Maestro)',        'Completa 10 juegos de Sonic.', 'rocket_launch', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Tomb Raider: hitos 1, 3, 6 (hay muchos incluyendo remasters)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('tomb_raider_1', 'Exploradora (Nivel 1)',     'Completa 1 juego de Tomb Raider.',  'explore', 'common', 10,  'franchises'),
  ('tomb_raider_3', 'Cazadora de Tesoros (Nivel 2)', 'Completa 3 juegos de Tomb Raider.', 'explore', 'rare',   50,  'franchises'),
  ('tomb_raider_6', 'Lara Croft (Maestro)',          'Completa 6 juegos de Tomb Raider.', 'explore', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Monster Hunter: hitos 1, 3, 6 (hay 45 en IGDB)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('monster_hunter_1', 'Cazador de Bajo Rango (Nivel 1)',  'Completa 1 juego de Monster Hunter.', 'pets', 'common', 10,  'franchises'),
  ('monster_hunter_3', 'Cazador de Alto Rango (Nivel 2)',  'Completa 3 juegos de Monster Hunter.', 'pets', 'rare',   50,  'franchises'),
  ('monster_hunter_6', 'Rey de los Cazadores (Maestro)',   'Completa 6 juegos de Monster Hunter.', 'pets', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Kingdom Hearts: hitos 1, 3, 6 (hay 44 en IGDB incluyendo ports)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('kingdom_hearts_1', 'Portador de la Llave (Nivel 1)',  'Completa 1 juego de Kingdom Hearts.', 'catching_pokemon', 'common', 10,  'franchises'),
  ('kingdom_hearts_3', 'Guardián del Corazón (Nivel 2)',  'Completa 3 juegos de Kingdom Hearts.', 'catching_pokemon', 'rare',   50,  'franchises'),
  ('kingdom_hearts_6', 'Maestro Keyblade (Maestro)',       'Completa 6 juegos de Kingdom Hearts.', 'catching_pokemon', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Silent Hill: hitos 1, 3 (hay 38 en IGDB pero muchos son ports; saga principal son 8)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('silent_hill_1', 'Niebla Inquietante (Nivel 1)', 'Completa 1 juego de Silent Hill.',  'visibility_off', 'common', 10, 'franchises'),
  ('silent_hill_3', 'La Oscuridad Llama (Maestro)', 'Completa 3 juegos de Silent Hill.', 'visibility_off', 'rare',   50, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Metroid: hitos 1, 3, 6 (hay 42 en IGDB)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('metroid_1', 'Cazarrecompensas (Nivel 1)',  'Completa 1 juego de Metroid.',  'rocket_launch', 'common', 10,  'franchises'),
  ('metroid_3', 'Samus (Nivel 2)',             'Completa 3 juegos de Metroid.', 'rocket_launch', 'rare',   50,  'franchises'),
  ('metroid_6', 'Última Cazadora (Maestro)',   'Completa 6 juegos de Metroid.', 'rocket_launch', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Kirby: hitos 1, 5, 10 (hay 50+ juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('kirby_1',  'Rosa y Redondo (Nivel 1)',  'Completa 1 juego de Kirby.',   'catching_pokemon', 'common', 10,  'franchises'),
  ('kirby_5',  'Inhala Todo (Nivel 2)',     'Completa 5 juegos de Kirby.',  'catching_pokemon', 'rare',   50,  'franchises'),
  ('kirby_10', 'Héroe de Dream Land (Maestro)','Completa 10 juegos de Kirby.','catching_pokemon', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Devil May Cry: hitos 1, 3, 5 (35 en IGDB con ports/remasters)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('devil_may_cry_1', 'Cazademonios (Nivel 1)', 'Completa 1 juego de Devil May Cry.', 'colorize', 'common', 10,  'franchises'),
  ('devil_may_cry_3', 'Estiloso S+ (Nivel 2)',  'Completa 3 juegos de Devil May Cry.', 'colorize', 'rare',   50,  'franchises'),
  ('devil_may_cry_5', 'Dante (Maestro)',         'Completa 5 juegos de Devil May Cry.', 'colorize', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Castlevania: hitos 1, 5, 10 (hay 50+ juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('castlevania_1',  'Cazavampiros (Nivel 1)',     'Completa 1 juego de Castlevania.',   'local_fire_department', 'common', 10,  'franchises'),
  ('castlevania_5',  'Belmont (Nivel 2)',           'Completa 5 juegos de Castlevania.',  'local_fire_department', 'rare',   50,  'franchises'),
  ('castlevania_10', 'Señor de las Tinieblas (Maestro)','Completa 10 juegos de Castlevania.','local_fire_department', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Mass Effect: hitos 1, 2, 3 (saga principal son 3 + Andromeda = 4)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('mass_effect_1', 'Espectro N7 (Nivel 1)', 'Completa 1 juego de Mass Effect.',  'rocket_launch', 'common', 10, 'franchises'),
  ('mass_effect_2', 'Comandante (Nivel 2)',   'Completa 2 juegos de Mass Effect.', 'rocket_launch', 'rare',   50, 'franchises'),
  ('mass_effect_3', 'Shepard (Maestro)',      'Completa 3 juegos de Mass Effect.', 'rocket_launch', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Doom: hitos 1, 3, 5 (hay 41 entradas con ports/engines)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('doom_1', 'Marine del Infierno (Nivel 1)', 'Completa 1 juego de Doom.',  'local_fire_department', 'common', 10,  'franchises'),
  ('doom_3', 'Doomguy (Nivel 2)',             'Completa 3 juegos de Doom.', 'local_fire_department', 'rare',   50,  'franchises'),
  ('doom_5', 'Doom Slayer (Maestro)',          'Completa 5 juegos de Doom.', 'local_fire_department', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- BioShock: hitos 1, 3 (trilogía principal = 3 juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('bioshock_1', 'Bienvenido a Rapture (Nivel 1)', 'Completa 1 juego de BioShock.',  'science', 'common', 10, 'franchises'),
  ('bioshock_3', '¿Un hombre elige... (Maestro)',  'Completa la trilogía BioShock.',  'science', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Borderlands: hitos 1, 3 (hay 21 entradas)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('borderlands_1', 'Buscavidas (Nivel 1)', 'Completa 1 juego de Borderlands.',  'explore', 'common', 10, 'franchises'),
  ('borderlands_3', 'Vault Hunter (Maestro)', 'Completa 3 juegos de Borderlands.', 'explore', 'rare',   50, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Metro: hitos 1, 3 (trilogía principal)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('metro_1', 'Superviviente del Metro (Nivel 1)', 'Completa 1 juego de Metro.',  'hourglass_empty', 'common', 10, 'franchises'),
  ('metro_3', 'Artyom (Maestro)',                  'Completa la trilogía Metro.', 'hourglass_empty', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Dead Space: hitos 1, 3 (trilogía principal)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('dead_space_1', 'Ingeniero a bordo (Nivel 1)', 'Completa 1 juego de Dead Space.',  'science', 'common', 10, 'franchises'),
  ('dead_space_3', 'Isaac Clarke (Maestro)',        'Completa la trilogía Dead Space.', 'science', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Yakuza / Like a Dragon: hitos 1, 3, 6 (hay 50+ juegos)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('yakuza_1', 'Yakuza de Barrio (Nivel 1)',   'Completa 1 juego de la saga Yakuza / Like a Dragon.', 'local_police', 'common', 10,  'franchises'),
  ('yakuza_3', 'Dragón de Dojima (Nivel 2)',   'Completa 3 juegos de Yakuza.',                         'local_police', 'rare',   50,  'franchises'),
  ('yakuza_6', 'Kiryu Kazuma (Maestro)',        'Completa 6 juegos de Yakuza.',                         'local_police', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Xenoblade Chronicles: hitos 1, 3 (hay 13 entradas con remasters)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('xenoblade_1', 'Monado (Nivel 1)',   'Completa 1 juego de Xenoblade Chronicles.', 'menu_book', 'common', 10, 'franchises'),
  ('xenoblade_3', 'Ponspect (Maestro)', 'Completa 3 juegos de Xenoblade Chronicles.','menu_book', 'rare',   50, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Persona / Shin Megami Tensei: hitos 1, 3, 5
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('persona_1', 'Explorador de Sombras (Nivel 1)', 'Completa 1 juego de Persona o SMT.',  'psychology', 'common', 10,  'franchises'),
  ('persona_3', 'Wild Card (Nivel 2)',              'Completa 3 juegos de Persona o SMT.', 'psychology', 'rare',   50,  'franchises'),
  ('persona_5', 'Phantom Thief (Maestro)',          'Completa 5 juegos de Persona o SMT.', 'psychology', 'epic',  100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Konami: hitos 1, 5 (company ID 129)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('konami_1', 'Up Up Down Down (Nivel 1)', 'Completa 1 juego de Konami.', 'sports_esports', 'common', 10, 'companies'),
  ('konami_5', 'Konami Code (Maestro)',     'Completa 5 juegos de Konami.', 'sports_esports', 'rare',   50, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Valve: hitos 1, 3 (company ID 56)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('valve_1', 'Apertura de Ciencia (Nivel 1)', 'Completa 1 juego de Valve.', 'science', 'common', 10, 'companies'),
  ('valve_3', 'GabeN (Maestro)',               'Completa 3 juegos de Valve.', 'science', 'rare',   50, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Remedy Entertainment: hitos 1, 3 (company ID 305)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('remedy_1', 'Control Alterado (Nivel 1)', 'Completa 1 juego de Remedy Entertainment.', 'visibility', 'common', 10, 'companies'),
  ('remedy_3', 'Alan Wake (Maestro)',        'Completa 3 juegos de Remedy Entertainment.', 'visibility', 'rare',   50, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- Team Ninja / Koei Tecmo: hitos 1, 5 (company IDs 769 y 18532)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES
  ('team_ninja_1', 'Ninja de Élite (Nivel 1)', 'Completa 1 juego de Team Ninja / Koei Tecmo.', 'colorize', 'common', 10, 'companies'),
  ('team_ninja_5', 'Maestro del Dojo (Maestro)', 'Completa 5 juegos de Team Ninja / Koei Tecmo.', 'colorize', 'rare',   50, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;


-- =========================================================================
-- PARTE 3: ACTUALIZAR EL TRIGGER (función check_user_achievements)
-- =========================================================================
CREATE OR REPLACE FUNCTION check_user_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
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
  
  -- Franquicias / Colecciones
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
  v_tomb_raider_count INT;
  v_monster_hunter_count INT;
  v_kingdom_hearts_count INT;
  v_silent_hill_count INT;
  v_metroid_count INT;
  v_kirby_count INT;
  v_dmc_count INT;
  v_castlevania_count INT;
  v_mass_effect_count INT;
  v_doom_count INT;
  v_bioshock_count INT;
  v_borderlands_count INT;
  v_metro_count INT;
  v_dead_space_count INT;
  v_yakuza_count INT;
  v_xenoblade_count INT;
  v_persona_count INT;
  v_halo_count INT;
BEGIN
  -- =============================================
  -- COMPAÑÍAS
  -- =============================================
  SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Kojima%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%FromSoftware%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Capcom%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Naughty Dog%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Rockstar%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%CD Projekt%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Konami%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Valve%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Remedy%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -- =============================================
  -- COLECCIONES / FRANQUICIAS (buscadas en campo JSON 'collection')
  -- =============================================
  SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR (g.collection->>'name') ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR (g.collection->>'name') ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Game Freak%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR (g.collection->>'name') ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR (g.collection->>'name') ILIKE '%Dark Souls%' OR g.collection::text ILIKE '%Elden Ring%' OR (g.collection->>'name') ILIKE '%Elden Ring%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR (g.collection->>'name') ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR (g.collection->>'name') ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_cod_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Call of Duty%' OR (g.collection->>'name') ILIKE '%Call of Duty%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_tes_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Elder Scrolls%' OR (g.collection->>'name') ILIKE '%Elder Scrolls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_gow_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%God of War%' OR (g.collection->>'name') ILIKE '%God of War%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_sonic_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Sonic%' OR (g.collection->>'name') ILIKE '%Sonic%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_tomb_raider_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Tomb Raider%' OR (g.collection->>'name') ILIKE '%Tomb Raider%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_monster_hunter_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Monster Hunter%' OR (g.collection->>'name') ILIKE '%Monster Hunter%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_kingdom_hearts_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kingdom Hearts%' OR (g.collection->>'name') ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_silent_hill_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Silent Hill%' OR (g.collection->>'name') ILIKE '%Silent Hill%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_metroid_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metroid%' OR (g.collection->>'name') ILIKE '%Metroid%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_kirby_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kirby%' OR (g.collection->>'name') ILIKE '%Kirby%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_dmc_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Devil May Cry%' OR (g.collection->>'name') ILIKE '%Devil May Cry%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_castlevania_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Castlevania%' OR (g.collection->>'name') ILIKE '%Castlevania%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_mass_effect_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mass Effect%' OR (g.collection->>'name') ILIKE '%Mass Effect%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_doom_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Doom%' OR (g.collection->>'name') ILIKE '%Doom%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR (g.collection->>'name') ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR (g.collection->>'name') ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR (g.collection->>'name') ILIKE '%Metro%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR (g.collection->>'name') ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_yakuza_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Yakuza%' OR (g.collection->>'name') ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%' OR (g.collection->>'name') ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_xenoblade_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Xenoblade%' OR (g.collection->>'name') ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_persona_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Persona%' OR (g.collection->>'name') ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%' OR (g.collection->>'name') ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_halo_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Halo%' OR (g.collection->>'name') ILIKE '%Halo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -- =============================================
  -- LÓGICA DE HITOS (INSERT ON CONFLICT DO NOTHING)
  -- =============================================
  
  -- Kojima
  IF v_kojima_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_1') ON CONFLICT DO NOTHING; END IF;
  IF v_kojima_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_3') ON CONFLICT DO NOTHING; END IF;
  
  -- FromSoftware
  IF v_fromsoftware_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_1') ON CONFLICT DO NOTHING; END IF;
  IF v_fromsoftware_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_3') ON CONFLICT DO NOTHING; END IF;
  IF v_fromsoftware_count >= 7 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_all') ON CONFLICT DO NOTHING; END IF;

  -- Nintendo
  IF v_nintendo_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_1') ON CONFLICT DO NOTHING; END IF;
  IF v_nintendo_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_5') ON CONFLICT DO NOTHING; END IF;
  IF v_nintendo_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_10') ON CONFLICT DO NOTHING; END IF;

  -- Capcom
  IF v_capcom_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_1') ON CONFLICT DO NOTHING; END IF;
  IF v_capcom_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_5') ON CONFLICT DO NOTHING; END IF;
  IF v_capcom_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_10') ON CONFLICT DO NOTHING; END IF;
  IF v_capcom_count >= 20 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_20') ON CONFLICT DO NOTHING; END IF;

  -- Naughty Dog
  IF v_naughty_dog_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_1') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 2 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_2') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_4') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_6') ON CONFLICT DO NOTHING; END IF;

  -- Rockstar
  IF v_rockstar_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_1') ON CONFLICT DO NOTHING; END IF;
  IF v_rockstar_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_3') ON CONFLICT DO NOTHING; END IF;

  -- CD Projekt
  IF v_cd_projekt_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_1') ON CONFLICT DO NOTHING; END IF;
  IF v_cd_projekt_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_3') ON CONFLICT DO NOTHING; END IF;

  -- Konami
  IF v_konami_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'konami_1') ON CONFLICT DO NOTHING; END IF;
  IF v_konami_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'konami_5') ON CONFLICT DO NOTHING; END IF;

  -- Valve
  IF v_valve_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'valve_1') ON CONFLICT DO NOTHING; END IF;
  IF v_valve_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'valve_3') ON CONFLICT DO NOTHING; END IF;

  -- Remedy
  IF v_remedy_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'remedy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_remedy_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'remedy_3') ON CONFLICT DO NOTHING; END IF;

  -- Team Ninja / Koei Tecmo
  IF v_team_ninja_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'team_ninja_1') ON CONFLICT DO NOTHING; END IF;
  IF v_team_ninja_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'team_ninja_5') ON CONFLICT DO NOTHING; END IF;

  -- Zelda
  IF v_zelda_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_1') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_3') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 7 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_all') ON CONFLICT DO NOTHING; END IF;

  -- Mario
  IF v_mario_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_1') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_5') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_10') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 15 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_all') ON CONFLICT DO NOTHING; END IF;

  -- Pokemon
  IF v_pokemon_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_1') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 2 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_2') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_4') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_6') ON CONFLICT DO NOTHING; END IF;

  -- Resident Evil
  IF v_re_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_1') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 2 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_2') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_4') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_6') ON CONFLICT DO NOTHING; END IF;

  -- Dark Souls (fusionado)
  IF v_ds_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ds_count >= 2 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_2') ON CONFLICT DO NOTHING; END IF;
  IF v_ds_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_all') ON CONFLICT DO NOTHING; END IF;

  -- Assassin's Creed
  IF v_ac_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_5') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_10') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 15 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_15') ON CONFLICT DO NOTHING; END IF;

  -- Final Fantasy
  IF v_ff_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_3') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_6') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_10') ON CONFLICT DO NOTHING; END IF;

  -- Call of Duty
  IF v_cod_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'call_of_duty_1') ON CONFLICT DO NOTHING; END IF;
  IF v_cod_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'call_of_duty_5') ON CONFLICT DO NOTHING; END IF;
  IF v_cod_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'call_of_duty_10') ON CONFLICT DO NOTHING; END IF;

  -- Elder Scrolls
  IF v_tes_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'elder_scrolls_1') ON CONFLICT DO NOTHING; END IF;
  IF v_tes_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'elder_scrolls_3') ON CONFLICT DO NOTHING; END IF;
  IF v_tes_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'elder_scrolls_5') ON CONFLICT DO NOTHING; END IF;

  -- God of War
  IF v_gow_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'god_of_war_1') ON CONFLICT DO NOTHING; END IF;
  IF v_gow_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'god_of_war_3') ON CONFLICT DO NOTHING; END IF;
  IF v_gow_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'god_of_war_6') ON CONFLICT DO NOTHING; END IF;

  -- Sonic
  IF v_sonic_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'sonic_1') ON CONFLICT DO NOTHING; END IF;
  IF v_sonic_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'sonic_5') ON CONFLICT DO NOTHING; END IF;
  IF v_sonic_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'sonic_10') ON CONFLICT DO NOTHING; END IF;

  -- Tomb Raider
  IF v_tomb_raider_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'tomb_raider_1') ON CONFLICT DO NOTHING; END IF;
  IF v_tomb_raider_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'tomb_raider_3') ON CONFLICT DO NOTHING; END IF;
  IF v_tomb_raider_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'tomb_raider_6') ON CONFLICT DO NOTHING; END IF;

  -- Monster Hunter
  IF v_monster_hunter_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'monster_hunter_1') ON CONFLICT DO NOTHING; END IF;
  IF v_monster_hunter_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'monster_hunter_3') ON CONFLICT DO NOTHING; END IF;
  IF v_monster_hunter_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'monster_hunter_6') ON CONFLICT DO NOTHING; END IF;

  -- Kingdom Hearts
  IF v_kingdom_hearts_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kingdom_hearts_1') ON CONFLICT DO NOTHING; END IF;
  IF v_kingdom_hearts_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kingdom_hearts_3') ON CONFLICT DO NOTHING; END IF;
  IF v_kingdom_hearts_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kingdom_hearts_6') ON CONFLICT DO NOTHING; END IF;

  -- Silent Hill
  IF v_silent_hill_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'silent_hill_1') ON CONFLICT DO NOTHING; END IF;
  IF v_silent_hill_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'silent_hill_3') ON CONFLICT DO NOTHING; END IF;

  -- Metroid
  IF v_metroid_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metroid_1') ON CONFLICT DO NOTHING; END IF;
  IF v_metroid_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metroid_3') ON CONFLICT DO NOTHING; END IF;
  IF v_metroid_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metroid_6') ON CONFLICT DO NOTHING; END IF;

  -- Kirby
  IF v_kirby_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kirby_1') ON CONFLICT DO NOTHING; END IF;
  IF v_kirby_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kirby_5') ON CONFLICT DO NOTHING; END IF;
  IF v_kirby_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kirby_10') ON CONFLICT DO NOTHING; END IF;

  -- Devil May Cry
  IF v_dmc_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'devil_may_cry_1') ON CONFLICT DO NOTHING; END IF;
  IF v_dmc_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'devil_may_cry_3') ON CONFLICT DO NOTHING; END IF;
  IF v_dmc_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'devil_may_cry_5') ON CONFLICT DO NOTHING; END IF;

  -- Castlevania
  IF v_castlevania_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'castlevania_1') ON CONFLICT DO NOTHING; END IF;
  IF v_castlevania_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'castlevania_5') ON CONFLICT DO NOTHING; END IF;
  IF v_castlevania_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'castlevania_10') ON CONFLICT DO NOTHING; END IF;

  -- Mass Effect
  IF v_mass_effect_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mass_effect_1') ON CONFLICT DO NOTHING; END IF;
  IF v_mass_effect_count >= 2 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mass_effect_2') ON CONFLICT DO NOTHING; END IF;
  IF v_mass_effect_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mass_effect_3') ON CONFLICT DO NOTHING; END IF;

  -- Doom
  IF v_doom_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'doom_1') ON CONFLICT DO NOTHING; END IF;
  IF v_doom_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'doom_3') ON CONFLICT DO NOTHING; END IF;
  IF v_doom_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'doom_5') ON CONFLICT DO NOTHING; END IF;

  -- BioShock
  IF v_bioshock_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'bioshock_1') ON CONFLICT DO NOTHING; END IF;
  IF v_bioshock_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'bioshock_3') ON CONFLICT DO NOTHING; END IF;

  -- Borderlands
  IF v_borderlands_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'borderlands_1') ON CONFLICT DO NOTHING; END IF;
  IF v_borderlands_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'borderlands_3') ON CONFLICT DO NOTHING; END IF;

  -- Metro
  IF v_metro_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metro_1') ON CONFLICT DO NOTHING; END IF;
  IF v_metro_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metro_3') ON CONFLICT DO NOTHING; END IF;

  -- Dead Space
  IF v_dead_space_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dead_space_1') ON CONFLICT DO NOTHING; END IF;
  IF v_dead_space_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dead_space_3') ON CONFLICT DO NOTHING; END IF;

  -- Yakuza / Like a Dragon
  IF v_yakuza_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_1') ON CONFLICT DO NOTHING; END IF;
  IF v_yakuza_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_3') ON CONFLICT DO NOTHING; END IF;
  IF v_yakuza_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_6') ON CONFLICT DO NOTHING; END IF;

  -- Xenoblade
  IF v_xenoblade_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'xenoblade_1') ON CONFLICT DO NOTHING; END IF;
  IF v_xenoblade_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'xenoblade_3') ON CONFLICT DO NOTHING; END IF;

  -- Persona / SMT
  IF v_persona_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_1') ON CONFLICT DO NOTHING; END IF;
  IF v_persona_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_3') ON CONFLICT DO NOTHING; END IF;
  IF v_persona_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_5') ON CONFLICT DO NOTHING; END IF;

  -- Halo
  IF v_halo_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'halo_1') ON CONFLICT DO NOTHING; END IF;
  IF v_halo_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'halo_3') ON CONFLICT DO NOTHING; END IF;
  IF v_halo_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'halo_6') ON CONFLICT DO NOTHING; END IF;

  RETURN NEW;
END;
$$;
