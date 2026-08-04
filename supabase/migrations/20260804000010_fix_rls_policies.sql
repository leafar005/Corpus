-- =============================================================================
-- Migración: Limpiar políticas RLS ambiguas en games y stash_community_reviews
-- =============================================================================
-- Problema 1: "Allow all for authenticated" en games tiene USING(true) WITH CHECK(true),
--   lo que permite cualquier operación a usuarios autenticados. Coexiste con políticas
--   "No user UPDATE" y "No user DELETE" que bloquean con USING(false). Confuso y redundante.
--   La política de INSERT existente ("Users can insert games") ya cubre la necesidad real.
--
-- Problema 2: "Anyone can insert stash community reviews" permite que cualquier cliente
--   (incluso anónimo) inserte en stash_community_reviews. Solo los edge functions
--   con service_role deberían poder escribir en esta tabla.
-- =============================================================================

-- ── games: eliminar política catch-all ambigua ─────────────────────────────
DO $$
BEGIN
  -- Solo eliminar si existe (idempotente)
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'games'
      AND policyname = 'Allow all for authenticated'
  ) THEN
    DROP POLICY "Allow all for authenticated" ON public.games;
    RAISE NOTICE 'Política "Allow all for authenticated" eliminada de games.';
  ELSE
    RAISE NOTICE 'Política "Allow all for authenticated" no existe en games — OK.';
  END IF;

  -- También eliminamos las políticas "No user X" que son innecesarias
  -- (si no hay política de UPDATE/DELETE, esas operaciones ya están denegadas por defecto)
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'games'
      AND policyname = 'No user DELETE on games'
  ) THEN
    DROP POLICY "No user DELETE on games" ON public.games;
    RAISE NOTICE 'Política "No user DELETE on games" eliminada (innecesaria).';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'games'
      AND policyname = 'No user UPDATE on games'
  ) THEN
    DROP POLICY "No user UPDATE on games" ON public.games;
    RAISE NOTICE 'Política "No user UPDATE on games" eliminada (innecesaria).';
  END IF;
END $$;

-- Estado final deseado en games:
--   SELECT → "Anyone can view games"           USING (true)
--   INSERT → "Users can insert games"          WITH CHECK (auth.role() = 'authenticated')
--   UPDATE → sin política → denegado por defecto
--   DELETE → sin política → denegado por defecto

-- ── stash_community_reviews: restringir INSERT a service_role ─────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'stash_community_reviews'
      AND policyname = 'Anyone can insert stash community reviews'
  ) THEN
    DROP POLICY "Anyone can insert stash community reviews" ON public.stash_community_reviews;
    RAISE NOTICE 'Política permisiva de INSERT en stash_community_reviews eliminada.';
  END IF;
END $$;

-- Solo service_role (Edge Functions) puede insertar reseñas de Stash.
-- Los usuarios normales solo pueden leer (cubierto por "Anyone can view stash community reviews").
CREATE POLICY "Service role inserts stash community reviews"
  ON public.stash_community_reviews
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- ── stash_sync_metadata: lo mismo ─────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'stash_sync_metadata'
      AND policyname = 'Anyone can insert stash sync metadata'
  ) THEN
    DROP POLICY "Anyone can insert stash sync metadata" ON public.stash_sync_metadata;
    RAISE NOTICE 'Política permisiva de INSERT/UPDATE en stash_sync_metadata eliminada.';
  END IF;
END $$;

CREATE POLICY "Service role manages stash sync metadata"
  ON public.stash_sync_metadata
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
