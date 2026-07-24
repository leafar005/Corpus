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
