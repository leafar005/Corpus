// supabase/functions/_shared/rate-limit.ts
//
// Rate limiting por bucket, respaldado por Postgres. Requiere la migración
// que crea `public.igdb_proxy_rate_limits` y `public.check_igdb_rate_limit`
// (ver sección 4 de esta especificación).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface RateLimitOptions {
  bucketKey: string;
  maxRequests: number;
  windowSeconds: number;
}

export interface RateLimitResult {
  allowed: boolean;
  /** true si el check falló (ej. problema de BD) y se dejó pasar por defecto */
  failedOpen: boolean;
}

/**
 * Genera una bucket key estable a partir de la cabecera Authorization (o
 * apikey como fallback) de la petición. Se usa el hash SHA-256 del token
 * crudo, sin decodificar/confiar en el JWT — así el resultado es seguro
 * independientemente de la configuración de verify_jwt a nivel de gateway.
 */
export async function bucketKeyFromRequest(req: Request): Promise<string> {
  const raw = req.headers.get('Authorization') ?? req.headers.get('apikey') ?? 'anonymous';
  const bytes = new TextEncoder().encode(raw);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Comprueba (y consume) el rate limit para un bucket dado, vía la función
 * SQL `check_igdb_rate_limit`. Falla ABIERTO deliberadamente: si el propio
 * chequeo falla por un problema de infraestructura, se permite la petición
 * en vez de tumbar IGDB por un fallo del rate limiter en sí. Esto es una
 * decisión de "protección de coste/abuso", no de seguridad crítica — si en
 * algún momento prefieres fail-closed, cambia `allowed: true` por `false`
 * en los dos catch/error de abajo.
 */
export async function checkRateLimit(opts: RateLimitOptions): Promise<RateLimitResult> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    console.log(JSON.stringify({
      level: 'ERROR',
      service: 'rate-limit',
      message: 'Faltan SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY, rate limiter deshabilitado (fail-open)',
    }));
    return { allowed: true, failedOpen: true };
  }

  const client = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await client.rpc('check_igdb_rate_limit', {
    p_bucket_key: opts.bucketKey,
    p_max_requests: opts.maxRequests,
    p_window_seconds: opts.windowSeconds,
  });

  if (error) {
    console.log(JSON.stringify({
      level: 'ERROR',
      service: 'rate-limit',
      message: 'Fallo al comprobar el rate limit, se permite la petición (fail-open)',
      error: error.message,
    }));
    return { allowed: true, failedOpen: true };
  }

  return { allowed: data === true, failedOpen: false };
}
