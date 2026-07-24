-- =====================================================================
-- ACTUALIZACIÓN DE HITOS (V4): Ajustar hitos para varias sagas y compañías
-- Mario: 1, 5, 10
-- Pokemon, Resident Evil, Naughty Dog, Final Fantasy: 1, 3, 5
-- Assassin's Creed: 1, 3, 6
-- Capcom: 1, 5, 10
-- =====================================================================

-- 1. Eliminar los hitos antiguos que ya no se usarán
DELETE FROM achievements WHERE id IN (
  'mario_all', -- 15
  'pokemon_2', 'pokemon_4', 'pokemon_6',
  'resident_evil_2', 'resident_evil_4', 'resident_evil_6',
  'naughty_dog_2', 'naughty_dog_4', 'naughty_dog_6',
  'assassins_creed_5',
  'kojima'
);

-- 2. Insertar o actualizar los nuevos hitos (niveles 2 y maestros)
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
-- Pokemon (1, 3, 5)
('pokemon_3', 'Entrenador Pokémon (Nivel 2)', 'Completa 3 juegos de Pokémon.', 'catching_pokemon', 'common', 50, 'franchises'),
('pokemon_5', 'Entrenador Pokémon (Maestro)', 'Completa 5 juegos de Pokémon.', 'catching_pokemon', 'epic', 100, 'franchises'),

-- Resident Evil (1, 3, 5)
('resident_evil_3', 'Agente de S.T.A.R.S. (Nivel 2)', 'Completa 3 juegos de Resident Evil.', 'biotech', 'common', 50, 'franchises'),
('resident_evil_5', 'Agente de S.T.A.R.S. (Maestro)', 'Completa 5 juegos de Resident Evil.', 'biotech', 'epic', 100, 'franchises'),

-- Naughty Dog (1, 3, 5)
('naughty_dog_3', 'Cazatesoros (Nivel 2)', 'Completa 3 juegos de Naughty Dog.', 'explore', 'common', 50, 'companies'),
('naughty_dog_5', 'Cazatesoros (Maestro)', 'Completa 5 juegos de Naughty Dog.', 'explore', 'epic', 100, 'companies'),

-- Assassin's Creed (1, 3, 6)
('assassins_creed_3', 'Maestro Asesino (Nivel 2)', 'Completa 3 juegos de Assassin''s Creed.', 'visibility_off', 'common', 50, 'franchises'),
('assassins_creed_6', 'Maestro Asesino (Maestro)', 'Completa 6 juegos de Assassin''s Creed.', 'visibility_off', 'epic', 100, 'franchises'),

-- Capcom (1, 5, 10)
('capcom_5', 'Superviviente Nato (Nivel 2)', 'Completa 5 juegos de Capcom.', 'pets', 'common', 50, 'companies'),
('capcom_10', 'Superviviente Nato (Maestro)', 'Completa 10 juegos de Capcom.', 'pets', 'epic', 100, 'companies'),

-- Kojima (1, 3, 5)
('kojima_3', 'Devoto de Kojima (Nivel 2)', 'Completa 3 juegos de Kojima Productions.', 'psychology', 'common', 50, 'companies'),
('kojima_5', 'Devoto de Kojima (Maestro)', 'Completa 5 juegos de Kojima Productions.', 'psychology', 'epic', 100, 'companies'),

-- Final Fantasy (1, 3, 5)
('final_fantasy_3', 'Guerrero de la Luz (Nivel 2)', 'Completa 3 juegos de Final Fantasy.', 'auto_awesome', 'common', 50, 'franchises'),
('final_fantasy_5', 'Guerrero de la Luz (Maestro)', 'Completa 5 juegos de Final Fantasy.', 'auto_awesome', 'epic', 100, 'franchises')

ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name, 
  description = EXCLUDED.description, 
  xp_reward = EXCLUDED.xp_reward,
  rarity = EXCLUDED.rarity;

-- 3. Actualizar el hito maestro de Mario (ahora el 10 es el máximo)
UPDATE achievements 
SET name = '¡Mamma Mia! (Maestro)', rarity = 'epic', xp_reward = 100 
WHERE id = 'mario_10';

-- 4. Actualizar la función del Trigger para que otorgue los nuevos hitos
CREATE OR REPLACE FUNCTION check_user_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_kojima_count INT;
  v_fromsoftware_count INT;
  v_nintendo_count INT;
  v_capcom_count INT;
  v_naughty_dog_count INT;
  v_rockstar_count INT;
  v_cd_projekt_count INT;
  
  v_zelda_count INT;
  v_mario_count INT;
  v_pokemon_count INT;
  v_re_count INT;
  v_ds_count INT;
  v_ac_count INT;
  v_ff_count INT;
BEGIN
  -- Compañías
  SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Kojima%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%FromSoftware%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Capcom%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Naughty Dog%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Rockstar%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%CD Projekt%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -- Colecciones (Sagas)
  SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR (g.collection->>'name') ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR (g.collection->>'name') ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR (g.collection->>'name') ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR (g.collection->>'name') ILIKE '%Dark Souls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR (g.collection->>'name') ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR (g.collection->>'name') ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -------------------------------------------------------------
  -- LÓGICA DE HITOS ESCALABLES
  -------------------------------------------------------------
  -- Kojima
  IF v_kojima_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_1') ON CONFLICT DO NOTHING; END IF;
  IF v_kojima_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_3') ON CONFLICT DO NOTHING; END IF;
  IF v_kojima_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'kojima_5') ON CONFLICT DO NOTHING; END IF;
  
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

  -- Naughty Dog
  IF v_naughty_dog_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_1') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_3') ON CONFLICT DO NOTHING; END IF;
  IF v_naughty_dog_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_5') ON CONFLICT DO NOTHING; END IF;

  -- Rockstar
  IF v_rockstar_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_1') ON CONFLICT DO NOTHING; END IF;
  IF v_rockstar_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'rockstar_3') ON CONFLICT DO NOTHING; END IF;

  -- CD Projekt
  IF v_cd_projekt_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_1') ON CONFLICT DO NOTHING; END IF;
  IF v_cd_projekt_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'cd_projekt_3') ON CONFLICT DO NOTHING; END IF;

  -- Zelda
  IF v_zelda_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_1') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_3') ON CONFLICT DO NOTHING; END IF;
  IF v_zelda_count >= 7 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'zelda_all') ON CONFLICT DO NOTHING; END IF;

  -- Mario
  IF v_mario_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_1') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_5') ON CONFLICT DO NOTHING; END IF;
  IF v_mario_count >= 10 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'mario_10') ON CONFLICT DO NOTHING; END IF;

  -- Pokemon
  IF v_pokemon_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_1') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_3') ON CONFLICT DO NOTHING; END IF;
  IF v_pokemon_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_5') ON CONFLICT DO NOTHING; END IF;

  -- Resident Evil
  IF v_re_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_1') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_3') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_5') ON CONFLICT DO NOTHING; END IF;

  -- Dark Souls
  IF v_ds_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ds_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_all') ON CONFLICT DO NOTHING; END IF;

  -- Assassin's Creed
  IF v_ac_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_3') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 6 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_6') ON CONFLICT DO NOTHING; END IF;

  -- Final Fantasy
  IF v_ff_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_3') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_5') ON CONFLICT DO NOTHING; END IF;

  RETURN NEW;
END;
$$;
