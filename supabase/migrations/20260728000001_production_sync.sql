-- =====================================================================
-- FASE 2: SINCRONIZACIÓN DE PRODUCCIÓN (Storage, Cron, Funciones V8 y XP)
-- =====================================================================

-- >>> INCLUSIÓN DE: storage_migration.sql <<<
-- ==============================================================================
-- CORPUS: MIGRACIÓN PARA SUPABASE STORAGE (Avatares y Banners)
-- ==============================================================================
-- ¡ATENCIÓN! Ejecuta este script en el SQL Editor de tu Dashboard de Supabase.

-- 1. Insertamos los "buckets" si no existen
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Habilitamos RLS en storage.objects (Supabase ya lo tiene habilitado por defecto, y falla por falta de permisos de owner si intentas alterarlo)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ==========================================================
-- POLÍTICAS PARA AVATARES
-- ==========================================================
-- Permitir que cualquier persona vea las imágenes de avatares
DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Permitir a usuarios logueados subir su propio avatar
DROP POLICY IF EXISTS "Users can upload their own avatars" ON storage.objects;
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados actualizar su propio avatar
DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados borrar su propio avatar
DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
CREATE POLICY "Users can delete their own avatars"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);


-- ==========================================================
-- POLÍTICAS PARA BANNERS
-- ==========================================================
-- Permitir que cualquier persona vea las imágenes de banners
DROP POLICY IF EXISTS "Banner images are publicly accessible" ON storage.objects;
CREATE POLICY "Banner images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'banners');

-- Permitir a usuarios logueados subir su propio banner
DROP POLICY IF EXISTS "Users can upload their own banners" ON storage.objects;
CREATE POLICY "Users can upload their own banners"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados actualizar su propio banner
DROP POLICY IF EXISTS "Users can update their own banners" ON storage.objects;
CREATE POLICY "Users can update their own banners"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados borrar su propio banner
DROP POLICY IF EXISTS "Users can delete their own banners" ON storage.objects;
CREATE POLICY "Users can delete their own banners"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);


-- >>> INCLUSIÓN DE: add_images_to_reviews.sql <<<
-- ==============================================================================
-- CORPUS: MIGRACIÓN PARA SOPORTE DE IMÁGENES EN RESEÑAS Y COMENTARIOS
-- ==============================================================================
-- Ejecuta este script en el SQL Editor de tu Dashboard de Supabase.

-- 1. Añadir columna image_urls (Array de Textos) a reviews
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- 2. Añadir columna image_url (Texto único) a review_comments
ALTER TABLE public.review_comments ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 3. Crear el Bucket de Storage 'user_uploads' si no existe
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user_uploads',
    'user_uploads',
    true, -- ¡Importante para que las imágenes sean visibles!
    10485760, -- Límite de 10 MB (10 * 1024 * 1024)
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 4. Políticas de seguridad (RLS) para el bucket 'user_uploads'

-- Permitir a todo el mundo LEER las imágenes
DROP POLICY IF EXISTS "Public Access to user_uploads" ON storage.objects;
CREATE POLICY "Public Access to user_uploads"
ON storage.objects FOR SELECT
USING (bucket_id = 'user_uploads');

-- Permitir a los usuarios logueados SUBIR imágenes
DROP POLICY IF EXISTS "Authenticated users can upload to user_uploads" ON storage.objects;
CREATE POLICY "Authenticated users can upload to user_uploads"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'user_uploads' AND
    auth.role() = 'authenticated'
);

-- Permitir a los usuarios logueados ELIMINAR sus propias imágenes
DROP POLICY IF EXISTS "Users can delete their own uploads" ON storage.objects;
CREATE POLICY "Users can delete their own uploads"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'user_uploads' AND
    auth.uid() = owner
);


-- >>> INCLUSIÓN DE: fix_storage_policies.sql <<<
-- Arreglar políticas RLS para los buckets avatars y banners

-- Habilitar inserción (uploads) en el bucket 'avatars' para usuarios autenticados
DROP POLICY IF EXISTS "Avatars Upload Policy" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Upload Policy" ON storage.objects;
CREATE POLICY "Avatars Upload Policy" ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Habilitar actualización (updates) en el bucket 'avatars' para usuarios autenticados
DROP POLICY IF EXISTS "Avatars Update Policy" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Update Policy" ON storage.objects;
CREATE POLICY "Avatars Update Policy" ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Habilitar inserción (uploads) en el bucket 'banners' para usuarios autenticados
DROP POLICY IF EXISTS "Banners Upload Policy" ON storage.objects;
DROP POLICY IF EXISTS "Banners Upload Policy" ON storage.objects;
CREATE POLICY "Banners Upload Policy" ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'banners' AND 
    auth.role() = 'authenticated'
);

-- Habilitar actualización (updates) en el bucket 'banners' para usuarios autenticados
DROP POLICY IF EXISTS "Banners Update Policy" ON storage.objects;
DROP POLICY IF EXISTS "Banners Update Policy" ON storage.objects;
CREATE POLICY "Banners Update Policy" ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'banners' AND 
    auth.role() = 'authenticated'
);

-- Opcional: Asegurarnos de que tengan política de Select (lectura pública) por si no la tuvieran
DROP POLICY IF EXISTS "Avatars Select Policy" ON storage.objects;
DROP POLICY IF EXISTS "Avatars Select Policy" ON storage.objects;
CREATE POLICY "Avatars Select Policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Banners Select Policy" ON storage.objects;
DROP POLICY IF EXISTS "Banners Select Policy" ON storage.objects;
CREATE POLICY "Banners Select Policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'banners');


