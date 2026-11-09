// supabase/functions/_shared/cors.ts
//
// CORS centralizado. Restringe Access-Control-Allow-Origin a los dominios
// de producción y desarrollo de Corpus en lugar de usar '*'.
// (Auditoría H-01)

// ── Orígenes permitidos ─────────────────────────────────────────────────────
// Añade aquí nuevos dominios si se necesitan (staging, preview de Vercel, etc.)
const ALLOWED_ORIGINS: string[] = [
  'https://corpus-games.vercel.app', // producción (Vercel)
  'http://localhost:3000',           // desarrollo local web
  'http://localhost:5000',           // desarrollo local web (alt)
  'http://localhost:8080',           // desarrollo local web (alt)
];

function isAllowedOrigin(origin: string): boolean {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.includes(origin)) return true;
  // Permitir cualquier puerto efímero de desarrollo local (ej. flutter run -d edge/chrome)
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) return true;
  // Permitir despliegues preview de Vercel del proyecto Corpus
  if (/^https:\/\/corpus(-[a-z0-9-]+)?\.vercel\.app$/i.test(origin)) return true;
  return false;
}

/**
 * Devuelve las cabeceras CORS apropiadas para la petición dada.
 *
 * Si el Origin de la petición está en la allowlist, se refleja en la
 * respuesta (patrón "reflect origin"). Si no coincide, se devuelve el
 * dominio de producción como fallback — los navegadores rechazarán la
 * respuesta si el origen del caller no coincide, bloqueando el acceso.
 *
 * Las Edge Functions invocadas servidor-a-servidor (triggers, cron) no
 * envían cabecera Origin, así que esto no les afecta.
 */
export function corsHeadersForRequest(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin') ?? '';
  const allowed = isAllowedOrigin(origin);
  return {
    'Access-Control-Allow-Origin': allowed ? origin : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Vary': 'Origin',
  };
}

/**
 * Cabeceras CORS estáticas para contextos donde no se tiene acceso al
 * Request (ej. respuestas de error genéricas). Usa el dominio de producción.
 * Preferir `corsHeadersForRequest(req)` siempre que sea posible.
 */
export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS[0],
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

/**
 * Responde a las peticiones CORS preflight (OPTIONS).
 * Devuelve la Response si la petición es OPTIONS, o null si no lo es
 * (en cuyo caso el caller debe seguir procesando la petición real).
 */
export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeadersForRequest(req) });
  }
  return null;
}
