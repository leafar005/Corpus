-- =====================================================================
-- 05_storage_and_cron.sql: Storage Buckets, Policies and pg_cron tasks
-- =====================================================================

-- >>> FROM: storage_migration.sql <<<
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
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Permitir a usuarios logueados subir su propio avatar
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados actualizar su propio avatar
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados borrar su propio avatar
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
CREATE POLICY "Banner images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'banners');

-- Permitir a usuarios logueados subir su propio banner
CREATE POLICY "Users can upload their own banners"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados actualizar su propio banner
CREATE POLICY "Users can update their own banners"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);

-- Permitir a usuarios logueados borrar su propio banner
CREATE POLICY "Users can delete their own banners"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'banners' AND 
  auth.role() = 'authenticated'
);


-- >>> FROM: add_images_to_reviews.sql <<<
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
CREATE POLICY "Public Access to user_uploads"
ON storage.objects FOR SELECT
USING (bucket_id = 'user_uploads');

-- Permitir a los usuarios logueados SUBIR imágenes
CREATE POLICY "Authenticated users can upload to user_uploads"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'user_uploads' AND
    auth.role() = 'authenticated'
);

-- Permitir a los usuarios logueados ELIMINAR sus propias imágenes
CREATE POLICY "Users can delete their own uploads"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'user_uploads' AND
    auth.uid() = owner
);


-- >>> FROM: fix_storage_policies.sql <<<
-- Arreglar políticas RLS para los buckets avatars y banners

-- Habilitar inserción (uploads) en el bucket 'avatars' para usuarios autenticados
DROP POLICY IF EXISTS "Avatars Upload Policy" ON storage.objects;
CREATE POLICY "Avatars Upload Policy" ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Habilitar actualización (updates) en el bucket 'avatars' para usuarios autenticados
DROP POLICY IF EXISTS "Avatars Update Policy" ON storage.objects;
CREATE POLICY "Avatars Update Policy" ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'avatars' AND 
    auth.role() = 'authenticated'
);

-- Habilitar inserción (uploads) en el bucket 'banners' para usuarios autenticados
DROP POLICY IF EXISTS "Banners Upload Policy" ON storage.objects;
CREATE POLICY "Banners Upload Policy" ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'banners' AND 
    auth.role() = 'authenticated'
);

-- Habilitar actualización (updates) en el bucket 'banners' para usuarios autenticados
DROP POLICY IF EXISTS "Banners Update Policy" ON storage.objects;
CREATE POLICY "Banners Update Policy" ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'banners' AND 
    auth.role() = 'authenticated'
);

-- Opcional: Asegurarnos de que tengan política de Select (lectura pública) por si no la tuvieran
DROP POLICY IF EXISTS "Avatars Select Policy" ON storage.objects;
CREATE POLICY "Avatars Select Policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Banners Select Policy" ON storage.objects;
CREATE POLICY "Banners Select Policy" ON storage.objects
FOR SELECT
USING (bucket_id = 'banners');


-- >>> FROM: setup_cron_feed.sql <<<
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


-- >>> FROM: active_bundles_setup.sql <<<
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


