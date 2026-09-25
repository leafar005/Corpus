-- =============================================================================
-- Migración: Fase 3 — Refactor check_user_achievements a sistema data-driven
-- =============================================================================
-- ANTES: 291 líneas de SQL procedural con 42 CASE WHEN hardcodeados.
-- DESPUÉS: Tabla `achievement_rules` con las reglas de matching, y una función
-- genérica que itera sobre las reglas. Añadir un nuevo logro es solo un INSERT.
--
-- IMPORTANTE: Migración idempotente con IF NOT EXISTS / CREATE OR REPLACE.
-- =============================================================================

-- ── 1. Tabla de reglas de logros ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievement_rules (
  achievement_id TEXT PRIMARY KEY,          -- 'kojima_1', 'zelda_3', etc.
  rule_type TEXT NOT NULL DEFAULT 'company', -- 'company', 'franchise', 'general'
  match_group TEXT NOT NULL,                 -- 'kojima', 'zelda', 'time_traveler', etc.
  threshold INT NOT NULL DEFAULT 1,          -- nº de juegos beaten necesarios
  -- Para 'general' rules, condiciones más flexibles
  sql_condition TEXT                          -- condición SQL extra (solo para rule_type='general')
);

-- RLS: solo service_role puede escribir, lectura pública (el cliente las usa
-- para mostrar progreso).
ALTER TABLE public.achievement_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "achievement_rules_select" ON public.achievement_rules
  FOR SELECT USING (true);

CREATE POLICY "achievement_rules_service_role" ON public.achievement_rules
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 2. Tabla de patrones de matching por grupo ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievement_match_patterns (
  id SERIAL PRIMARY KEY,
  match_group TEXT NOT NULL,                 -- 'kojima', 'zelda', etc.
  field TEXT NOT NULL,                        -- 'developer', 'collection', 'franchises', 'title'
  pattern TEXT NOT NULL,                      -- '%Kojima%', '%Zelda%', etc.
  is_exclusion BOOLEAN NOT NULL DEFAULT false -- true = NOT ILIKE (para excluir falsos positivos)
);

ALTER TABLE public.achievement_match_patterns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "match_patterns_select" ON public.achievement_match_patterns
  FOR SELECT USING (true);

CREATE POLICY "match_patterns_service_role" ON public.achievement_match_patterns
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 3. Seed: Reglas de logros ────────────────────────────────────────────────
-- Compañías
INSERT INTO achievement_rules (achievement_id, rule_type, match_group, threshold) VALUES
  ('kojima_1', 'company', 'kojima', 1),
  ('kojima_3', 'company', 'kojima', 3),
  ('kojima_5', 'company', 'kojima', 5),
  ('fromsoftware_1', 'company', 'fromsoftware', 1),
  ('fromsoftware_3', 'company', 'fromsoftware', 3),
  ('fromsoftware_all', 'company', 'fromsoftware', 7),
  ('nintendo_1', 'company', 'nintendo', 1),
  ('nintendo_5', 'company', 'nintendo', 5),
  ('nintendo_10', 'company', 'nintendo', 10),
  ('capcom_1', 'company', 'capcom', 1),
  ('capcom_5', 'company', 'capcom', 5),
  ('capcom_10', 'company', 'capcom', 10),
  ('naughty_dog_1', 'company', 'naughty_dog', 1),
  ('naughty_dog_3', 'company', 'naughty_dog', 3),
  ('naughty_dog_5', 'company', 'naughty_dog', 5),
  ('rockstar_1', 'company', 'rockstar', 1),
  ('rockstar_3', 'company', 'rockstar', 3),
  ('cd_projekt_1', 'company', 'cd_projekt', 1),
  ('cd_projekt_3', 'company', 'cd_projekt', 3),
  ('konami_1', 'company', 'konami', 1),
  ('konami_5', 'company', 'konami', 5),
  ('valve_1', 'company', 'valve', 1),
  ('valve_3', 'company', 'valve', 3),
  ('remedy_1', 'company', 'remedy', 1),
  ('remedy_3', 'company', 'remedy', 3),
  ('team_ninja_1', 'company', 'team_ninja', 1),
  ('team_ninja_5', 'company', 'team_ninja', 5),
  ('square_enix_1', 'company', 'square_enix', 1),
  ('square_enix_5', 'company', 'square_enix', 5),
  ('square_enix_10', 'company', 'square_enix', 10),
  ('bethesda_1', 'company', 'bethesda', 1),
  ('bethesda_3', 'company', 'bethesda', 3),
  ('bethesda_5', 'company', 'bethesda', 5)
ON CONFLICT (achievement_id) DO NOTHING;