-- >>> INCLUSIÓN DE: setup_cron_feed.sql <<<
-- Instrucciones: Ejecuta esto en el SQL Editor de Supabase.
-- REEMPLAZA [TU_ANON_KEY_AQUI] por tu anon_key de Supabase (Settings -> API)
-- REEMPLAZA [TU_PROJECT_REF] por el ID de tu proyecto (está en la URL, ej: rhcgjiwmlqswlideqzid)

select cron.schedule(
  'fetch-stash-feed-every-4-hours',
  '0 */4 * * *',
  $$
    select net.http_post(
        url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/fetch-stash-feed',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_IaEQtKAtjt7Wqpy7WywRog_a83R4u8m"}'::jsonb,
        body:='{}'::jsonb
    ) as request_id;
  $$
);


-- >>> INCLUSIÓN DE: active_bundles_setup.sql <<<
-- 1. Crear tabla principal para bundles procesados
CREATE TABLE IF NOT EXISTS public.active_bundles (
  id text NOT NULL PRIMARY KEY,
  title text NOT NULL,
  store_name text NOT NULL,
  url text NOT NULL,
  end_date timestamp with time zone,
  tiers jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Habilitar Row Level Security (RLS) con lectura pública
ALTER TABLE public.active_bundles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access on active_bundles" ON public.active_bundles;
CREATE POLICY "Allow public read access on active_bundles" 
ON public.active_bundles 
FOR SELECT 
USING (true);

-- 3. Función y trigger para mantener el campo updated_at al día
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_active_bundles_modtime ON public.active_bundles;
CREATE TRIGGER update_active_bundles_modtime
    BEFORE UPDATE ON public.active_bundles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 4. Programar la ejecución de la Edge Function cada 4 horas
-- (Reemplaza TU_SERVICE_ROLE_KEY con tu clave secreta service_role)
SELECT cron.schedule(
  'sync-bundles-cron',
  '0 */4 * * *', -- Cada 4 horas en punto
  $$
  SELECT net.http_post(
      url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/sync-bundles',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer TU_SERVICE_ROLE_KEY"}'::jsonb,
      body:='{}'::jsonb
  ) as request_id;
  $$
);

-- 5. Programar una tarea de limpieza diaria para purgar bundles caducados
SELECT cron.schedule(
  'purge-expired-bundles',
  '0 3 * * *', -- Todos los días a las 03:00 UTC
  $$
  DELETE FROM public.active_bundles WHERE end_date < now();
  $$
);


-- >>> INCLUSIÓN DE: fix_achievements_and_xp.sql <<<
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
    library_xp integer := 0;
    reviews_xp integer := 0;
    achievements_xp integer := 0;
    total_xp integer := 0;
BEGIN
    -- XP por juegos en biblioteca (tabla user_games donde están todos tus 255 juegos)
    SELECT COALESCE(SUM(
        CASE 
            WHEN status = 'beaten' THEN 20  -- Completar (Terminar) un juego: 20 XP
            ELSE 5                          -- Añadir juego a tu biblioteca (wishlist, playing, dropped, abandoned...): 5 XP
        END
    ), 0) INTO library_xp
    FROM public.user_games
    WHERE user_id = uid;

    -- XP por reseñas escritas y bonus de 100% (tabla reviews donde están tus 65 reseñas)
    SELECT COALESCE(SUM(
        CASE WHEN comment IS NOT NULL AND length(trim(comment)) > 0 THEN 10 ELSE 0 END -- Escribir una reseña: 10 XP
        + CASE WHEN completion_type = '100%' THEN 50 ELSE 0 END                          -- Bonus por 100%: 50 XP
    ), 0) INTO reviews_xp
    FROM public.reviews
    WHERE user_id = uid;

    -- XP por logros desbloqueados (Variable según suma de xp_reward)
    SELECT COALESCE(SUM(a.xp_reward), 0) INTO achievements_xp
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uid;
    
    -- 50 XP base por crear la cuenta (siempre presentes)
    total_xp := library_xp + reviews_xp + achievements_xp + 50;

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


-- >>> INCLUSIÓN DE: achievements_migration_v8_definitive.sql <<<
-- =====================================================================
-- CORPUS: MIGRACIÓN DE LOGROS DEFINITIVA (v8 - COMPLETA Y LIMPIA)
-- 1. Inserta/Actualiza el catálogo completo (42 compañías y sagas).
-- 2. Limpia automáticamente cualquier descripción genérica residual.
-- 3. Reconstruye el motor de cálculo con conteos estrictos (DISTINCT).
-- =====================================================================

-- 1. SOBREESCRIBIR CATÁLOGO COMPLETO CON DESCRIPCIONES EXPLÍCITAS
INSERT INTO achievements (id, name, description, icon_name, rarity, xp_reward, category) VALUES 
-- Compañías
('kojima_1', 'Devoto de Kojima (Nivel 1)', 'Completa 1 juego de Kojima Productions.', 'psychology', 'common', 10, 'companies'),
('kojima_3', 'Devoto de Kojima (Nivel 2)', 'Completa 3 juegos de Kojima Productions.', 'psychology', 'rare', 50, 'companies'),
('kojima_5', 'Devoto de Kojima (Maestro)', 'Completa 5 juegos de Kojima Productions.', 'psychology', 'epic', 100, 'companies'),

('fromsoftware_1', 'Abraza el Sufrimiento (Nivel 1)', 'Completa 1 juego de FromSoftware.', 'fireplace', 'common', 10, 'companies'),
('fromsoftware_3', 'Abraza el Sufrimiento (Nivel 2)', 'Completa 3 juegos de FromSoftware.', 'fireplace', 'rare', 50, 'companies'),
('fromsoftware_all', 'Alma Oscura (Maestro)', 'Completa 7 juegos de FromSoftware.', 'fireplace', 'epic', 200, 'companies'),

('nintendo_1', 'Sello de Calidad (Nivel 1)', 'Completa 1 juego desarrollado por Nintendo.', 'sports_esports', 'common', 10, 'companies'),
('nintendo_5', 'Sello de Calidad (Nivel 2)', 'Completa 5 juegos desarrollados por Nintendo.', 'sports_esports', 'rare', 50, 'companies'),
('nintendo_10', 'Sello de Calidad (Maestro)', 'Completa 10 juegos desarrollados por Nintendo.', 'sports_esports', 'epic', 100, 'companies'),

('capcom_1', 'Superviviente Nato (Nivel 1)', 'Completa 1 juego de Capcom.', 'pets', 'common', 10, 'companies'),
('capcom_5', 'Superviviente Nato (Nivel 2)', 'Completa 5 juegos de Capcom.', 'pets', 'rare', 50, 'companies'),
('capcom_10', 'Superviviente Nato (Maestro)', 'Completa 10 juegos de Capcom.', 'pets', 'epic', 100, 'companies'),

('naughty_dog_1', 'Cazatesoros (Nivel 1)', 'Completa 1 juego de Naughty Dog.', 'explore', 'common', 10, 'companies'),
('naughty_dog_3', 'Cazatesoros (Nivel 2)', 'Completa 3 juegos de Naughty Dog.', 'explore', 'rare', 50, 'companies'),
('naughty_dog_5', 'Cazatesoros (Maestro)', 'Completa 5 juegos de Naughty Dog.', 'explore', 'epic', 100, 'companies'),

('rockstar_1', 'Forajido (Nivel 1)', 'Completa 1 juego de Rockstar Games.', 'local_police', 'common', 10, 'companies'),
('rockstar_3', 'Forajido de Leyenda (Maestro)', 'Completa 3 juegos de Rockstar Games.', 'local_police', 'rare', 50, 'companies'),

('cd_projekt_1', 'Brujo (Nivel 1)', 'Completa 1 juego de CD Projekt RED.', 'science', 'common', 10, 'companies'),
('cd_projekt_3', 'Lobo Blanco (Maestro)', 'Completa 3 juegos de CD Projekt RED.', 'science', 'rare', 50, 'companies'),

('konami_1', 'Up Up Down Down (Nivel 1)', 'Completa 1 juego de Konami.', 'sports_esports', 'common', 10, 'companies'),
('konami_5', 'Konami Code (Maestro)', 'Completa 5 juegos de Konami.', 'sports_esports', 'rare', 50, 'companies'),

('valve_1', 'Apertura de Ciencia (Nivel 1)', 'Completa 1 juego del universo Valve.', 'science', 'common', 10, 'companies'),
('valve_3', 'GabeN (Maestro)', 'Completa 3 juegos del universo Valve.', 'science', 'rare', 50, 'companies'),

('remedy_1', 'Control Alterado (Nivel 1)', 'Completa 1 juego de Remedy Entertainment.', 'visibility', 'common', 10, 'companies'),
('remedy_3', 'Alan Wake (Maestro)', 'Completa 3 juegos de Remedy Entertainment.', 'visibility', 'rare', 50, 'companies'),

('team_ninja_1', 'Ninja de Élite (Nivel 1)', 'Completa 1 juego de Team Ninja / Koei Tecmo.', 'colorize', 'common', 10, 'companies'),
('team_ninja_5', 'Maestro del Dojo (Maestro)', 'Completa 5 juegos de Team Ninja / Koei Tecmo.', 'colorize', 'rare', 50, 'companies'),

('square_enix_1', 'Cristal de Rol (Nivel 1)', 'Completa 1 juego de Square Enix / Squaresoft.', 'auto_awesome', 'common', 10, 'companies'),
('square_enix_5', 'Cristal de Rol (Nivel 2)', 'Completa 5 juegos de Square Enix / Squaresoft.', 'auto_awesome', 'rare', 50, 'companies'),
('square_enix_10', 'Cristal de Rol (Maestro)', 'Completa 10 juegos de Square Enix / Squaresoft.', 'auto_awesome', 'epic', 100, 'companies'),

('bethesda_1', 'Morador del Refugio (Nivel 1)', 'Completa 1 juego de Bethesda / ZeniMax / id Software.', 'shield', 'common', 10, 'companies'),
('bethesda_3', 'Morador del Refugio (Nivel 2)', 'Completa 3 juegos de Bethesda / ZeniMax.', 'shield', 'rare', 50, 'companies'),
('bethesda_5', 'Morador del Refugio (Maestro)', 'Completa 5 juegos de Bethesda / ZeniMax.', 'shield', 'epic', 100, 'companies'),

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

('dark_souls_1', 'Hueco (Nivel 1)', 'Completa 1 juego de la saga Dark Souls.', 'local_fire_department', 'common', 10, 'franchises'),
('dark_souls_all', 'Señor de la Ceniza (Maestro)', 'Completa 3 juegos de la saga Dark Souls.', 'local_fire_department', 'epic', 100, 'franchises'),

('assassins_creed_1', 'Asesino (Nivel 1)', 'Completa 1 juego de Assassin''s Creed.', 'visibility_off', 'common', 10, 'franchises'),
('assassins_creed_3', 'Maestro Asesino (Nivel 2)', 'Completa 3 juegos de Assassin''s Creed.', 'visibility_off', 'rare', 50, 'franchises'),
('assassins_creed_6', 'Maestro Asesino (Maestro)', 'Completa 6 juegos de Assassin''s Creed.', 'visibility_off', 'epic', 100, 'franchises'),

('final_fantasy_1', 'Cristal (Nivel 1)', 'Completa 1 juego de Final Fantasy.', 'auto_awesome', 'common', 10, 'franchises'),
('final_fantasy_3', 'Guerrero de la Luz (Nivel 2)', 'Completa 3 juegos de Final Fantasy.', 'auto_awesome', 'rare', 50, 'franchises'),
('final_fantasy_5', 'Guerrero de la Luz (Maestro)', 'Completa 5 juegos de Final Fantasy.', 'auto_awesome', 'epic', 100, 'franchises'),

('call_of_duty_1', 'Veterano de Guerra (Nivel 1)', 'Completa 1 juego de la saga Call of Duty.', 'swords', 'common', 10, 'franchises'),
('call_of_duty_3', 'Veterano de Guerra (Nivel 2)', 'Completa 3 juegos de la saga Call of Duty.', 'swords', 'rare', 50, 'franchises'),
('call_of_duty_5', 'Veterano de Guerra (Maestro)', 'Completa 5 juegos de la saga Call of Duty.', 'swords', 'epic', 100, 'franchises'),

('elder_scrolls_1', 'Sangre de Dragón (Nivel 1)', 'Completa 1 juego de The Elder Scrolls.', 'swords', 'common', 10, 'franchises'),
('elder_scrolls_3', 'Sangre de Dragón (Nivel 2)', 'Completa 3 juegos de The Elder Scrolls.', 'swords', 'rare', 50, 'franchises'),
('elder_scrolls_5', 'Sangre de Dragón (Maestro)', 'Completa 5 juegos de The Elder Scrolls.', 'swords', 'epic', 100, 'franchises'),

('god_of_war_1', 'Fantasma de Esparta (Nivel 1)', 'Completa 1 juego de la saga God of War.', 'colorize', 'common', 10, 'franchises'),
('god_of_war_3', 'Fantasma de Esparta (Nivel 2)', 'Completa 3 juegos de la saga God of War.', 'colorize', 'rare', 50, 'franchises'),
('god_of_war_5', 'Fantasma de Esparta (Maestro)', 'Completa 5 juegos de la saga God of War.', 'colorize', 'epic', 100, 'franchises'),

('tomb_raider_1', 'Saqueadora de Tumbas (Nivel 1)', 'Completa 1 juego de la saga Tomb Raider.', 'explore', 'common', 10, 'franchises'),
('tomb_raider_3', 'Saqueadora de Tumbas (Nivel 2)', 'Completa 3 juegos de la saga Tomb Raider.', 'explore', 'rare', 50, 'franchises'),
('tomb_raider_5', 'Saqueadora de Tumbas (Maestro)', 'Completa 5 juegos de la saga Tomb Raider.', 'explore', 'epic', 100, 'franchises'),

('monster_hunter_1', 'Cazador de Bestias (Nivel 1)', 'Completa 1 juego de Monster Hunter.', 'pets', 'common', 10, 'franchises'),
('monster_hunter_3', 'Cazador de Bestias (Nivel 2)', 'Completa 3 juegos de Monster Hunter.', 'pets', 'rare', 50, 'franchises'),
('monster_hunter_5', 'Cazador de Bestias (Maestro)', 'Completa 5 juegos de Monster Hunter.', 'pets', 'epic', 100, 'franchises'),

('kingdom_hearts_1', 'Portador de la Llave (Nivel 1)', 'Completa 1 juego de Kingdom Hearts.', 'auto_awesome', 'common', 10, 'franchises'),
('kingdom_hearts_3', 'Portador de la Llave (Nivel 2)', 'Completa 3 juegos de Kingdom Hearts.', 'auto_awesome', 'rare', 50, 'franchises'),
('kingdom_hearts_5', 'Portador de la Llave (Maestro)', 'Completa 5 juegos de Kingdom Hearts.', 'auto_awesome', 'epic', 100, 'franchises'),

('silent_hill_1', 'Niebla Eterna (Nivel 1)', 'Completa 1 juego de Silent Hill.', 'visibility_off', 'common', 10, 'franchises'),
('silent_hill_3', 'Niebla Eterna (Nivel 2)', 'Completa 3 juegos de Silent Hill.', 'visibility_off', 'rare', 50, 'franchises'),
('silent_hill_5', 'Niebla Eterna (Maestro)', 'Completa 5 juegos de Silent Hill.', 'visibility_off', 'epic', 100, 'franchises'),

('metroid_1', 'Cazarrecompensas (Nivel 1)', 'Completa 1 juego de la saga Metroid.', 'biotech', 'common', 10, 'franchises'),
('metroid_3', 'Cazarrecompensas (Nivel 2)', 'Completa 3 juegos de la saga Metroid.', 'biotech', 'rare', 50, 'franchises'),
('metroid_5', 'Cazarrecompensas (Maestro)', 'Completa 5 juegos de la saga Metroid.', 'biotech', 'epic', 100, 'franchises'),

('kirby_1', 'Bola Rosa (Nivel 1)', 'Completa 1 juego de la saga Kirby.', 'pets', 'common', 10, 'franchises'),
('kirby_3', 'Bola Rosa (Nivel 2)', 'Completa 3 juegos de la saga Kirby.', 'pets', 'rare', 50, 'franchises'),
('kirby_5', 'Bola Rosa (Maestro)', 'Completa 5 juegos de la saga Kirby.', 'pets', 'epic', 100, 'franchises'),

('devil_may_cry_1', 'Cazador de Demonios (Nivel 1)', 'Completa 1 juego de Devil May Cry.', 'colorize', 'common', 10, 'franchises'),
('devil_may_cry_3', 'Cazador de Demonios (Nivel 2)', 'Completa 3 juegos de Devil May Cry.', 'colorize', 'rare', 50, 'franchises'),
('devil_may_cry_5', 'Cazador de Demonios (Maestro)', 'Completa 5 juegos de Devil May Cry.', 'colorize', 'epic', 100, 'franchises'),

('castlevania_1', 'Cazador de Vampiros (Nivel 1)', 'Completa 1 juego de Castlevania.', 'swords', 'common', 10, 'franchises'),
('castlevania_3', 'Cazador de Vampiros (Nivel 2)', 'Completa 3 juegos de Castlevania.', 'swords', 'rare', 50, 'franchises'),
('castlevania_5', 'Cazador de Vampiros (Maestro)', 'Completa 5 juegos de Castlevania.', 'swords', 'epic', 100, 'franchises'),

('mass_effect_1', 'Comandante Shepard (Nivel 1)', 'Completa 1 juego de la saga Mass Effect.', 'rocket_launch', 'common', 10, 'franchises'),
('mass_effect_3', 'Comandante Shepard (Nivel 2)', 'Completa 3 juegos de la saga Mass Effect.', 'rocket_launch', 'rare', 50, 'franchises'),
('mass_effect_4', 'Comandante Shepard (Maestro)', 'Completa 4 juegos de la saga Mass Effect.', 'rocket_launch', 'epic', 100, 'franchises'),

('doom_1', 'Slayer (Nivel 1)', 'Completa 1 juego de la saga DOOM.', 'local_fire_department', 'common', 10, 'franchises'),
('doom_3', 'Slayer (Nivel 2)', 'Completa 3 juegos de la saga DOOM.', 'local_fire_department', 'rare', 50, 'franchises'),
('doom_5', 'Slayer (Maestro)', 'Completa 5 juegos de la saga DOOM.', 'local_fire_department', 'epic', 100, 'franchises'),

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

-- 2. LIMPIEZA INTELIGENTE: Si queda algún logro con la frase vaga, lo reescribimos
UPDATE achievements 
SET description = 'Completa ' || COALESCE(substring(id from '_([0-9]+)$'), 'varios') || ' juegos de ' || initcap(replace(substring(id from '^([a-z_]+)_[0-9all]+$'), '_', ' ')) || '.'
WHERE description ILIKE '%esta saga o estudio%';

-- 3. MOTOR DE CÁLCULO BLINDADO CON LAS 42 SAGAS
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
    -- GENERALES
    IF EXISTS (SELECT 1 FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') THEN valid_ids := array_append(valid_ids, 'time_traveler'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.release_date < '2000-01-01') >= 20 THEN valid_ids := array_append(valid_ids, 'scholar_20th'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND extract(year from r.created_at) = extract(year from g.release_date::date)) >= 10 THEN valid_ids := array_append(valid_ids, 'vanguard'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform ILIKE '%PC%') >= 50 THEN valid_ids := array_append(valid_ids, 'pc_master_race'); END IF;
    IF (SELECT count(DISTINCT r.platform) FROM reviews r WHERE r.user_id = uid AND r.status = 'beaten' AND r.platform IS NOT NULL) >= 15 THEN valid_ids := array_append(valid_ids, 'multiplatform'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.genres::text ILIKE '%Role-playing%') >= 30 THEN valid_ids := array_append(valid_ids, 'rpg_veteran'); END IF;
    IF (SELECT count(DISTINCT r.game_id) FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND g.game_modes::text ILIKE '%Single player%') >= 50 THEN valid_ids := array_append(valid_ids, 'lone_wolf'); END IF;

    -- COMPAÑÍAS
    SELECT count(DISTINCT r.game_id) INTO v_kojima_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Kojima%' OR g.collection::text ILIKE '%Metal Gear%' OR g.collection::text ILIKE '%Zone of the Enders%' OR g.collection::text ILIKE '%Boktai%' OR g.title ILIKE '%Metal Gear%' OR g.title ILIKE '%Death Stranding%' OR g.title ILIKE '%Snatcher%' OR g.title ILIKE '%Policenauts%' OR g.title ILIKE '%Zone of the Enders%' OR g.title ILIKE '%Boktai%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_fromsoftware_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%FromSoftware%' OR g.title ILIKE '%Demon''s Souls%' OR g.title ILIKE '%Demon Souls%' OR g.title ILIKE '%Dark Souls%' OR g.title ILIKE '%Elden Ring%' OR g.title ILIKE '%Bloodborne%' OR g.title ILIKE '%Sekiro%' OR g.title ILIKE '%Armored Core%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_nintendo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Nintendo%' OR g.developer ILIKE '%HAL Laboratory%' OR g.developer ILIKE '%Intelligent Systems%' OR g.developer ILIKE '%Game Freak%' OR g.developer ILIKE '%Monolith Soft%' OR g.developer ILIKE '%Retro Studios%' OR g.developer ILIKE '%Next Level Games%' OR g.developer ILIKE '%Grezzo%' OR g.developer ILIKE '%Good-Feel%' OR g.developer ILIKE '%ND Cube%' OR g.developer ILIKE '%Sora Ltd%' OR g.developer ILIKE '%Camelot%' OR g.developer ILIKE '%Creatures Inc%' OR g.collection::text ILIKE '%Mario%' OR g.collection::text ILIKE '%Zelda%' OR g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%' OR g.collection::text ILIKE '%Metroid%' OR g.collection::text ILIKE '%Kirby%' OR g.collection::text ILIKE '%Donkey Kong%' OR g.collection::text ILIKE '%Fire Emblem%' OR g.collection::text ILIKE '%Splatoon%' OR g.collection::text ILIKE '%Pikmin%' OR g.collection::text ILIKE '%Animal Crossing%' OR g.collection::text ILIKE '%Star Fox%' OR g.collection::text ILIKE '%Xenoblade%' OR g.collection::text ILIKE '%Smash Bros%' OR g.franchises::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Pokemon%' OR g.franchises::text ILIKE '%Pokémon%' OR g.franchises::text ILIKE '%Metroid%' OR g.franchises::text ILIKE '%Kirby%' OR g.franchises::text ILIKE '%Donkey Kong%' OR g.franchises::text ILIKE '%Fire Emblem%' OR g.franchises::text ILIKE '%Splatoon%' OR g.franchises::text ILIKE '%Pikmin%' OR g.franchises::text ILIKE '%Animal Crossing%' OR g.franchises::text ILIKE '%Star Fox%' OR g.franchises::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Smash Bros%' OR g.title ILIKE '%Mario%' OR g.title ILIKE '%Zelda%' OR g.title ILIKE '%Pokemon%' OR g.title ILIKE '%Pokémon%' OR g.title ILIKE '%Metroid%' OR g.title ILIKE '%Kirby%' OR g.title ILIKE '%Donkey Kong%' OR g.title ILIKE '%Fire Emblem%' OR g.title ILIKE '%Splatoon%' OR g.title ILIKE '%Pikmin%' OR g.title ILIKE '%Animal Crossing%' OR g.title ILIKE '%Star Fox%' OR g.title ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_capcom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Capcom%' OR g.developer ILIKE '%Blue Castle%' OR g.developer ILIKE '%Ninja Theory%' OR g.developer ILIKE '%NeoBards%' OR g.developer ILIKE '%M-Two%' OR g.developer ILIKE '%HexaDrive%' OR g.developer ILIKE '%QLOC%' OR g.developer ILIKE '%TOSE%' OR g.collection::text ILIKE '%Resident Evil%' OR g.collection::text ILIKE '%Monster Hunter%' OR g.collection::text ILIKE '%Devil May Cry%' OR g.collection::text ILIKE '%Street Fighter%' OR g.collection::text ILIKE '%Mega Man%' OR g.collection::text ILIKE '%Ace Attorney%' OR g.collection::text ILIKE '%Dead Rising%' OR g.collection::text ILIKE '%Dragon''s Dogma%' OR g.collection::text ILIKE '%Onimusha%' OR g.collection::text ILIKE '%Dino Crisis%' OR g.collection::text ILIKE '%Okami%' OR g.collection::text ILIKE '%Darkstalkers%' OR g.franchises::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Monster Hunter%' OR g.franchises::text ILIKE '%Devil May Cry%' OR g.franchises::text ILIKE '%Street Fighter%' OR g.franchises::text ILIKE '%Mega Man%' OR g.franchises::text ILIKE '%Ace Attorney%' OR g.franchises::text ILIKE '%Dead Rising%' OR g.franchises::text ILIKE '%Dragon''s Dogma%' OR g.franchises::text ILIKE '%Onimusha%' OR g.franchises::text ILIKE '%Dino Crisis%' OR g.franchises::text ILIKE '%Okami%' OR g.franchises::text ILIKE '%Darkstalkers%' OR g.title ILIKE '%Resident Evil%' OR g.title ILIKE '%Monster Hunter%' OR g.title ILIKE '%Devil May Cry%' OR g.title ILIKE '%Street Fighter%' OR g.title ILIKE '%Mega Man%' OR g.title ILIKE '%Ace Attorney%' OR g.title ILIKE '%Dead Rising%' OR g.title ILIKE '%Dragon''s Dogma%' OR g.title ILIKE '%Onimusha%' OR g.title ILIKE '%Dino Crisis%' OR g.title ILIKE '%Okami%' OR g.title ILIKE '%Darkstalkers%') AND g.title NOT ILIKE '%Smash Bros%' AND g.title NOT ILIKE '%Project X Zone%' AND g.title NOT ILIKE '%Vs. Capcom%' AND g.title NOT ILIKE '%Vs Capcom%' AND g.title NOT ILIKE '%All-Stars%' AND g.title NOT ILIKE '%Fortnite%' AND g.title NOT ILIKE '%Dead by Daylight%' AND g.title NOT ILIKE '%Teppen%' AND g.title NOT ILIKE '%Poker Night%' AND g.title NOT ILIKE '%Cross Tag%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_naughty_dog_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Naughty Dog%' OR g.collection::text ILIKE '%Uncharted%' OR g.collection::text ILIKE '%The Last of Us%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_rockstar_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Rockstar%' OR g.collection::text ILIKE '%Grand Theft Auto%' OR g.collection::text ILIKE '%Red Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_cd_projekt_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%CD Projekt%' OR g.collection::text ILIKE '%Witcher%' OR g.collection::text ILIKE '%Cyberpunk%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_konami_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Konami%' OR g.developer ILIKE '%Bloober Team%' OR g.developer ILIKE '%MercurySteam%' OR g.developer ILIKE '%PlatinumGames%' OR g.developer ILIKE '%HexaDrive%' OR g.developer ILIKE '%Double Helix%' OR g.developer ILIKE '%Climax%' OR g.developer ILIKE '%WayForward%' OR g.collection::text ILIKE '%Metal Gear%' OR g.collection::text ILIKE '%Silent Hill%' OR g.collection::text ILIKE '%Castlevania%' OR g.collection::text ILIKE '%Contra%' OR g.collection::text ILIKE '%Pro Evolution%' OR g.collection::text ILIKE '%eFootball%' OR g.collection::text ILIKE '%Suikoden%' OR g.collection::text ILIKE '%Bomberman%' OR g.collection::text ILIKE '%Frogger%' OR g.collection::text ILIKE '%Zone of the Enders%' OR g.franchises::text ILIKE '%Metal Gear%' OR g.franchises::text ILIKE '%Silent Hill%' OR g.franchises::text ILIKE '%Castlevania%' OR g.franchises::text ILIKE '%Contra%' OR g.franchises::text ILIKE '%Pro Evolution%' OR g.franchises::text ILIKE '%eFootball%' OR g.franchises::text ILIKE '%Suikoden%' OR g.franchises::text ILIKE '%Bomberman%' OR g.franchises::text ILIKE '%Frogger%' OR g.franchises::text ILIKE '%Zone of the Enders%' OR g.title ILIKE '%Metal Gear%' OR g.title ILIKE '%Silent Hill%' OR g.title ILIKE '%Castlevania%' OR g.title ILIKE '%Contra%' OR g.title ILIKE '%Pro Evolution%' OR g.title ILIKE '%eFootball%' OR g.title ILIKE '%Suikoden%' OR g.title ILIKE '%Bomberman%' OR g.title ILIKE '%Frogger%' OR g.title ILIKE '%Zone of the Enders%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_valve_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Valve%' OR g.developer ILIKE '%Crowbar Collective%' OR g.title ILIKE '%Black Mesa%' OR g.collection::text ILIKE '%Half-Life%' OR g.collection::text ILIKE '%Portal%' OR g.collection::text ILIKE '%Left 4 Dead%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_remedy_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Remedy%' OR g.collection::text ILIKE '%Alan Wake%' OR g.title ILIKE '%Control%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_team_ninja_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Team Ninja%' OR g.developer ILIKE '%Koei Tecmo%' OR g.collection::text ILIKE '%Ninja Gaiden%' OR g.collection::text ILIKE '%Nioh%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_square_enix_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Square Enix%' OR g.developer ILIKE '%Squaresoft%' OR g.developer ILIKE '%Enix%' OR g.collection::text ILIKE '%Final Fantasy%' OR g.collection::text ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_bethesda_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.developer ILIKE '%Bethesda%' OR g.developer ILIKE '%ZeniMax%' OR g.developer ILIKE '%Arkane%' OR g.developer ILIKE '%id Software%' OR g.developer ILIKE '%MachineGames%' OR g.collection::text ILIKE '%Elder Scrolls%' OR g.collection::text ILIKE '%Fallout%' OR g.collection::text ILIKE '%DOOM%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- SAGAS
    SELECT count(DISTINCT r.game_id) INTO v_zelda_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Zelda%' OR g.franchises::text ILIKE '%Zelda%' OR g.title ILIKE '%Zelda%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_mario_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mario%' OR g.franchises::text ILIKE '%Mario%' OR g.title ILIKE '%Super Mario%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_pokemon_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Pokemon%' OR g.collection::text ILIKE '%Pokémon%' OR g.title ILIKE '%Pokemon%' OR g.title ILIKE '%Pokémon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_re_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Resident Evil%' OR g.franchises::text ILIKE '%Resident Evil%' OR g.title ILIKE '%Resident Evil%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ds_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dark Souls%' OR g.franchises::text ILIKE '%Dark Souls%' OR g.title ILIKE '%Dark Souls%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ac_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Assassin''s Creed%' OR g.franchises::text ILIKE '%Assassin''s Creed%' OR g.title ILIKE '%Assassin''s Creed%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_ff_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Final Fantasy%' OR g.franchises::text ILIKE '%Final Fantasy%' OR g.title ILIKE '%Final Fantasy%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_cod_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Call of Duty%' OR g.franchises::text ILIKE '%Call of Duty%' OR g.title ILIKE '%Call of Duty%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_es_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Elder Scrolls%' OR g.franchises::text ILIKE '%Elder Scrolls%' OR g.title ILIKE '%Elder Scrolls%' OR g.title ILIKE '%Skyrim%' OR g.title ILIKE '%Oblivion%' OR g.title ILIKE '%Morrowind%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_gow_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%God of War%' OR g.franchises::text ILIKE '%God of War%' OR g.title ILIKE '%God of War%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_tomb_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Tomb Raider%' OR g.franchises::text ILIKE '%Tomb Raider%' OR g.title ILIKE '%Tomb Raider%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_mh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Monster Hunter%' OR g.franchises::text ILIKE '%Monster Hunter%' OR g.title ILIKE '%Monster Hunter%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_kh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kingdom Hearts%' OR g.franchises::text ILIKE '%Kingdom Hearts%' OR g.title ILIKE '%Kingdom Hearts%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_sh_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Silent Hill%' OR g.franchises::text ILIKE '%Silent Hill%' OR g.title ILIKE '%Silent Hill%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_metroid_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metroid%' OR g.franchises::text ILIKE '%Metroid%' OR g.title ILIKE '%Metroid%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_kirby_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Kirby%' OR g.franchises::text ILIKE '%Kirby%' OR g.title ILIKE '%Kirby%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_dmc_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Devil May Cry%' OR g.franchises::text ILIKE '%Devil May Cry%' OR g.title ILIKE '%Devil May Cry%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_castlevania_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Castlevania%' OR g.franchises::text ILIKE '%Castlevania%' OR g.title ILIKE '%Castlevania%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_me_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Mass Effect%' OR g.franchises::text ILIKE '%Mass Effect%' OR g.title ILIKE '%Mass Effect%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_doom_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%DOOM%' OR g.franchises::text ILIKE '%DOOM%' OR g.title ILIKE '%DOOM%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_bioshock_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%BioShock%' OR g.franchises::text ILIKE '%BioShock%' OR g.title ILIKE '%BioShock%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_borderlands_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Borderlands%' OR g.franchises::text ILIKE '%Borderlands%' OR g.title ILIKE '%Borderlands%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    -- EXCLUSIÓN EXPLÍCITA DE METROID EN METRO
    SELECT count(DISTINCT r.game_id) INTO v_metro_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Metro%' OR g.franchises::text ILIKE '%Metro%' OR g.title ILIKE '%Metro 2033%' OR g.title ILIKE '%Metro: Last Light%' OR g.title ILIKE '%Metro Exodus%') AND g.title NOT ILIKE '%Metroid%' AND g.collection::text NOT ILIKE '%Metroid%' AND g.franchises::text NOT ILIKE '%Metroid%' AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    
    SELECT count(DISTINCT r.game_id) INTO v_dead_space_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Dead Space%' OR g.franchises::text ILIKE '%Dead Space%' OR g.title ILIKE '%Dead Space%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_yakuza_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Yakuza%' OR g.collection::text ILIKE '%Like a Dragon%' OR g.title ILIKE '%Yakuza%' OR g.title ILIKE '%Like a Dragon%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_xenoblade_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Xenoblade%' OR g.franchises::text ILIKE '%Xenoblade%' OR g.title ILIKE '%Xenoblade%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_persona_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Persona%' OR g.collection::text ILIKE '%Shin Megami Tensei%' OR g.title ILIKE '%Persona%' OR g.title ILIKE '%Shin Megami Tensei%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_halo_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Halo%' OR g.franchises::text ILIKE '%Halo%' OR g.title ILIKE '%Halo%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);
    SELECT count(DISTINCT r.game_id) INTO v_sonic_count FROM reviews r JOIN games g ON r.game_id = g.igdb_id WHERE r.user_id = uid AND r.status = 'beaten' AND (g.collection::text ILIKE '%Sonic%' OR g.franchises::text ILIKE '%Sonic%' OR g.title ILIKE '%Sonic%') AND (g.category IN (0,8,9,10,11) OR g.category IS NULL);

    -- ASIGNACIÓN DE LOGROS
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
    IF v_metroid_count >= 5 THEN valid_ids := array_append(valid_ids, 'metroid_5'); END IF;

    IF v_kirby_count >= 1 THEN valid_ids := array_append(valid_ids, 'kirby_1'); END IF;
    IF v_kirby_count >= 3 THEN valid_ids := array_append(valid_ids, 'kirby_3'); END IF;
    IF v_kirby_count >= 5 THEN valid_ids := array_append(valid_ids, 'kirby_5'); END IF;

    IF v_dmc_count >= 1 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_1'); END IF;
    IF v_dmc_count >= 3 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_3'); END IF;
    IF v_dmc_count >= 5 THEN valid_ids := array_append(valid_ids, 'devil_may_cry_5'); END IF;

    IF v_castlevania_count >= 1 THEN valid_ids := array_append(valid_ids, 'castlevania_1'); END IF;
    IF v_castlevania_count >= 3 THEN valid_ids := array_append(valid_ids, 'castlevania_3'); END IF;
    IF v_castlevania_count >= 5 THEN valid_ids := array_append(valid_ids, 'castlevania_5'); END IF;

    IF v_me_count >= 1 THEN valid_ids := array_append(valid_ids, 'mass_effect_1'); END IF;
    IF v_me_count >= 3 THEN valid_ids := array_append(valid_ids, 'mass_effect_3'); END IF;
    IF v_me_count >= 4 THEN valid_ids := array_append(valid_ids, 'mass_effect_4'); END IF;

    IF v_doom_count >= 1 THEN valid_ids := array_append(valid_ids, 'doom_1'); END IF;
    IF v_doom_count >= 3 THEN valid_ids := array_append(valid_ids, 'doom_3'); END IF;
    IF v_doom_count >= 5 THEN valid_ids := array_append(valid_ids, 'doom_5'); END IF;

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

    -- ELIMINAR LOS QUE YA NO SE CUMPLEN E INSERTAR LOS VÁLIDOS
    DELETE FROM public.user_achievements WHERE user_id = uid AND achievement_id != ALL(valid_ids);
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT uid, unnest(valid_ids) ON CONFLICT (user_id, achievement_id) DO NOTHING;
END;
$$;

-- 4. RECALCULAR PARA TODOS LOS USUARIOS
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT id FROM auth.users LOOP
        PERFORM public.check_user_achievements(r.id);
        PERFORM public.calculate_user_xp(r.id);
    END LOOP;
END $$;


