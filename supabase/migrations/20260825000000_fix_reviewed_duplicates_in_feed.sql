-- =============================================================================
-- Fix: eliminar entradas 'reviewed' duplicadas del activity_feed
-- =============================================================================
--
-- CONTEXTO
-- --------
-- La app solía mostrar un icono/texto "reseñado" para entradas con
-- action_type='reviewed'. Tras el fix en el cliente (25 Aug 2026), estas
-- entradas ahora muestran el estado real del juego (completado, jugando…).
--
-- El problema pendiente en BD: cuando existe TANTO una entrada 'reviewed'
-- como una 'status_change' para el mismo user_id + game_id, el feed muestra
-- DOS posts con el mismo texto (ej. "ha completado X" dos veces).
--
-- SOLUCIÓN
-- --------
-- Para cada par (user_id, game_id) que tenga al menos un 'status_change',
-- eliminamos la entrada 'reviewed'. La información de la reseña (rating,
-- comment, etc.) sigue accesible a través de la tabla reviews — el cliente
-- la carga vía status_change.review_id que el trigger ya inyecta.
--
-- Las entradas 'reviewed' SIN ningún 'status_change' correspondiente
-- se conservan intactas (el cliente las muestra correctamente).
--
-- SEGURIDAD
-- ---------
-- Solo afecta a 'reviewed'. No toca 'status_change' ni 'achievement'.
-- La columna review_id de la entrada 'status_change' superviviente ya
-- apunta a la review correcta gracias a on_user_game_status_change().
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. DIAGNÓSTICO (comentado — ejecutar manualmente para ver el impacto antes)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- SELECT
--   af_r.id          AS reviewed_id,
--   af_r.user_id,
--   af_r.game_id,
--   af_r.created_at  AS reviewed_at,
--   af_s.id          AS status_change_id,
--   af_s.metadata->>'status' AS status,
--   af_s.created_at  AS status_change_at
-- FROM public.activity_feed af_r
-- JOIN public.activity_feed af_s
--   ON  af_s.user_id    = af_r.user_id
--   AND af_s.game_id    = af_r.game_id
--   AND af_s.action_type = 'status_change'
-- WHERE af_r.action_type = 'reviewed'
-- ORDER BY af_r.user_id, af_r.game_id, af_r.created_at DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. LIMPIEZA: borrar entradas 'reviewed' con un 'status_change' del mismo
--    user_id + game_id.
-- ─────────────────────────────────────────────────────────────────────────────

DELETE FROM public.activity_feed af_reviewed
WHERE af_reviewed.action_type = 'reviewed'
  AND EXISTS (
    SELECT 1
    FROM public.activity_feed af_status
    WHERE af_status.user_id     = af_reviewed.user_id
      AND af_status.game_id     = af_reviewed.game_id
      AND af_status.action_type = 'status_change'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. ASEGURAR que las entradas 'reviewed' supervivientes (standalone) tienen
--    la review_id apuntando a la review correcta.
--    Esto permite que el cliente cargue review['status'] sin ambigüedad.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.activity_feed af
SET review_id = r.id
FROM public.reviews r
WHERE af.action_type = 'reviewed'
  AND af.review_id IS NULL
  AND r.user_id = af.user_id
  AND r.game_id = af.game_id
  -- En caso de múltiples reseñas para el mismo juego, cogemos la más reciente
  AND r.id = (
    SELECT id FROM public.reviews
    WHERE user_id = af.user_id
      AND game_id = af.game_id
    ORDER BY created_at DESC
    LIMIT 1
  );
