-- =====================================================================
-- CORPUS: MIGRACIÓN DE LOGROS DEFINITIVA (v5)
-- Fusiona todos los hitos (v3 y v4), limpia los obsoletos, inserta
-- todos los logros necesarios y actualiza el Trigger de forma completa.
-- =====================================================================

-- 1. Eliminar los hitos antiguos que ya no se usarán
DELETE FROM achievements WHERE id IN (
  'mario_all',
  'pokemon_2', 'pokemon_4', 'pokemon_6',
  'resident_evil_2', 'resident_evil_4', 'resident_evil_6',
  'naughty_dog_2', 'naughty_dog_4', 'naughty_dog_6',
  'assassins_creed_5',
  'kojima'
);

-- 2. Insertar todos los hitos (Combinación completa de compañías y sagas)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
-- Kojima Productions (1, 3, 5)
('kojima_1', 'Devoto de Kojima (Nivel 1)', 'Completa 1 juego de Kojima Productions.', 'psychology', 'common', 10, 'companies'),
('kojima_3', 'Devoto de Kojima (Nivel 2)', 'Completa 3 juegos de Kojima Productions.', 'psychology', 'rare', 50, 'companies'),
('kojima_5', 'Devoto de Kojima (Maestro)', 'Completa 5 juegos de Kojima Productions.', 'psychology', 'epic', 100, 'companies'),

-- FromSoftware (1, 3, 7)
('fromsoftware_1', 'Abraza el Sufrimiento (Nivel 1)', 'Completa 1 juego de FromSoftware.', 'fireplace', 'common', 10, 'companies'),
('fromsoftware_3', 'Abraza el Sufrimiento (Nivel 2)', 'Completa 3 juegos de FromSoftware.', 'fireplace', 'rare', 50, 'companies'),
('fromsoftware_all', 'Alma Oscura (Maestro)', 'Completa 7 juegos de FromSoftware.', 'fireplace', 'epic', 200, 'companies'),

-- Nintendo (1, 5, 10)
('nintendo_1', 'Sello de Calidad (Nivel 1)', 'Completa 1 juego de Nintendo.', 'sports_esports', 'common', 10, 'companies'),
('nintendo_5', 'Sello de Calidad (Nivel 2)', 'Completa 5 juegos de Nintendo.', 'sports_esports', 'rare', 50, 'companies'),
('nintendo_10', 'Sello de Calidad (Maestro)', 'Completa 10 juegos de Nintendo.', 'sports_esports', 'epic', 100, 'companies'),

-- Capcom (1, 5, 10)
('capcom_1', 'Superviviente Nato (Nivel 1)', 'Completa 1 juego de Capcom.', 'pets', 'common', 10, 'companies'),
('capcom_5', 'Superviviente Nato (Nivel 2)', 'Completa 5 juegos de Capcom.', 'pets', 'rare', 50, 'companies'),
('capcom_10', 'Superviviente Nato (Maestro)', 'Completa 10 juegos de Capcom.', 'pets', 'epic', 100, 'companies'),

-- Naughty Dog (1, 3, 5)
('naughty_dog_1', 'Cazatesoros (Nivel 1)', 'Completa 1 juego de Naughty Dog.', 'explore', 'common', 10, 'companies'),
('naughty_dog_3', 'Cazatesoros (Nivel 2)', 'Completa 3 juegos de Naughty Dog.', 'explore', 'rare', 50, 'companies'),
('naughty_dog_5', 'Cazatesoros (Maestro)', 'Completa 5 juegos de Naughty Dog.', 'explore', 'epic', 100, 'companies'),

-- Rockstar (1, 3)
('rockstar_1', 'Forajido (Nivel 1)', 'Completa 1 juego de Rockstar Games.', 'local_police', 'common', 10, 'companies'),
('rockstar_3', 'Forajido de Leyenda (Maestro)', 'Completa 3 juegos de Rockstar Games.', 'local_police', 'rare', 50, 'companies'),

-- CD Projekt RED (1, 3)
('cd_projekt_1', 'Brujo (Nivel 1)', 'Completa 1 juego de CD Projekt RED.', 'science', 'common', 10, 'companies'),
('cd_projekt_3', 'Lobo Blanco (Maestro)', 'Completa 3 juegos de CD Projekt RED.', 'science', 'rare', 50, 'companies'),