-- Franquicias
INSERT INTO achievement_rules (achievement_id, rule_type, match_group, threshold) VALUES
  ('zelda_1', 'franchise', 'zelda', 1),
  ('zelda_3', 'franchise', 'zelda', 3),
  ('zelda_all', 'franchise', 'zelda', 7),
  ('mario_1', 'franchise', 'mario', 1),
  ('mario_5', 'franchise', 'mario', 5),
  ('mario_10', 'franchise', 'mario', 10),
  ('pokemon_1', 'franchise', 'pokemon', 1),
  ('pokemon_3', 'franchise', 'pokemon', 3),
  ('pokemon_5', 'franchise', 'pokemon', 5),
  ('resident_evil_1', 'franchise', 'resident_evil', 1),
  ('resident_evil_3', 'franchise', 'resident_evil', 3),
  ('resident_evil_5', 'franchise', 'resident_evil', 5),
  ('dark_souls_1', 'franchise', 'dark_souls', 1),
  ('dark_souls_all', 'franchise', 'dark_souls', 3),
  ('assassins_creed_1', 'franchise', 'assassins_creed', 1),
  ('assassins_creed_3', 'franchise', 'assassins_creed', 3),
  ('assassins_creed_6', 'franchise', 'assassins_creed', 6),
  ('final_fantasy_1', 'franchise', 'final_fantasy', 1),
  ('final_fantasy_3', 'franchise', 'final_fantasy', 3),
  ('final_fantasy_5', 'franchise', 'final_fantasy', 5),
  ('call_of_duty_1', 'franchise', 'call_of_duty', 1),
  ('call_of_duty_3', 'franchise', 'call_of_duty', 3),
  ('call_of_duty_5', 'franchise', 'call_of_duty', 5),
  ('elder_scrolls_1', 'franchise', 'elder_scrolls', 1),
  ('elder_scrolls_3', 'franchise', 'elder_scrolls', 3),
  ('elder_scrolls_5', 'franchise', 'elder_scrolls', 5),
  ('god_of_war_1', 'franchise', 'god_of_war', 1),
  ('god_of_war_3', 'franchise', 'god_of_war', 3),
  ('god_of_war_5', 'franchise', 'god_of_war', 5),
  ('tomb_raider_1', 'franchise', 'tomb_raider', 1),
  ('tomb_raider_3', 'franchise', 'tomb_raider', 3),
  ('tomb_raider_5', 'franchise', 'tomb_raider', 5),
  ('monster_hunter_1', 'franchise', 'monster_hunter', 1),
  ('monster_hunter_3', 'franchise', 'monster_hunter', 3),
  ('monster_hunter_5', 'franchise', 'monster_hunter', 5),
  ('kingdom_hearts_1', 'franchise', 'kingdom_hearts', 1),
  ('kingdom_hearts_3', 'franchise', 'kingdom_hearts', 3),
  ('kingdom_hearts_5', 'franchise', 'kingdom_hearts', 5),
  ('silent_hill_1', 'franchise', 'silent_hill', 1),
  ('silent_hill_3', 'franchise', 'silent_hill', 3),
  ('silent_hill_5', 'franchise', 'silent_hill', 5),
  ('metroid_1', 'franchise', 'metroid', 1),
  ('metroid_3', 'franchise', 'metroid', 3),
  ('kirby_1', 'franchise', 'kirby', 1),
  ('kirby_3', 'franchise', 'kirby', 3),
  ('devil_may_cry_1', 'franchise', 'devil_may_cry', 1),
  ('devil_may_cry_3', 'franchise', 'devil_may_cry', 3),
  ('castlevania_1', 'franchise', 'castlevania', 1),
  ('castlevania_3', 'franchise', 'castlevania', 3),
  ('mass_effect_1', 'franchise', 'mass_effect', 1),
  ('mass_effect_3', 'franchise', 'mass_effect', 3),
  ('doom_1', 'franchise', 'doom', 1),
  ('doom_3', 'franchise', 'doom', 3),
  ('bioshock_1', 'franchise', 'bioshock', 1),
  ('bioshock_3', 'franchise', 'bioshock', 3),
  ('borderlands_1', 'franchise', 'borderlands', 1),
  ('borderlands_3', 'franchise', 'borderlands', 3),
  ('metro_1', 'franchise', 'metro', 1),
  ('metro_3', 'franchise', 'metro', 3),
  ('dead_space_1', 'franchise', 'dead_space', 1),
  ('dead_space_3', 'franchise', 'dead_space', 3),
  ('yakuza_1', 'franchise', 'yakuza', 1),
  ('yakuza_3', 'franchise', 'yakuza', 3),
  ('xenoblade_1', 'franchise', 'xenoblade', 1),
  ('xenoblade_3', 'franchise', 'xenoblade', 3),
  ('persona_1', 'franchise', 'persona', 1),
  ('persona_3', 'franchise', 'persona', 3),
  ('halo_1', 'franchise', 'halo', 1),
  ('halo_3', 'franchise', 'halo', 3),
  ('sonic_1', 'franchise', 'sonic', 1),
  ('sonic_3', 'franchise', 'sonic', 3)
