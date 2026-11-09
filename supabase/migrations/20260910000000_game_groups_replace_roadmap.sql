-- =============================================================================
-- Reemplaza roadmap (DAG) por grupos de juegos simples (listas ordenadas).
-- =============================================================================

-- ── Eliminar triggers y funciones del roadmap ────────────────────────────────

DROP TRIGGER IF EXISTS trg_sync_roadmap_from_user_games ON public.user_games;
DROP FUNCTION IF EXISTS public.sync_roadmap_from_user_games();

-- ── Eliminar tablas roadmap (orden por FKs) ──────────────────────────────────

DROP TABLE IF EXISTS public.roadmap_suggestions;
DROP TABLE IF EXISTS public.roadmap_edges;
DROP TABLE IF EXISTS public.roadmap_nodes CASCADE;
DROP FUNCTION IF EXISTS public.set_roadmap_nodes_updated_at();

-- ── game_groups ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.game_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  cover_game_id integer REFERENCES public.games(igdb_id) ON DELETE SET NULL,
  sort_order smallint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.game_groups IS
  'Grupos personalizados de juegos (sagas, backlogs, listas de planificación).';

CREATE INDEX IF NOT EXISTS idx_game_groups_user_id ON public.game_groups (user_id);
CREATE INDEX IF NOT EXISTS idx_game_groups_user_sort ON public.game_groups (user_id, sort_order);

-- ── game_group_items ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.game_group_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES public.game_groups(id) ON DELETE CASCADE,
  game_id integer NOT NULL REFERENCES public.games(igdb_id) ON DELETE CASCADE,
  sort_order smallint NOT NULL DEFAULT 0,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, game_id)
);

COMMENT ON TABLE public.game_group_items IS
  'Juegos dentro de un grupo, en orden definido por el usuario.';

CREATE INDEX IF NOT EXISTS idx_game_group_items_group ON public.game_group_items (group_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_game_group_items_game ON public.game_group_items (game_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.game_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_group_items ENABLE ROW LEVEL SECURITY;

-- Grupos: lectura pública (perfiles), escritura solo dueño
DROP POLICY IF EXISTS "Anyone can view game groups" ON public.game_groups;
CREATE POLICY "Anyone can view game groups"
  ON public.game_groups FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users manage own game groups" ON public.game_groups;
CREATE POLICY "Users manage own game groups"
  ON public.game_groups FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own game groups" ON public.game_groups;
CREATE POLICY "Users update own game groups"
  ON public.game_groups FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own game groups" ON public.game_groups;
CREATE POLICY "Users delete own game groups"
  ON public.game_groups FOR DELETE
  USING (auth.uid() = user_id);

-- Items: lectura pública, escritura si el grupo es del usuario
DROP POLICY IF EXISTS "Anyone can view game group items" ON public.game_group_items;
CREATE POLICY "Anyone can view game group items"
  ON public.game_group_items FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users insert items in own groups" ON public.game_group_items;
CREATE POLICY "Users insert items in own groups"
  ON public.game_group_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.game_groups g
      WHERE g.id = group_id AND g.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users update items in own groups" ON public.game_group_items;
CREATE POLICY "Users update items in own groups"
  ON public.game_group_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.game_groups g
      WHERE g.id = group_id AND g.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.game_groups g
      WHERE g.id = group_id AND g.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users delete items in own groups" ON public.game_group_items;
CREATE POLICY "Users delete items in own groups"
  ON public.game_group_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.game_groups g
      WHERE g.id = group_id AND g.user_id = auth.uid()
    )
  );
