-- Instrucciones: Ejecuta esto en el SQL Editor de Supabase.
-- REEMPLAZA [TU_ANON_KEY_AQUI] por tu anon_key de Supabase (Settings -> API)
-- REEMPLAZA [TU_PROJECT_REF] por el ID de tu proyecto (está en la URL, ej: rhcgjiwmlqswlideqzid)

select cron.schedule(
  'fetch-stash-feed-every-4-hours',
  '0 */4 * * *',
  $$
    select net.http_post(
        url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/fetch-stash-feed',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_IaEQtKAtjt7Wqpy7WywRog_a83R4u8m"}'::jsonb,
        body:='{}'::jsonb
    ) as request_id;
  $$
);
