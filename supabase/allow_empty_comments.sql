-- Permitir que un comentario no tenga texto si incluye una imagen.
-- 1. Quitamos la restricción NOT NULL de la columna 'content'
ALTER TABLE public.review_comments ALTER COLUMN content DROP NOT NULL;

-- 2. Quitamos el check anterior que obligaba a que el texto tuviera length > 0
-- (Para quitarlo sin saber el nombre exacto, podemos intentar usar el bloque DO)
DO $$
DECLARE
    constraint_name text;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.review_comments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%char_length(content) > 0%';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.review_comments DROP CONSTRAINT ' || constraint_name;
    END IF;
END $$;

-- 3. Añadimos un nuevo CHECK que garantice que haya texto o haya imagen (o ambas)
ALTER TABLE public.review_comments ADD CONSTRAINT review_comments_content_or_image_check 
CHECK (
    (content IS NOT NULL AND char_length(content) > 0) OR 
    (image_url IS NOT NULL AND char_length(image_url) > 0)
);
