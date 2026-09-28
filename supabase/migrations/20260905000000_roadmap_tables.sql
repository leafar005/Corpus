-- =============================================================================
-- Roadmap: planificación visual de backlog (árbol / DAG de juegos).
-- Migración aditiva: no modifica tablas existentes.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- roadmap_nodes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.roadmap_nodes (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    game_id      integer     NOT NULL REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    status       text        NOT NULL DEFAULT 'up_next'
                             CHECK (status IN ('up_next', 'playing', 'completed', 'skipped')),
    position_x   real        NOT NULL DEFAULT 0,
    position_y   real        NOT NULL DEFAULT 0,
    label        text,
    platform     text,
    priority     smallint    NOT NULL DEFAULT 0,
    is_root      boolean     NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, game_id)
);

COMMENT ON TABLE public.roadmap_nodes IS
    'Nodos del roadmap personal: un juego planificado con posición visual y metadata.';

CREATE INDEX idx_roadmap_nodes_user_id ON public.roadmap_nodes (user_id);
CREATE INDEX idx_roadmap_nodes_user_status ON public.roadmap_nodes (user_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- roadmap_edges
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.roadmap_edges (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source_node_id   uuid        NOT NULL REFERENCES public.roadmap_nodes(id) ON DELETE CASCADE,
    target_node_id   uuid        NOT NULL REFERENCES public.roadmap_nodes(id) ON DELETE CASCADE,
    condition_label  text,
    is_preferred     boolean     NOT NULL DEFAULT false,
    sort_order       smallint    NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_node_id, target_node_id),
    CHECK (source_node_id <> target_node_id)
);

COMMENT ON TABLE public.roadmap_edges IS
    'Conexiones entre nodos del roadmap (ramas del árbol).';

CREATE INDEX idx_roadmap_edges_user_id ON public.roadmap_edges (user_id);
CREATE INDEX idx_roadmap_edges_source ON public.roadmap_edges (source_node_id);
CREATE INDEX idx_roadmap_edges_target ON public.roadmap_edges (target_node_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- roadmap_suggestions
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE public.roadmap_suggestions (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id  uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    suggester_id    uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    game_id         integer     NOT NULL REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    note            text,
    after_node_id   uuid        REFERENCES public.roadmap_nodes(id) ON DELETE SET NULL,
    status          text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'accepted', 'dismissed')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (target_user_id <> suggester_id)
);

COMMENT ON TABLE public.roadmap_suggestions IS
    'Sugerencias de juegos entre amigos para el roadmap.';

CREATE INDEX idx_roadmap_suggestions_target
    ON public.roadmap_suggestions (target_user_id, status);

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at trigger for roadmap_nodes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_roadmap_nodes_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_roadmap_nodes_updated_at
    BEFORE UPDATE ON public.roadmap_nodes
    FOR EACH ROW
    EXECUTE FUNCTION public.set_roadmap_nodes_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-sync roadmap_nodes.status from user_games.status
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_roadmap_from_user_games()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN
        IF NEW.status = 'playing' THEN
            UPDATE public.roadmap_nodes
            SET status = 'playing'
            WHERE user_id = NEW.user_id
              AND game_id = NEW.game_id
              AND status IN ('up_next', 'playing');
        ELSIF NEW.status IN ('beaten', 'completed') THEN
            UPDATE public.roadmap_nodes
            SET status = 'completed'
            WHERE user_id = NEW.user_id
              AND game_id = NEW.game_id
              AND status IN ('up_next', 'playing', 'completed');
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_roadmap_from_user_games
    AFTER INSERT OR UPDATE OF status ON public.user_games
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_roadmap_from_user_games();

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.roadmap_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmap_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmap_suggestions ENABLE ROW LEVEL SECURITY;

-- roadmap_nodes: owner only
CREATE POLICY "Users manage own roadmap nodes"
    ON public.roadmap_nodes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- roadmap_edges: owner only
CREATE POLICY "Users manage own roadmap edges"
    ON public.roadmap_edges FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- roadmap_suggestions: read if involved
CREATE POLICY "Users view roadmap suggestions they are part of"
    ON public.roadmap_suggestions FOR SELECT
    USING (auth.uid() = target_user_id OR auth.uid() = suggester_id);

-- roadmap_suggestions: insert if suggester and friends
CREATE POLICY "Friends can suggest roadmap games"
    ON public.roadmap_suggestions FOR INSERT
    WITH CHECK (
        auth.uid() = suggester_id
        AND suggester_id <> target_user_id
        AND EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE f.status = 'accepted'
              AND (
                  (f.requester_id = suggester_id AND f.addressee_id = target_user_id)
                  OR (f.requester_id = target_user_id AND f.addressee_id = suggester_id)
              )
        )
    );

-- roadmap_suggestions: target can update (accept/dismiss)
CREATE POLICY "Target user can respond to roadmap suggestions"
    ON public.roadmap_suggestions FOR UPDATE
    USING (auth.uid() = target_user_id)
    WITH CHECK (auth.uid() = target_user_id);
