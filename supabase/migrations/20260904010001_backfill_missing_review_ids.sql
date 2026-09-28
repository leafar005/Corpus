-- =============================================================================
-- Migración: Backfill para arreglar los status_change huérfanos
-- =============================================================================
-- Esta migración actualiza los eventos 'status_change' en el feed de actividad
-- que se crearon con `review_id` = NULL debido al bug de la migración previa.
-- Busca la reseña más reciente de ese usuario y juego y la enlaza para que
-- vuelvan a aparecer los likes y comentarios en esos posts.
-- =============================================================================

UPDATE public.activity_feed af
SET review_id = (
    SELECT r.id 
    FROM public.reviews r
    WHERE r.user_id = af.user_id 
      AND r.game_id = af.game_id
    ORDER BY r.created_at DESC
    LIMIT 1
)
WHERE af.action_type = 'status_change'
  AND af.review_id IS NULL;
