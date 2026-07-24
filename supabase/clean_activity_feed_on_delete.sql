-- Limpiar actividades residuales existentes de reseñas que ya no existen
DELETE FROM public.activity_feed
WHERE action_type = 'reviewed'
  AND NOT EXISTS (
      SELECT 1 FROM public.reviews r 
      WHERE r.id::text = activity_feed.metadata->>'review_id'
  );

-- Limpiar actividades residuales existentes de juegos que ya no están en la biblioteca
DELETE FROM public.activity_feed
WHERE action_type = 'status_change'
  AND NOT EXISTS (
      SELECT 1 FROM public.user_games ug
      WHERE ug.user_id = activity_feed.user_id
        AND ug.game_id = activity_feed.game_id
  );

-- Función y trigger para limpiar el feed cuando se elimina un juego de la biblioteca
CREATE OR REPLACE FUNCTION public.on_user_game_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    DELETE FROM public.activity_feed
    WHERE user_id = OLD.user_id 
      AND game_id = OLD.game_id 
      AND action_type = 'status_change';
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_game_delete ON public.user_games;
CREATE TRIGGER trg_user_game_delete
AFTER DELETE ON public.user_games
FOR EACH ROW EXECUTE FUNCTION public.on_user_game_delete();

-- Función y trigger para limpiar el feed cuando se elimina una reseña
CREATE OR REPLACE FUNCTION public.on_review_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    DELETE FROM public.activity_feed
    WHERE user_id = OLD.user_id 
      AND game_id = OLD.game_id 
      AND action_type = 'reviewed'
      AND metadata->>'review_id' = OLD.id::text;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_delete ON public.reviews;
CREATE TRIGGER trg_review_delete
AFTER DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.on_review_delete();
