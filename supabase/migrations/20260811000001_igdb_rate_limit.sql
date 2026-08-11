-- Fase 4 (Backend consolidation): rate limiting para igdb-proxy.
-- Tabla de contadores por bucket + ventana deslizante, y una función RPC
-- atómica para comprobar/incrementar en una sola sentencia (evita race
-- conditions entre isolates concurrentes de Deno).

create table if not exists public.igdb_proxy_rate_limits (
  bucket_key text primary key,
  window_start timestamptz not null default now(),
  request_count integer not null default 0
);

comment on table public.igdb_proxy_rate_limits is
  'Contadores de rate limiting para igdb-proxy, por bucket (hash del token del caller).';

create or replace function public.check_igdb_rate_limit(
  p_bucket_key text,
  p_max_requests integer,
  p_window_seconds integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_count integer;
begin
  insert into public.igdb_proxy_rate_limits (bucket_key, window_start, request_count)
  values (p_bucket_key, v_now, 1)
  on conflict (bucket_key) do update
    set
      request_count = case
        when public.igdb_proxy_rate_limits.window_start < v_now - make_interval(secs => p_window_seconds)
          then 1
        else public.igdb_proxy_rate_limits.request_count + 1
      end,
      window_start = case
        when public.igdb_proxy_rate_limits.window_start < v_now - make_interval(secs => p_window_seconds)
          then v_now
        else public.igdb_proxy_rate_limits.window_start
      end
  returning request_count into v_count;

  return v_count <= p_max_requests;
end;
$$;

grant execute on function public.check_igdb_rate_limit(text, integer, integer) to service_role;

-- RLS activado; nadie tiene policies de lectura/escritura directa sobre la
-- tabla — solo se toca a través de la función SECURITY DEFINER de arriba.
alter table public.igdb_proxy_rate_limits enable row level security;
