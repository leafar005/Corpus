-- 1. Crear tabla principal para bundles procesados
CREATE TABLE IF NOT EXISTS public.active_bundles (
  id text NOT NULL PRIMARY KEY,
  title text NOT NULL,
  store_name text NOT NULL,
  url text NOT NULL,
  end_date timestamp with time zone,
  tiers jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Habilitar Row Level Security (RLS) con lectura pública
ALTER TABLE public.active_bundles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on active_bundles" 
ON public.active_bundles 
FOR SELECT 
USING (true);

-- 3. Función y trigger para mantener el campo updated_at al día
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_active_bundles_modtime ON public.active_bundles;
CREATE TRIGGER update_active_bundles_modtime
    BEFORE UPDATE ON public.active_bundles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 4. Programar la ejecución de la Edge Function cada 4 horas
-- (Reemplaza TU_SERVICE_ROLE_KEY con tu clave secreta service_role)
SELECT cron.schedule(
  'sync-bundles-cron',
  '0 */4 * * *', -- Cada 4 horas en punto
  $$
  SELECT net.http_post(
      url:='https://rhcgjiwmlqswlideqzid.supabase.co/functions/v1/sync-bundles',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer TU_SERVICE_ROLE_KEY"}'::jsonb,
      body:='{}'::jsonb
  ) as request_id;
  $$
);

-- 5. Programar una tarea de limpieza diaria para purgar bundles caducados
SELECT cron.schedule(
  'purge-expired-bundles',
  '0 3 * * *', -- Todos los días a las 03:00 UTC
  $$
  DELETE FROM public.active_bundles WHERE end_date < now();
  $$
);
