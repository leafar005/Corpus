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
