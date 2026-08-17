-- Nuevo archivo: supabase/migrations/20260818000003_fix_partner_id_typo.sql
-- Parche para arreglar el typo partner_id -> partner_ids en la migración 20260818000000

CREATE OR REPLACE FUNCTION public.sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  target_user_id uuid := COALESCE(NEW.user_id, OLD.user_id);
  target_game_id integer := COALESCE(NEW.game_id, OLD.game_id);
  latest RECORD;
BEGIN
  -- La reseña vigente es la más reciente para ese (user_id, game_id).
  SELECT r.status, r.rating, r.rating_gameplay, r.rating_narrative,
         r.rating_soundtrack, r.rating_visuals, r.comment, r.partner_ids,
         COALESCE(r.played_until, r.created_at) AS last_played_at
    INTO latest
    FROM public.reviews r
   WHERE r.user_id = target_user_id AND r.game_id = target_game_id
   ORDER BY COALESCE(r.played_until, r.created_at) DESC, r.created_at DESC, r.id DESC
   LIMIT 1;

  IF latest IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  INSERT INTO public.user_games (
    user_id, game_id, status, rating,
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals,
    comment, partner_ids, updated_at, last_played_at, is_steam_only
  ) VALUES (
    target_user_id, target_game_id, latest.status, latest.rating,
    latest.rating_gameplay, latest.rating_narrative, latest.rating_soundtrack,
    latest.rating_visuals, latest.comment, latest.partner_ids, now(),
    latest.last_played_at, false
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

  RETURN COALESCE(NEW, OLD);
END;
$$;