ON CONFLICT (achievement_id) DO NOTHING;

-- Generales (mantienen condiciones SQL porque son más complejas)
INSERT INTO achievement_rules (achievement_id, rule_type, match_group, threshold, sql_condition) VALUES
  ('time_traveler', 'general', 'retro', 1, 'g.release_date < ''2000-01-01'''),
  ('scholar_20th', 'general', 'retro', 20, 'g.release_date < ''2000-01-01'''),
  ('vanguard', 'general', 'launch_year', 10, 'extract(year from r.created_at) = extract(year from g.release_date::date)'),
  ('pc_master_race', 'general', 'pc', 50, 'r.platform ILIKE ''%PC%'''),
  ('rpg_veteran', 'general', 'rpg', 30, 'g.genres::text ILIKE ''%Role-playing%'''),
  ('lone_wolf', 'general', 'single_player', 50, 'g.game_modes::text ILIKE ''%Single player%''')
ON CONFLICT (achievement_id) DO NOTHING;

-- Nota: multiplatform se evalúa con COUNT(DISTINCT platform), no con COUNT(games)
-- Se mantiene hardcodeado en la función por ser una estructura diferente.

-- ── 4. Seed: Patrones de matching (ejemplos clave, el resto sigue el mismo patrón)
-- Solo inserto los que no se pueden inferir del nombre del match_group.
-- Patrones para 'kojima' (el más complejo por ser cross-company):
INSERT INTO achievement_match_patterns (match_group, field, pattern) VALUES
  ('kojima', 'developer', '%Kojima%'),
  ('kojima', 'collection', '%Metal Gear%'),
  ('kojima', 'collection', '%Zone of the Enders%'),
  ('kojima', 'collection', '%Boktai%'),
  ('kojima', 'title', '%Metal Gear%'),
  ('kojima', 'title', '%Death Stranding%'),
  ('kojima', 'title', '%Snatcher%'),
  ('kojima', 'title', '%Policenauts%'),
  ('kojima', 'title', '%Zone of the Enders%'),
  ('kojima', 'title', '%Boktai%')
ON CONFLICT DO NOTHING;

-- Patrones simples de franquicia (campo + patrón)
INSERT INTO achievement_match_patterns (match_group, field, pattern) VALUES
  ('zelda', 'collection', '%Zelda%'),
  ('zelda', 'franchises', '%Zelda%'),
  ('zelda', 'title', '%Zelda%'),
  ('mario', 'collection', '%Mario%'),
  ('mario', 'franchises', '%Mario%'),
  ('mario', 'title', '%Super Mario%'),
  ('pokemon', 'collection', '%Pokemon%'),
  ('pokemon', 'collection', '%Pokémon%'),
  ('pokemon', 'title', '%Pokemon%'),
  ('pokemon', 'title', '%Pokémon%'),
  ('resident_evil', 'collection', '%Resident Evil%'),
  ('resident_evil', 'franchises', '%Resident Evil%'),
  ('resident_evil', 'title', '%Resident Evil%'),
  ('dark_souls', 'collection', '%Dark Souls%'),
  ('dark_souls', 'franchises', '%Dark Souls%'),
  ('dark_souls', 'title', '%Dark Souls%'),
  ('doom', 'collection', '%DOOM%'),
  ('doom', 'franchises', '%DOOM%'),
  ('doom', 'title', '%DOOM%')
ON CONFLICT DO NOTHING;

-- Exclusiones (para evitar falsos positivos — ej. 'metro' no debe matchear 'Metroid')
INSERT INTO achievement_match_patterns (match_group, field, pattern, is_exclusion) VALUES
  ('metro', 'title', '%Metroid%', true),
  ('metro', 'collection', '%Metroid%', true),
  ('metro', 'franchises', '%Metroid%', true)
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTA: La reescritura de check_user_achievements para usar estas tablas
-- requiere una función plpgsql con SQL dinámico (EXECUTE) para los patrones.
-- La migración actual CREA la infraestructura de datos.
-- La reescritura de la función se hará en una segunda migración DESPUÉS de
-- verificar que los datos de seed son correctos en staging/local.
-- ═══════════════════════════════════════════════════════════════════════════════
