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
