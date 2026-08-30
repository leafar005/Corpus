-- =============================================================================
-- Badge de actividad: el estado de "leído" pasa de SharedPreferences (local,
-- por dispositivo) a una columna en public.users (compartida entre todos los
-- dispositivos/plataformas de la misma cuenta). Esto es lo que permite que
-- marcar como leído en escritorio se refleje también en móvil y viceversa.
-- =============================================================================

ALTER TABLE public.users
  ADD COLUMN last_activity_read_at timestamptz NOT NULL DEFAULT now();

-- Backfill: los usuarios ya existentes arrancan "al día" en el momento del
-- despliegue. Sin esto, todo el mundo vería de golpe un badge con toda la
-- actividad de los últimos ~3 días (el fallback que usaba antes el cliente)
-- la primera vez que abran la app tras esta migración.
UPDATE public.users SET last_activity_read_at = now();

COMMENT ON COLUMN public.users.last_activity_read_at IS
  'Marca de tiempo (hora de servidor) hasta la que el usuario ha leído su '
  'feed de actividad. Sustituye a la antigua clave local last_activity_visit '
  'de SharedPreferences, que era por dispositivo y no sincronizaba entre '
  'plataformas. Se actualiza vía la función mark_activity_read().';

-- ─────────────────────────────────────────────────────────────────────────
-- mark_activity_read()
-- Marca "leído hasta ahora mismo" usando la hora del SERVIDOR (evita que un
-- reloj de dispositivo desincronizado deje el badge roto).
-- SECURITY INVOKER: se ejecuta con los permisos del usuario que llama, y
-- solo puede tocar su propia fila gracias a la policy "Users can update own
-- profile" ya existente sobre public.users (auth.uid() = id).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_activity_read()
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
  UPDATE public.users
  SET last_activity_read_at = now()
  WHERE id = auth.uid();
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- get_unread_activity_summary()
-- Calcula el nº de actividades no leídas en el SERVIDOR, usando la misma
-- columna que mark_activity_read() actualiza. Sustituye por completo a la
-- query ad-hoc que hoy vive en _fetchInitialBadges() (main_screen.dart).
--
-- Devuelve SIEMPRE exactamente 1 fila (incluso si el usuario no tiene fila
-- en public.users todavía, o no hay actividad nueva), para que el cliente
-- pueda usar `.single()` sin manejar el caso de "0 filas".
--
-- Respeta la RLS existente sobre activity_feed ("Users can view their own
-- and friends activity"): solo cuenta actividad de amigos aceptados, igual
-- que hace hoy ActivityScreen al listar el feed.
--
-- Agrupa por (user_id, game_id) distinto, igual que el cálculo actual en
-- el cliente, para no inflar el contador cuando un mismo amigo genera
-- varias entradas seguidas sobre el mismo juego.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_unread_activity_summary()
RETURNS TABLE (unread_count integer, last_read_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_since timestamptz;
  v_count integer;
BEGIN
  SELECT u.last_activity_read_at INTO v_since
  FROM public.users u
  WHERE u.id = auth.uid();

  IF v_since IS NULL THEN
    -- auth.uid() es null (invitado) o no existe fila en public.users todavía.
    RETURN QUERY SELECT 0, now();
    RETURN;
  END IF;

  SELECT COUNT(
    DISTINCT COALESCE(af.user_id::text || ':' || af.game_id::text, af.id::text)
  )
  INTO v_count
  FROM public.activity_feed af
  WHERE af.user_id <> auth.uid()
    AND af.created_at > v_since;

  RETURN QUERY SELECT COALESCE(v_count, 0), v_since;
END;
$$;
