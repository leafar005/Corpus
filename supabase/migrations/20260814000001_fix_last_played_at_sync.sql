-- =============================================================================
-- Fix: last_played_at nunca se actualizaba al guardar una reseña, así que el
-- orden de "Completados"/"Platinos" en el perfil usaba updated_at (= now() en
-- cada guardado) en vez de la fecha real que el usuario elige en la reseña.
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO user_games (
    user_id, game_id, status, rating,
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals,
    comment, partner_id, updated_at, last_played_at, is_steam_only
  ) VALUES (
    NEW.user_id, NEW.game_id, NEW.status, NEW.rating,
    NEW.rating_gameplay, NEW.rating_narrative, NEW.rating_soundtrack, NEW.rating_visuals,
    NEW.comment, NEW.partner_id, now(),
    COALESCE(NEW.played_until, NEW.created_at), false
  )
  ON CONFLICT (user_id, game_id) DO UPDATE SET
    status = EXCLUDED.status,
    rating = EXCLUDED.rating,
    rating_gameplay = EXCLUDED.rating_gameplay,
    rating_narrative = EXCLUDED.rating_narrative,
    rating_soundtrack = EXCLUDED.rating_soundtrack,
    rating_visuals = EXCLUDED.rating_visuals,
    comment = EXCLUDED.comment,
    partner_id = EXCLUDED.partner_id,
    updated_at = EXCLUDED.updated_at,
    last_played_at = EXCLUDED.last_played_at;
  RETURN NEW;
END;
$$;

-- Backfill: recalcula last_played_at para todo lo que ya tiene reseña,
-- así el orden se corrige sin esperar a que el usuario re-guarde cada juego.
UPDATE public.user_games ug
SET last_played_at = sub.review_date
FROM (
  SELECT DISTINCT ON (user_id, game_id)
    user_id, game_id, COALESCE(played_until, created_at) AS review_date
  FROM public.reviews
  ORDER BY user_id, game_id, created_at DESC
) sub
WHERE ug.user_id = sub.user_id
  AND ug.game_id = sub.game_id
  AND (ug.last_played_at IS NULL OR ug.last_played_at <> sub.review_date);
