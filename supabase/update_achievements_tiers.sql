-- 1. Estandarizar nombres para que la agrupación en Flutter (por nombre base) funcione perfectamente
UPDATE achievements SET name = 'Abraza el Sufrimiento (Maestro)' WHERE id = 'fromsoftware_all';
UPDATE achievements SET name = 'Forajido (Nivel 2)' WHERE id = 'rockstar_3';
UPDATE achievements SET name = 'Brujo (Nivel 2)' WHERE id = 'cd_projekt_3';
UPDATE achievements SET name = 'Héroe del Tiempo (Maestro)' WHERE id = 'zelda_all';
UPDATE achievements SET name = '¡Mamma Mia! (Maestro)' WHERE id = 'mario_all';

-- 2. Renombrar y estandarizar Pokémon y añadir nuevos hitos (1, 2, 4, 6)
UPDATE achievements SET name = 'Entrenador Pokémon (Nivel 1)' WHERE id = 'pokemon_1';
UPDATE achievements SET name = 'Entrenador Pokémon (Nivel 3)' WHERE id = 'pokemon_4';
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
('pokemon_2', 'Entrenador Pokémon (Nivel 2)', 'Completa 2 juegos de Pokémon.', 'catching_pokemon', 'common', 25, 'franchises'),
('pokemon_6', 'Entrenador Pokémon (Maestro)', 'Completa 6 juegos de Pokémon.', 'catching_pokemon', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- 3. Renombrar y estandarizar Resident Evil y añadir nuevos hitos (1, 2, 4, 6)
UPDATE achievements SET name = 'Agente de S.T.A.R.S. (Nivel 1)' WHERE id = 'resident_evil_1';
UPDATE achievements SET name = 'Agente de S.T.A.R.S. (Nivel 3)' WHERE id = 'resident_evil_4';
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
('resident_evil_2', 'Agente de S.T.A.R.S. (Nivel 2)', 'Completa 2 juegos de Resident Evil.', 'biotech', 'common', 25, 'franchises'),
('resident_evil_6', 'Agente de S.T.A.R.S. (Maestro)', 'Completa 6 juegos de Resident Evil.', 'biotech', 'epic', 100, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- 4. Renombrar y estandarizar Naughty Dog y añadir nuevos hitos (1, 2, 4, 6)
UPDATE achievements SET name = 'Cazatesoros (Nivel 1)' WHERE id = 'naughty_dog_1';
UPDATE achievements SET name = 'Cazatesoros (Nivel 3)' WHERE id = 'naughty_dog_4';
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
('naughty_dog_2', 'Cazatesoros (Nivel 2)', 'Completa 2 juegos de Naughty Dog.', 'explore', 'common', 25, 'companies'),
('naughty_dog_6', 'Cazatesoros (Maestro)', 'Completa 6 juegos de Naughty Dog.', 'explore', 'epic', 100, 'companies')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- 5. Actualizar la función del Trigger para que otorgue los nuevos hitos 2 y 6
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

  -- Dark Souls
  IF v_ds_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ds_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'dark_souls_all') ON CONFLICT DO NOTHING; END IF;

  -- Assassin's Creed
  IF v_ac_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ac_count >= 5 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'assassins_creed_5') ON CONFLICT DO NOTHING; END IF;

  -- Final Fantasy
  IF v_ff_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_1') ON CONFLICT DO NOTHING; END IF;
  IF v_ff_count >= 3 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'final_fantasy_3') ON CONFLICT DO NOTHING; END IF;

  RETURN NEW;
END;
$$;
