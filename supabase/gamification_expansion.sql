-- 1. Insertamos los nuevos logros escalables en la base de datos
-- IMPORTANTE: Asegúrate de borrar logros viejos de prueba si los tienes, o simplemente ignora los duplicados.
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category)
VALUES 
    -- Kojima Productions
    ('kojima_1', 'Devoto de Kojima (Nivel 1)', 'Completa 1 juego desarrollado por Kojima Productions.', 'psychology', 'common', 10, 'companies'),
    ('kojima_3', 'Devoto de Kojima (Nivel 2)', 'Completa 3 juegos desarrollados por Kojima Productions.', 'psychology', 'rare', 50, 'companies'),
    
    -- FromSoftware
    ('fromsoftware_1', 'Abraza el Sufrimiento (Nivel 1)', 'Completa 1 juego desarrollado por FromSoftware.', 'fireplace', 'common', 10, 'companies'),
    ('fromsoftware_3', 'Abraza el Sufrimiento (Nivel 2)', 'Completa 3 juegos desarrollados por FromSoftware.', 'fireplace', 'rare', 50, 'companies'),
    ('fromsoftware_all', 'Alma Oscura (Maestro)', 'Completa 7 juegos desarrollados por FromSoftware.', 'fireplace', 'epic', 200, 'companies'),
    
    -- Nintendo
    ('nintendo_1', 'Sello de Calidad (Nivel 1)', 'Completa 1 juego de Nintendo.', 'sports_esports', 'common', 10, 'companies'),
    ('nintendo_5', 'Sello de Calidad (Nivel 2)', 'Completa 5 juegos de Nintendo.', 'sports_esports', 'rare', 50, 'companies'),
    ('nintendo_10', 'Sello de Calidad (Nivel 3)', 'Completa 10 juegos de Nintendo.', 'sports_esports', 'epic', 100, 'companies'),
    
    -- Capcom
    ('capcom_1', 'Superviviente Nato (Nivel 1)', 'Completa 1 juego de Capcom.', 'pets', 'common', 10, 'companies'),
    ('capcom_5', 'Superviviente Nato (Nivel 2)', 'Completa 5 juegos de Capcom.', 'pets', 'rare', 50, 'companies'),
    
    -- Naughty Dog
    ('naughty_dog_1', 'Cazatesoros (Nivel 1)', 'Completa 1 juego de Naughty Dog.', 'explore', 'common', 10, 'companies'),
    ('naughty_dog_4', 'Cazatesoros (Nivel 2)', 'Completa 4 juegos de Naughty Dog.', 'explore', 'rare', 50, 'companies'),
    
    -- Rockstar Games
    ('rockstar_1', 'Forajido (Nivel 1)', 'Completa 1 juego de Rockstar Games.', 'local_police', 'common', 10, 'companies'),
    ('rockstar_3', 'Forajido de Leyenda (Nivel 2)', 'Completa 3 juegos de Rockstar Games.', 'local_police', 'rare', 50, 'companies'),
    
    -- CD Projekt RED
    ('cd_projekt_1', 'Brujo (Nivel 1)', 'Completa 1 juego de CD Projekt RED.', 'science', 'common', 10, 'companies'),
    ('cd_projekt_3', 'Lobo Blanco (Nivel 2)', 'Completa 3 juegos de CD Projekt RED.', 'science', 'rare', 50, 'companies'),

    -- Sagas: The Legend of Zelda
    ('zelda_1', 'Héroe del Tiempo (Nivel 1)', 'Completa 1 juego de la saga The Legend of Zelda.', 'shield', 'common', 10, 'franchises'),
    ('zelda_3', 'Héroe del Tiempo (Nivel 2)', 'Completa 3 juegos de The Legend of Zelda.', 'shield', 'rare', 50, 'franchises'),
    ('zelda_all', 'Portador de la Trifuerza (Maestro)', 'Completa 7 juegos de The Legend of Zelda.', 'shield', 'epic', 200, 'franchises'),
    
    -- Sagas: Super Mario
    ('mario_1', '¡Mamma Mia! (Nivel 1)', 'Completa 1 juego de Super Mario.', 'plumbing', 'common', 10, 'franchises'),
    ('mario_5', '¡Mamma Mia! (Nivel 2)', 'Completa 5 juegos de Super Mario.', 'plumbing', 'rare', 50, 'franchises'),
    ('mario_10', '¡Mamma Mia! (Nivel 3)', 'Completa 10 juegos de Super Mario.', 'plumbing', 'epic', 100, 'franchises'),
    ('mario_all', 'Estrella Invencible (Maestro)', 'Completa 15 juegos de Super Mario.', 'plumbing', 'legendary', 300, 'franchises'),

    -- Sagas: Pokémon
    ('pokemon_1', 'Entrenador (Nivel 1)', 'Completa 1 juego de Pokémon.', 'catching_pokemon', 'common', 10, 'franchises'),
    ('pokemon_4', 'Maestro de la Liga (Nivel 2)', 'Completa 4 juegos de Pokémon.', 'catching_pokemon', 'rare', 50, 'franchises'),
    
    -- Sagas: Resident Evil
    ('resident_evil_1', 'Agente de S.T.A.R.S. (Nivel 1)', 'Completa 1 juego de Resident Evil.', 'biotech', 'common', 10, 'franchises'),
    ('resident_evil_4', 'Virus Progenitor (Nivel 2)', 'Completa 4 juegos de Resident Evil.', 'biotech', 'rare', 50, 'franchises'),
    
    -- Sagas: Dark Souls
    ('dark_souls_1', 'Hueco (Nivel 1)', 'Completa 1 juego de la saga Dark Souls.', 'local_fire_department', 'common', 10, 'franchises'),
    ('dark_souls_all', 'Señor de la Ceniza (Maestro)', 'Completa la trilogía Dark Souls.', 'local_fire_department', 'epic', 100, 'franchises'),
    
    -- Sagas: Assassin's Creed
    ('assassins_creed_1', 'Asesino (Nivel 1)', 'Completa 1 juego de Assassin''s Creed.', 'visibility_off', 'common', 10, 'franchises'),
    ('assassins_creed_5', 'Maestro Asesino (Nivel 2)', 'Completa 5 juegos de Assassin''s Creed.', 'visibility_off', 'rare', 50, 'franchises'),
    
    -- Sagas: Final Fantasy
    ('final_fantasy_1', 'Cristal (Nivel 1)', 'Completa 1 juego de Final Fantasy.', 'auto_awesome', 'common', 10, 'franchises'),
    ('final_fantasy_3', 'Guerrero de la Luz (Nivel 2)', 'Completa 3 juegos de Final Fantasy.', 'auto_awesome', 'rare', 50, 'franchises')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, xp_reward = EXCLUDED.xp_reward;

