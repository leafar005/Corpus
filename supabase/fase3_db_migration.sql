-- =====================================================================
-- CORPUS: FASE 3 - BASE DE DATOS
-- Mejoras: vista v_friend_pairs, RLS en games, columnas zombie
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- Seguro de ejecutar varias veces (todos los pasos son idempotentes)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. VISTA v_friend_pairs
--    Objetivo: colapsar las 2 queries de friendships (sent + received)
--    en 1 sola query simetrica. Antes:
--      SELECT addressee_id FROM friendships WHERE requester_id = $me AND status = 'accepted'
--      SELECT requester_id FROM friendships WHERE addressee_id  = $me AND status = 'accepted'
--    Despues:
--      SELECT friend_id FROM v_friend_pairs WHERE user_id = $me
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_friend_pairs AS
  SELECT requester_id AS user_id, addressee_id AS friend_id
  FROM public.friendships WHERE status = 'accepted'
  UNION ALL
  SELECT addressee_id AS user_id, requester_id AS friend_id
  FROM public.friendships WHERE status = 'accepted';

COMMENT ON VIEW public.v_friend_pairs IS
  'Vista simetrica de amistades aceptadas. Para cada par (A,B) genera '
  'dos filas: (A->B) y (B->A). Usala para obtener todos los amigos de un '
  'usuario con una sola query: SELECT friend_id FROM v_friend_pairs WHERE user_id = $1';

CREATE INDEX IF NOT EXISTS idx_friendships_req_status
  ON public.friendships(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_addr_status
  ON public.friendships(addressee_id, status);


-- ---------------------------------------------------------------------
-- 2. RLS RESTRICTIVA EN games
--    Prohibicion explicita de UPDATE/DELETE para usuarios normales.
-- ---------------------------------------------------------------------

DROP POLICY IF EXISTS "No user UPDATE on games" ON public.games;
CREATE POLICY "No user UPDATE on games"
  ON public.games FOR UPDATE USING (false);

DROP POLICY IF EXISTS "No user DELETE on games" ON public.games;
CREATE POLICY "No user DELETE on games"
  ON public.games FOR DELETE USING (false);

COMMENT ON TABLE public.games IS
  'Catalogo de juegos (solo lectura para usuarios). '
  'INSERT permitido para autenticados. '
  'UPDATE/DELETE solo por service_role o funciones SECURITY DEFINER.';


-- ---------------------------------------------------------------------
-- 3. ELIMINAR COLUMNAS ZOMBIE
--    review_likes   : review_user_id, review_game_id (reemplazadas por review_id)
--    review_comments: review_user_id, review_game_id (reemplazadas por review_id)
--
--    VERIFICAR ANTES DE EJECUTAR:
--      SELECT COUNT(*) FROM review_likes    WHERE review_id IS NULL;
--      SELECT COUNT(*) FROM review_comments WHERE review_id IS NULL;
--    Ambas deben devolver 0.
-- ---------------------------------------------------------------------

-- 3b. Eliminar FK compuesta antigua de review_likes -> user_games
DO $$
DECLARE fk_name TEXT;
BEGIN
  SELECT conname INTO fk_name
  FROM pg_constraint
  WHERE conrelid = 'public.review_likes'::regclass
    AND confrelid = 'public.user_games'::regclass
    AND contype   = 'f';
  IF fk_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.review_likes DROP CONSTRAINT ' || quote_ident(fk_name);
    RAISE NOTICE 'FK % eliminada de review_likes', fk_name;
  ELSE
    RAISE NOTICE 'FK review_likes->user_games ya no existe';
  END IF;
END;
$$;

-- 3c. Eliminar FK compuesta antigua de review_comments -> user_games
DO $$
DECLARE fk_name TEXT;
BEGIN
  SELECT conname INTO fk_name
  FROM pg_constraint
  WHERE conrelid = 'public.review_comments'::regclass
    AND confrelid = 'public.user_games'::regclass
    AND contype   = 'f';
  IF fk_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.review_comments DROP CONSTRAINT ' || quote_ident(fk_name);
    RAISE NOTICE 'FK % eliminada de review_comments', fk_name;
  ELSE
    RAISE NOTICE 'FK review_comments->user_games ya no existe';
  END IF;
END;
$$;

-- 3d. Eliminar columnas zombie de review_likes
ALTER TABLE public.review_likes
  DROP COLUMN IF EXISTS review_user_id,
  DROP COLUMN IF EXISTS review_game_id;

-- 3e. Eliminar columnas zombie de review_comments
ALTER TABLE public.review_comments
  DROP COLUMN IF EXISTS review_user_id,
  DROP COLUMN IF EXISTS review_game_id;


-- ---------------------------------------------------------------------
-- 4. ACTUALIZAR PRIMARY KEY de review_likes
--    El PK original era (user_id, review_user_id, review_game_id).
--    Tras eliminar columnas zombie -> nuevo PK: (user_id, review_id)
-- ---------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.review_likes'::regclass AND contype = 'p'
  ) THEN
    ALTER TABLE public.review_likes DROP CONSTRAINT IF EXISTS review_likes_pkey;
  END IF;
END;
$$;

ALTER TABLE public.review_likes
  ADD CONSTRAINT review_likes_pkey PRIMARY KEY (user_id, review_id);


-- ---------------------------------------------------------------------
-- 5. VERIFICACION FINAL (queries opcionales para comprobar)
-- ---------------------------------------------------------------------

-- Vista existe:
-- SELECT * FROM public.v_friend_pairs LIMIT 5;

-- Columnas zombie eliminadas (debe devolver 0 filas):
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   IN ('review_likes', 'review_comments')
--   AND column_name  IN ('review_user_id', 'review_game_id');

-- Politicas de games:
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'games';