-- Konami (1, 5)
('konami_1', 'Up Up Down Down (Nivel 1)', 'Completa 1 juego de Konami.', 'sports_esports', 'common', 10, 'companies'),
('konami_5', 'Konami Code (Maestro)', 'Completa 5 juegos de Konami.', 'sports_esports', 'rare', 50, 'companies'),

-- Valve (1, 3)
('valve_1', 'Apertura de Ciencia (Nivel 1)', 'Completa 1 juego de Valve.', 'science', 'common', 10, 'companies'),
('valve_3', 'GabeN (Maestro)', 'Completa 3 juegos de Valve.', 'science', 'rare', 50, 'companies'),

-- Remedy Entertainment (1, 3)
('remedy_1', 'Control Alterado (Nivel 1)', 'Completa 1 juego de Remedy Entertainment.', 'visibility', 'common', 10, 'companies'),
('remedy_3', 'Alan Wake (Maestro)', 'Completa 3 juegos de Remedy Entertainment.', 'visibility', 'rare', 50, 'companies'),

-- Team Ninja (1, 5)
('team_ninja_1', 'Ninja de Élite (Nivel 1)', 'Completa 1 juego de Team Ninja.', 'colorize', 'common', 10, 'companies'),
('team_ninja_5', 'Maestro del Dojo (Maestro)', 'Completa 5 juegos de Team Ninja.', 'colorize', 'rare', 50, 'companies'),

-- Zelda (1, 3, 7)
('zelda_1', 'Héroe del Tiempo (Nivel 1)', 'Completa 1 juego de Zelda.', 'shield', 'common', 10, 'franchises'),
('zelda_3', 'Héroe del Tiempo (Nivel 2)', 'Completa 3 juegos de Zelda.', 'shield', 'rare', 50, 'franchises'),
('zelda_all', 'Portador de la Trifuerza (Maestro)', 'Completa 7 juegos de Zelda.', 'shield', 'epic', 200, 'franchises'),

-- Mario (1, 5, 10)
('mario_1', '¡Mamma Mia! (Nivel 1)', 'Completa 1 juego de Super Mario.', 'plumbing', 'common', 10, 'franchises'),
('mario_5', '¡Mamma Mia! (Nivel 2)', 'Completa 5 juegos de Super Mario.', 'plumbing', 'rare', 50, 'franchises'),
('mario_10', '¡Mamma Mia! (Maestro)', 'Completa 10 juegos de Super Mario.', 'plumbing', 'epic', 100, 'franchises'),

-- Pokemon (1, 3, 5)
('pokemon_1', 'Entrenador (Nivel 1)', 'Completa 1 juego de Pokémon.', 'catching_pokemon', 'common', 10, 'franchises'),
('pokemon_3', 'Entrenador Pokémon (Nivel 2)', 'Completa 3 juegos de Pokémon.', 'catching_pokemon', 'rare', 50, 'franchises'),
('pokemon_5', 'Entrenador Pokémon (Maestro)', 'Completa 5 juegos de Pokémon.', 'catching_pokemon', 'epic', 100, 'franchises'),

-- Resident Evil (1, 3, 5)
('resident_evil_1', 'Agente de S.T.A.R.S. (Nivel 1)', 'Completa 1 juego de Resident Evil.', 'biotech', 'common', 10, 'franchises'),
('resident_evil_3', 'Agente de S.T.A.R.S. (Nivel 2)', 'Completa 3 juegos de Resident Evil.', 'biotech', 'rare', 50, 'franchises'),
('resident_evil_5', 'Agente de S.T.A.R.S. (Maestro)', 'Completa 5 juegos de Resident Evil.', 'biotech', 'epic', 100, 'franchises'),

-- Dark Souls (1, 3)
('dark_souls_1', 'Hueco (Nivel 1)', 'Completa 1 juego de Dark Souls / Elden Ring.', 'local_fire_department', 'common', 10, 'franchises'),
('dark_souls_all', 'Señor de la Ceniza (Maestro)', 'Completa la trilogía Dark Souls.', 'local_fire_department', 'epic', 100, 'franchises'),

-- Assassin's Creed (1, 3, 6)
('assassins_creed_1', 'Asesino (Nivel 1)', 'Completa 1 juego de Assassin''s Creed.', 'visibility_off', 'common', 10, 'franchises'),
('assassins_creed_3', 'Maestro Asesino (Nivel 2)', 'Completa 3 juegos de Assassin''s Creed.', 'visibility_off', 'rare', 50, 'franchises'),
('assassins_creed_6', 'Maestro Asesino (Maestro)', 'Completa 6 juegos de Assassin''s Creed.', 'visibility_off', 'epic', 100, 'franchises'),

