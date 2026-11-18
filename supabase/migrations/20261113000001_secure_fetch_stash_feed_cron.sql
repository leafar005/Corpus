-- Reprograma el cron job 'fetch-stash-feed-every-4-hours' para autenticarse
-- mediante 'x-cron-secret' desde Supabase Vault (reemplaza el header
-- Authorization con la publishable key introducido en
-- 20260728000001_production_sync.sql).
-- Mismo patrón que 20260831000000_fix_sync_bundles_cron.sql.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'fetch-stash-feed-every-4-hours'
  ) THEN
    PERFORM cron.unschedule('fetch-stash-feed-every-4-hours');
  END IF;
END;
$$;

SELECT cron.schedule(
  'fetch-stash-feed-every-4-hours',
  '0 */4 * * *',
  $$
  SELECT net.http_post(
      url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/fetch-stash-feed',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', coalesce((select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret'), '')
      ),
      body:='{}'::jsonb
  ) as request_id;
  $$
);
