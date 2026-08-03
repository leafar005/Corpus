-- ─────────────────────────────────────────────────────────────────────────────
-- Añadir notificación de wishlist + soporte de tokens web
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Añadir columna friend_wishlisted_game a notification_preferences
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS friend_wishlisted_game boolean DEFAULT true NOT NULL;

-- 2. Ampliar el CHECK de push_tokens para aceptar plataforma 'web'
ALTER TABLE public.push_tokens
  DROP CONSTRAINT IF EXISTS push_tokens_platform_check;

ALTER TABLE public.push_tokens
  ADD CONSTRAINT push_tokens_platform_check
  CHECK (platform IN ('android', 'windows', 'web'));
