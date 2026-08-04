-- =============================================================================
-- Migración: B-M1 Fix: Trigger UPSERT para user_games
-- =============================================================================
-- El trigger original hacía un UPDATE. Pero si el usuario añadía una review
-- sin tener el juego en su librería, el UPDATE fallaba silenciosamente y no 
-- se creaba el registro en user_games. Lo cambiamos a UPSERT.
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO user_games (
    user_id, game_id, status, rating, 
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals, 
    comment, partner_id, updated_at, is_steam_only
  ) VALUES (
    NEW.user_id, NEW.game_id, NEW.status, NEW.rating,
    NEW.rating_gameplay, NEW.rating_narrative, NEW.rating_soundtrack, NEW.rating_visuals,
    NEW.comment, NEW.partner_id, now(), false
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
    updated_at = EXCLUDED.updated_at;
  RETURN NEW;
END;
$$;
