-- =====================================================================
-- FIX SUPABASE LINT ERROR: SECURITY DEFINER en vista v_friend_pairs
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- =====================================================================

-- Opción 1 (Postgres 15+ / Supabase moderno - Recomendada y más segura):
-- Cambia la propiedad de la vista existente a security_invoker = true
ALTER VIEW public.v_friend_pairs SET (security_invoker = true);

-- Opción 2 (Si prefieres recrear la vista explícitamente con security_invoker = true):
CREATE OR REPLACE VIEW public.v_friend_pairs
WITH (security_invoker = true)
AS
  SELECT requester_id AS user_id, addressee_id AS friend_id
  FROM public.friendships WHERE status = 'accepted'
  UNION ALL
  SELECT addressee_id AS user_id, requester_id AS friend_id
  FROM public.friendships WHERE status = 'accepted';

COMMENT ON VIEW public.v_friend_pairs IS
  'Vista simétrica de amistades aceptadas (con security_invoker = true para heredar RLS de friendships).';
