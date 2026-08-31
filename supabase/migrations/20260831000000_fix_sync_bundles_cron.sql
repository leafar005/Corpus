-- Reemplaza el cron job de sync-bundles-cron original
-- (20260728000001_production_sync.sql), que dejó el placeholder
-- "TU_SERVICE_ROLE_KEY" sin sustituir en el Authorization header. Se alinea
-- con el mismo patrón de Vault que ya usa steam-presence-poll-job.

SELECT cron.unschedule('sync-bundles-cron');

SELECT cron.schedule(
  'sync-bundles-cron',
  '0 * * * *',
  $$
  SELECT net.http_post(
      url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/sync-bundles',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', coalesce((select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret'), '')
      ),
      body:='{}'::jsonb
  ) as request_id;
  $$
);
