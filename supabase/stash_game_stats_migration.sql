-- =====================================================================
-- CORPUS: MIGRACIÓN STASH GAME STATS
-- Nueva tabla y RLS para Stash Rating + Stats (Quiero/Jugando/Jugado/Reseñas)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.stash_game_stats (
  game_id integer NOT NULL,
  stash_rating numeric,
  want_count integer,
  playing_count integer,
  played_count integer,
  reviews_count integer,          -- viene de fetch-stash-reviews (data.total), NO del endpoint de stats
  last_stats_checked_at timestamp with time zone,   -- se actualiza al llamar fetch-stash-game-stats
  last_reviews_total_checked_at timestamp with time zone, -- se actualiza al llamar fetch-stash-reviews
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT stash_game_stats_pkey PRIMARY KEY (game_id),
  CONSTRAINT stash_game_stats_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id)
);

-- Habilitar RLS en stash_game_stats
ALTER TABLE public.stash_game_stats ENABLE ROW LEVEL SECURITY;

-- Política SELECT para rol authenticated
DROP POLICY IF EXISTS "stash_game_stats_select_authenticated" ON public.stash_game_stats;
CREATE POLICY "stash_game_stats_select_authenticated"
  ON public.stash_game_stats FOR SELECT
  TO authenticated
  USING (true);
