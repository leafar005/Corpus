-- ─────────────────────────────────────────────────────────────────────────────
-- Cron job: notificar bundles que expiran en ~24h
-- Se ejecuta diariamente a las 10:00 UTC
-- ─────────────────────────────────────────────────────────────────────────────

SELECT cron.schedule(
  'notify-bundle-expiring-daily',    -- nombre del job (único)
  '0 10 * * *',                       -- cada día a las 10:00 UTC
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/notify-bundle-expiring',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body := '{}'::jsonb
    )
  $$
);
