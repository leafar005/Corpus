-- =============================================================================
-- Fix: sync_user_games_rating_from_review quedó apuntando a la columna vieja
-- "partner_id" (singular) tras el fix de last_played_at, en vez de a
-- "partner_ids" (array), que es la que existe desde 20260808000000.
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO user_games (
    user_id, game_id, status, rating,
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals,
    comment, partner_ids, updated_at, last_played_at, is_steam_only
  ) VALUES (
    NEW.user_id, NEW.game_id, NEW.status, NEW.rating,
    NEW.rating_gameplay, NEW.rating_narrative, NEW.rating_soundtrack, NEW.rating_visuals,
    NEW.comment, NEW.partner_ids, now(),
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
    partner_ids = EXCLUDED.partner_ids,
    updated_at = EXCLUDED.updated_at,
    last_played_at = EXCLUDED.last_played_at;
  RETURN NEW;
END;
$$;
