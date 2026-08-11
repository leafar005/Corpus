// supabase/functions/igdb-proxy/index.ts
import { corsHeaders, handleCorsPreflight } from '../_shared/cors.ts';
import { igdbApiRequest } from '../_shared/igdb-client.ts';
import { checkRateLimit, bucketKeyFromRequest } from '../_shared/rate-limit.ts';

// Allowlist de endpoints válidos de la API v4 de IGDB para prevenir uso no autorizado
const ALLOWED_ENDPOINTS = new Set([
  'games',
  'external_games',
  'game_time_to_beats',
  'genres',
  'platforms',
  'themes',
  'game_modes',
  'player_perspectives',
  'collections',
  'franchises',
  'involved_companies',
]);

// Rate limit: 60 peticiones por minuto por caller. Ajustable si en producción
// se ve que genera falsos positivos con uso normal (revisa los logs WARN
// "Rate limit excedido" antes de subirlo a ciegas).
const RATE_LIMIT_MAX_REQUESTS = 60;
const RATE_LIMIT_WINDOW_SECONDS = 60;

const log = (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, any> = {}) => {
  console.log(JSON.stringify({ timestamp: new Date().toISOString(), level, message, ...meta }));
};

Deno.serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405,
      });
    }

    // --- Rate limiting ---
    const bucketKey = await bucketKeyFromRequest(req);
    const rateLimit = await checkRateLimit({
      bucketKey,
      maxRequests: RATE_LIMIT_MAX_REQUESTS,
      windowSeconds: RATE_LIMIT_WINDOW_SECONDS,
    });

    if (!rateLimit.allowed) {
      log('WARN', 'Rate limit excedido', { bucketKey });
      return new Response(JSON.stringify({ error: 'Too many requests, please slow down' }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Retry-After': String(RATE_LIMIT_WINDOW_SECONDS),
        },
        status: 429,
      });
    }

    const body = await req.json();
    const endpoint = typeof body?.endpoint === 'string' ? body.endpoint.trim() : '';
    const query = typeof body?.query === 'string' ? body.query : '';

    if (!endpoint || !ALLOWED_ENDPOINTS.has(endpoint)) {
      log('WARN', 'Intento de consulta a endpoint no permitido', { endpoint });
      return new Response(JSON.stringify({ error: `Endpoint '${endpoint}' is not allowed` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    log('INFO', 'Reenviando consulta a IGDB', { endpoint, queryLength: query.length });

    const result = await igdbApiRequest(endpoint, query);

    if (!result.ok) {
      return new Response(result.error, {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: result.status,
      });
    }

    log('INFO', 'Consulta a IGDB completada con éxito', { endpoint, status: result.status });

    return new Response(JSON.stringify(result.data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
      status: 200,
    });
  } catch (error: any) {
    log('ERROR', 'Excepción no controlada en igdb-proxy', { error: error?.message || String(error) });
    return new Response(JSON.stringify({ error: error?.message || 'Internal Server Error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