-- Final Fantasy (1, 3, 5)
('final_fantasy_1', 'Cristal (Nivel 1)', 'Completa 1 juego de Final Fantasy.', 'auto_awesome', 'common', 10, 'franchises'),
('final_fantasy_3', 'Guerrero de la Luz (Nivel 2)', 'Completa 3 juegos de Final Fantasy.', 'auto_awesome', 'rare', 50, 'franchises'),
('final_fantasy_5', 'Guerrero de la Luz (Maestro)', 'Completa 5 juegos de Final Fantasy.', 'auto_awesome', 'epic', 100, 'franchises'),

-- BioShock (1, 3)
('bioshock_1', 'Bienvenido a Rapture (Nivel 1)', 'Completa 1 juego de BioShock.', 'science', 'common', 10, 'franchises'),
('bioshock_3', '¿Un hombre elige... (Maestro)', 'Completa la trilogía BioShock.', 'science', 'epic', 100, 'franchises'),

-- Borderlands (1, 3)
('borderlands_1', 'Buscavidas (Nivel 1)', 'Completa 1 juego de Borderlands.', 'explore', 'common', 10, 'franchises'),
('borderlands_3', 'Vault Hunter (Maestro)', 'Completa 3 juegos de Borderlands.', 'explore', 'rare', 50, 'franchises'),

-- Metro (1, 3)
('metro_1', 'Superviviente del Metro (Nivel 1)', 'Completa 1 juego de Metro.', 'hourglass_empty', 'common', 10, 'franchises'),
('metro_3', 'Artyom (Maestro)', 'Completa la trilogía Metro.', 'hourglass_empty', 'epic', 100, 'franchises'),

-- Dead Space (1, 3)
('dead_space_1', 'Ingeniero a bordo (Nivel 1)', 'Completa 1 juego de Dead Space.', 'science', 'common', 10, 'franchises'),
('dead_space_3', 'Isaac Clarke (Maestro)', 'Completa la trilogía Dead Space.', 'science', 'epic', 100, 'franchises'),

-- Yakuza / Like a Dragon (1, 3, 6)
('yakuza_1', 'Yakuza de Barrio (Nivel 1)', 'Completa 1 juego de Yakuza.', 'local_police', 'common', 10, 'franchises'),
('yakuza_3', 'Dragón de Dojima (Nivel 2)', 'Completa 3 juegos de Yakuza.', 'local_police', 'rare', 50, 'franchises'),
('yakuza_6', 'Kiryu Kazuma (Maestro)', 'Completa 6 juegos de Yakuza.', 'local_police', 'epic', 100, 'franchises'),

-- Xenoblade (1, 3)
('xenoblade_1', 'Monado (Nivel 1)', 'Completa 1 juego de Xenoblade Chronicles.', 'menu_book', 'common', 10, 'franchises'),
('xenoblade_3', 'Ponspect (Maestro)', 'Completa 3 juegos de Xenoblade Chronicles.', 'menu_book', 'rare', 50, 'franchises'),

-- Persona / Shin Megami Tensei (1, 3, 5)
('persona_1', 'Explorador de Sombras (Nivel 1)', 'Completa 1 juego de Persona o SMT.', 'psychology', 'common', 10, 'franchises'),
('persona_3', 'Wild Card (Nivel 2)', 'Completa 3 juegos de Persona o SMT.', 'psychology', 'rare', 50, 'franchises'),
('persona_5', 'Phantom Thief (Maestro)', 'Completa 5 juegos de Persona o SMT.', 'psychology', 'epic', 100, 'franchises')

ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name, 
  description = EXCLUDED.description, 
  xp_reward = EXCLUDED.xp_reward,
  rarity = EXCLUDED.rarity;


