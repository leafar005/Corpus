-- =============================================================================
-- Plataformas de propiedad por juego (estantería virtual).
-- Permite al usuario indicar en qué plataforma(s) posee cada juego de su
-- biblioteca, independientemente de las reseñas.
-- Migración aditiva: no modifica tablas existentes.
-- =============================================================================

CREATE TABLE public.user_game_platforms (
    user_id       uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    game_id       integer     NOT NULL REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    platform_name text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, game_id, platform_name)
);

COMMENT ON TABLE public.user_game_platforms IS
    'Plataformas en las que el usuario posee cada juego (estantería / colección visual).';

CREATE INDEX idx_user_game_platforms_user_id
    ON public.user_game_platforms (user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_game_platforms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user owns their game platforms"
    ON public.user_game_platforms FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "anyone can view game platforms"
    ON public.user_game_platforms FOR SELECT
    USING (true);
