-- =============================================================================
-- Migración: Soporte para múltiples amigos (partner_ids)
-- =============================================================================

-- 1. Añadir nuevas columnas array
ALTER TABLE public.reviews ADD COLUMN partner_ids UUID[] DEFAULT '{}'::uuid[];
ALTER TABLE public.user_games ADD COLUMN partner_ids UUID[] DEFAULT '{}'::uuid[];

-- 2. Migrar datos existentes
UPDATE public.reviews SET partner_ids = ARRAY[partner_id] WHERE partner_id IS NOT NULL;
UPDATE public.user_games SET partner_ids = ARRAY[partner_id] WHERE partner_id IS NOT NULL;

-- 3. Actualizar trigger para sincronizar partner_ids en lugar de partner_id
CREATE OR REPLACE FUNCTION sync_user_games_rating_from_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO user_games (
    user_id, game_id, status, rating, 
    rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals, 
    comment, partner_ids, updated_at, is_steam_only
  ) VALUES (
    NEW.user_id, NEW.game_id, NEW.status, NEW.rating,
    NEW.rating_gameplay, NEW.rating_narrative, NEW.rating_soundtrack, NEW.rating_visuals,
    NEW.comment, NEW.partner_ids, now(), false
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
    updated_at = EXCLUDED.updated_at;
  RETURN NEW;
END;
$$;

-- 4. Eliminar las foreign keys y columnas antiguas
ALTER TABLE public.user_games DROP CONSTRAINT IF EXISTS user_games_partner_id_fkey;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_partner_id_fkey;

ALTER TABLE public.reviews DROP COLUMN IF EXISTS partner_id;
ALTER TABLE public.user_games DROP COLUMN IF EXISTS partner_id;
