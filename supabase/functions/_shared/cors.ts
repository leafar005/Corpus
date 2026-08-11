// supabase/functions/_shared/cors.ts

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/**
 * Responde a las peticiones CORS preflight (OPTIONS).
 * Devuelve la Response si la petición es OPTIONS, o null si no lo es
 * (en cuyo caso el caller debe seguir procesando la petición real).
 */
export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