-- 2. Actualizamos la función que valida los logros cada vez que insertas o modificas una review.
-- Usamos "Ruta A": Buscando el texto en el desarrollador y colecciones en el JSON guardado de Supabase.
-- Aplicamos la regla "anti-inflación" asegurando que el juego no sea DLC, Mod, o Hardware (Categorías admitidas: 0, 8, 9, 10, 11).
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
  -- Solo validamos juegos que han sido 'beaten' (completados)
  -- NOTA: Asumimos que guardas el category o game_type en tu tabla games. Si no es así, esta query fallaría.
  -- Si tu tabla 'games' NO TIENE el campo category, puedes omitir la parte de "g.category IN (0,8,9,10,11)".
  -- Para máxima compatibilidad con tu esquema actual, asumo que tienes 'category' guardado.
  -- Si no lo tienes, puedes quitar "AND (g.category IN (0,8,9,10,11) OR g.category IS NULL)"
  
  -- Compañías
  SELECT count(*) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Kojima%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%FromSoftware%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Nintendo%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Capcom%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Naughty Dog%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%Rockstar%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND g.developer ILIKE '%CD Projekt%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -- Colecciones (Sagas)
  -- Buscamos tanto si es un string directo en collection como si es un JSON (->>'name')
  SELECT count(*) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR (g.collection->>'name') ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR (g.collection->>'name') ILIKE '%Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR (g.collection->>'name') ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR (g.collection->>'name') ILIKE '%Dark Souls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR (g.collection->>'name') ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
  SELECT count(*) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.id WHERE r.user_id = NEW.user_id AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR (g.collection->>'name') ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

  -------------------------------------------------------------
  -- LÓGICA DE HITOS ESCALABLES (INSERT IGNORE)
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
  IF v_naughty_dog_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'naughty_dog_4') ON CONFLICT DO NOTHING; END IF;

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
  IF v_pokemon_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'pokemon_4') ON CONFLICT DO NOTHING; END IF;

  -- Resident Evil
  IF v_re_count >= 1 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_1') ON CONFLICT DO NOTHING; END IF;
  IF v_re_count >= 4 THEN INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, 'resident_evil_4') ON CONFLICT DO NOTHING; END IF;

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
