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
 * Genera una bucket key resistente a rotación de cabeceras falsas (SEC-06):
 * 1. Si la petición incluye un Bearer JWT de un usuario real verificado por
 *    Supabase Auth (`auth.getUser`), usa `user:<user.id>` para que distintos
 *    usuarios detrás de una misma IP pública (ej. Wi-Fi compartida) tengan su
 *    propio cupo.
 * 2. En caso contrario (modo invitado con anon/publishable key, o un atacante
 *    enviando tokens Bearer aleatorios inválidos), agrupa por la IP real del
 *    cliente (`cf-connecting-ip` / `x-forwarded-for`), impidiendo evadir el
 *    rate limit rotando cabeceras `Authorization` arbitrarias.
 */
export async function bucketKeyFromRequest(req: Request): Promise<string> {
  const clientIp =
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    'unknown-ip';

  const authHeader = req.headers.get('Authorization') ?? '';
  if (authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    // Solo intentamos verificar si parece un JWT (3 segmentos) y no es la anon key
    if (token && token !== anonKey && token.split('.').length === 3) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
      if (supabaseUrl && serviceRoleKey) {
        try {
          const supabase = createClient(supabaseUrl, serviceRoleKey);
          const { data: { user }, error } = await supabase.auth.getUser(token);
          if (!error && user?.id) {
            return await sha256Hex(`user:${user.id}`);
          }
        } catch {
          // Fallback a IP del cliente
        }
      }
    }
  }

  return await sha256Hex(`ip:${clientIp}`);
}

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
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
