-- Queremos evitar duplicar la reseña del mismo usuario para el mismo juego cada vez que ejecutemos el fetch
-- Primero borramos duplicados si los hubiera (dejando solo la importación más reciente)
DELETE FROM public.stash_community_reviews a USING (
    SELECT MIN(ctid) as ctid, game_id, stash_user_display_name
    FROM public.stash_community_reviews 
    GROUP BY game_id, stash_user_display_name HAVING COUNT(*) > 1
) b
WHERE a.game_id = b.game_id 
AND a.stash_user_display_name = b.stash_user_display_name 
AND a.ctid <> b.ctid;

-- Añadimos la restricción única
ALTER TABLE public.stash_community_reviews
ADD CONSTRAINT uq_game_user UNIQUE (game_id, stash_user_display_name);
