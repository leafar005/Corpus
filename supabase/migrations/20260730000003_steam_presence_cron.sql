-- Create the cron job to poll Steam presence every 1 minute
-- Note: The vault secret 'cron_secret' must be created manually in the target environment:
-- select vault.create_secret('YOUR_SECRET_HERE', 'cron_secret');

-- Deschedule if it exists
SELECT cron.unschedule('steam-presence-poll-job');

-- Schedule the job
SELECT cron.schedule(
  'steam-presence-poll-job',
  '* * * * *',
  $$
    select net.http_post(
        url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/steam-presence-poll',
        headers:=jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', coalesce((select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret'), '')
        )
    );
  $$
);
