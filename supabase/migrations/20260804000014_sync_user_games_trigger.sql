-- =============================================================================
-- Migración: B-M1 Trigger para sincronizar user_games desde reviews
-- =============================================================================
-- Cuando el cliente guarda una review, escribía los ratings manualmente
-- tanto en la tabla `reviews` como en `user_games`. 
-- Esto lo unificamos para que la BD lo mantenga sincronizado automáticamente
-- y eliminamos la escritura duplicada desde Dart.
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
  INSERT INTO user_games (
    user_id, game_id, status, rating, 
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals, 
    comment, partner_id, updated_at
  ) VALUES (
    NEW.user_id, NEW.game_id, NEW.status, NEW.rating,
    NEW.rating_gameplay, NEW.rating_narrative, NEW.rating_soundtrack, NEW.rating_visuals,
    NEW.comment, NEW.partner_id, now()
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

DROP TRIGGER IF EXISTS trg_sync_user_games_on_review ON reviews;
CREATE TRIGGER trg_sync_user_games_on_review
AFTER INSERT OR UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION sync_user_games_rating_from_review();