-- 3. Actualizar la función del Trigger de forma completa (Fusionando lógica v3 y v4)
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
  -- Contadores de Compañías
  SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Kojima%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%FromSoftware%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Capcom%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Naughty Dog%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Rockstar%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%CD Projekt%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Konami%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Valve%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.developer ILIKE '%Remedy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -- Contadores de Franquicias (Sagas)
  SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_yakuza_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_xenoblade_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_persona_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -------------------------------------------------------------
  -- OTORGAR LOGROS
  -------------------------------------------------------------
  
  -- Compañías
  IF v_kojima_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_1') ON CONFLICT DO NOTHING; END IF;
  IF v_kojima_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_3') ON CONFLICT DO NOTHING; END IF;
  IF v_kojima_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_5') ON CONFLICT DO NOTHING; END IF;

  IF v_fromsoftware_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_1') ON CONFLICT DO NOTHING; END IF;
  IF v_fromsoftware_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_3') ON CONFLICT DO NOTHING; END IF;
  IF v_fromsoftware_count >= 7 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'fromsoftware_all') ON CONFLICT DO NOTHING; END IF;

  IF v_nintendo_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_1') ON CONFLICT DO NOTHING; END IF;
  IF v_nintendo_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_5') ON CONFLICT DO NOTHING; END IF;
  IF v_nintendo_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'nintendo_10') ON CONFLICT DO NOTHING; END IF;

  IF v_capcom_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_1') ON CONFLICT DO NOTHING; END IF;
  IF v_capcom_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_5') ON CONFLICT DO NOTHING; END IF;
  IF v_capcom_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'capcom_10') ON CONFLICT DO NOTHING; END IF;

  IF v_naughty_dog_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_1') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_3') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_5') ON CONFLICT DO NOTHING; END IF;

  IF v_rockstar_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_1') ON CONFLICT DO NOTHING; END IF;
  IF v_rockstar_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_3') ON CONFLICT DO NOTHING; END IF;

  IF v_cd_projekt_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_1') ON CONFLICT DO NOTHING; END IF;
  IF v_cd_projekt_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_3') ON CONFLICT DO NOTHING; END IF;

  IF v_konami_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'konami_1') ON CONFLICT DO NOTHING; END IF;
  IF v_konami_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'konami_5') ON CONFLICT DO NOTHING; END IF;

  IF v_valve_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'valve_1') ON CONFLICT DO NOTHING; END IF;
  IF v_valve_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'valve_3') ON CONFLICT DO NOTHING; END IF;

  IF v_remedy_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'remedy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_remedy_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'remedy_3') ON CONFLICT DO NOTHING; END IF;

  IF v_team_ninja_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'team_ninja_1') ON CONFLICT DO NOTHING; END IF;
  IF v_team_ninja_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'team_ninja_5') ON CONFLICT DO NOTHING; END IF;

  -- Franquicias
  IF v_zelda_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_1') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_3') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 7 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_all') ON CONFLICT DO NOTHING; END IF;

  IF v_mario_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_1') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_5') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_10') ON CONFLICT DO NOTHING; END IF;

  IF v_pokemon_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_1') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_3') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_5') ON CONFLICT DO NOTHING; END IF;

  IF v_re_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_1') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_3') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_5') ON CONFLICT DO NOTHING; END IF;

  IF v_ds_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ds_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_all') ON CONFLICT DO NOTHING; END IF;

  IF v_ac_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_3') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_6') ON CONFLICT DO NOTHING; END IF;

  IF v_ff_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_3') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_5') ON CONFLICT DO NOTHING; END IF;

  IF v_bioshock_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'bioshock_1') ON CONFLICT DO NOTHING; END IF;
  IF v_bioshock_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'bioshock_3') ON CONFLICT DO NOTHING; END IF;

  IF v_borderlands_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'borderlands_1') ON CONFLICT DO NOTHING; END IF;
  IF v_borderlands_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'borderlands_3') ON CONFLICT DO NOTHING; END IF;

  IF v_metro_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metro_1') ON CONFLICT DO NOTHING; END IF;
  IF v_metro_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'metro_3') ON CONFLICT DO NOTHING; END IF;

  IF v_dead_space_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dead_space_1') ON CONFLICT DO NOTHING; END IF;
  IF v_dead_space_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dead_space_3') ON CONFLICT DO NOTHING; END IF;

  IF v_yakuza_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_1') ON CONFLICT DO NOTHING; END IF;
  IF v_yakuza_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_3') ON CONFLICT DO NOTHING; END IF;
  IF v_yakuza_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'yakuza_6') ON CONFLICT DO NOTHING; END IF;

  IF v_xenoblade_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'xenoblade_1') ON CONFLICT DO NOTHING; END IF;
  IF v_xenoblade_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'xenoblade_3') ON CONFLICT DO NOTHING; END IF;

  IF v_persona_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_1') ON CONFLICT DO NOTHING; END IF;
  IF v_persona_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_3') ON CONFLICT DO NOTHING; END IF;
  IF v_persona_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'persona_5') ON CONFLICT DO NOTHING; END IF;

  RETURN NEW;
END;
$$;
