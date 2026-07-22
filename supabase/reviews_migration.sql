-- ============================================================
-- MIGRACIÓN: Sistema de Reseñas Mejorado
-- Ejecutar en Supabase SQL Editor (en orden)
-- ============================================================

-- 1. Crear la tabla de reseñas
CREATE TABLE reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id INTEGER NOT NULL REFERENCES games(igdb_id),
  
  -- Nota y subnotas
  rating DOUBLE PRECISION CHECK (rating >= 1 AND rating <= 10),
  rating_gameplay DOUBLE PRECISION CHECK (rating_gameplay >= 1 AND rating_gameplay <= 10),
  rating_narrative DOUBLE PRECISION CHECK (rating_narrative >= 1 AND rating_narrative <= 10),
  rating_soundtrack DOUBLE PRECISION CHECK (rating_soundtrack >= 1 AND rating_soundtrack <= 10),
  rating_visuals DOUBLE PRECISION CHECK (rating_visuals >= 1 AND rating_visuals <= 10),
  comment TEXT,
  
  -- Estado al momento de la reseña
  status TEXT NOT NULL DEFAULT 'beaten',
  
  -- Nuevos campos
  completion_type TEXT NOT NULL DEFAULT 'story',
  is_replay BOOLEAN NOT NULL DEFAULT false,
  replay_number INTEGER,
  
  -- Info extra
  platform TEXT,
  play_time_hours DOUBLE PRECISION,
  played_from DATE,
  played_until DATE,
  progress_percent INTEGER CHECK (progress_percent >= 0 AND progress_percent <= 100),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. RLS para la tabla reviews
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read reviews" ON reviews FOR SELECT USING (true);
CREATE POLICY "Users can insert own reviews" ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews" ON reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews" ON reviews FOR DELETE USING (auth.uid() = user_id);

-- 3. Migrar datos existentes de user_games a reviews
-- (Solo los que tienen rating o comment — los que realmente tienen reseña)
INSERT INTO reviews (user_id, game_id, rating, rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals, comment, status, created_at)
SELECT 
  user_id, game_id, rating, rating_gameplay, rating_narrative, rating_soundtrack, rating_visuals, comment, status,
  COALESCE(updated_at, NOW())
FROM user_games
WHERE rating IS NOT NULL OR (comment IS NOT NULL AND comment != '');

-- 4. Añadir columna review_id a review_likes y review_comments
ALTER TABLE review_likes ADD COLUMN review_id UUID REFERENCES reviews(id) ON DELETE CASCADE;
ALTER TABLE review_comments ADD COLUMN review_id UUID REFERENCES reviews(id) ON DELETE CASCADE;

-- 5. Migrar likes existentes: vincularlos a la reseña correspondiente
UPDATE review_likes rl
SET review_id = r.id
FROM reviews r
WHERE r.user_id = rl.review_user_id 
  AND r.game_id = rl.review_game_id;

-- 6. Migrar comments existentes: vincularlos a la reseña correspondiente
UPDATE review_comments rc
SET review_id = r.id
FROM reviews r
WHERE r.user_id = rc.review_user_id 
  AND r.game_id = rc.review_game_id;

-- 7. Limpiar huérfanos (likes/comments que no pudieron vincularse)
DELETE FROM review_likes WHERE review_id IS NULL;
DELETE FROM review_comments WHERE review_id IS NULL;

-- 8. Ahora que todos tienen review_id, hacerlo NOT NULL
ALTER TABLE review_likes ALTER COLUMN review_id SET NOT NULL;
ALTER TABLE review_comments ALTER COLUMN review_id SET NOT NULL;

-- 9. (Opcional) Eliminar columnas antiguas que ya no se necesitan
-- Dejamos review_user_id y review_game_id por ahora por seguridad
-- ALTER TABLE review_likes DROP COLUMN review_user_id, DROP COLUMN review_game_id;
-- ALTER TABLE review_comments DROP COLUMN review_user_id, DROP COLUMN review_game_id;

-- 10. Índices para rendimiento
CREATE INDEX idx_reviews_user_game ON reviews(user_id, game_id);
CREATE INDEX idx_reviews_created_at ON reviews(created_at DESC);
CREATE INDEX idx_review_likes_review_id ON review_likes(review_id);
CREATE INDEX idx_review_comments_review_id ON review_comments(review_id);
