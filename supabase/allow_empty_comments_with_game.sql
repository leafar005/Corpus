-- Actualizar la restricción para permitir comentarios vacíos si hay un juego adjunto

-- 1. Eliminar la restricción anterior
ALTER TABLE public.review_comments DROP CONSTRAINT IF EXISTS review_comments_content_or_image_check;

-- 2. Añadir la nueva restricción que incluye attached_game
ALTER TABLE public.review_comments ADD CONSTRAINT review_comments_content_or_image_check 
CHECK (
    (content IS NOT NULL AND char_length(content) > 0) OR 
    (image_url IS NOT NULL AND char_length(image_url) > 0) OR
    (attached_game IS NOT NULL)
);
