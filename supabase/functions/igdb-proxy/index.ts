const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

// Helper para logging estructurado en JSON
const log = (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, any> = {}) => {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      message,
      ...meta,
    })
  );
};

// Caché en memoria del token de acceso a Twitch
let cachedToken: string | null = null;
let tokenExpiresAt: Date | null = null;

async function getTwitchAccessToken(): Promise<string> {
  const now = new Date();
  if (cachedToken && tokenExpiresAt && now < tokenExpiresAt) {
    return cachedToken;
  }

  const clientId = Deno.env.get('IGDB_CLIENT_ID');
  const clientSecret = Deno.env.get('IGDB_CLIENT_SECRET');

  if (!clientId || !clientSecret) {
    log('ERROR', 'Faltan credenciales IGDB_CLIENT_ID o IGDB_CLIENT_SECRET en variables de entorno');
    throw new Error('IGDB credentials not configured on server');
  }

  log('INFO', 'Solicitando nuevo token de acceso a Twitch/IGDB');
  const authUrl = `https://id.twitch.tv/oauth2/token?client_id=${clientId}&client_secret=${clientSecret}&grant_type=client_credentials`;
  const res = await fetch(authUrl, { method: 'POST' });

  if (!res.ok) {
    const errorText = await res.text();
    log('ERROR', 'Error al autenticar con Twitch', { status: res.status, error: errorText });
    throw new Error(`Twitch authentication failed: ${res.status}`);
  }

  const data = await res.json();
  cachedToken = data.access_token;

  // Guardamos expiración con 5 minutos de margen de seguridad
  const expiresInSeconds = typeof data.expires_in === 'number' ? data.expires_in : 3600;
  tokenExpiresAt = new Date(Date.now() + (expiresInSeconds - 300) * 1000);

  log('INFO', 'Token de Twitch obtenido con éxito', { expiresInSeconds });
  return cachedToken!;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405,
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

    const clientId = Deno.env.get('IGDB_CLIENT_ID');
    if (!clientId) {
      log('ERROR', 'Falta IGDB_CLIENT_ID en variables de entorno');
      return new Response(JSON.stringify({ error: 'Server misconfigured: missing IGDB_CLIENT_ID' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const token = await getTwitchAccessToken();

    log('INFO', 'Reenviando consulta a IGDB', { endpoint, queryLength: query.length });

    const igdbRes = await fetch(`https://api.igdb.com/v4/${endpoint}`, {
      method: 'POST',
      headers: {
        'Client-ID': clientId,
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'text/plain',
      },
      body: query,
    });

    const responseText = await igdbRes.text();

    if (!igdbRes.ok) {
      log('ERROR', 'Error devuelto por IGDB API', {
        status: igdbRes.status,
        endpoint,
        error: responseText,
      });
      return new Response(responseText, {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: igdbRes.status,
      });
    }

    log('INFO', 'Consulta a IGDB completada con éxito', { endpoint, status: igdbRes.status });

    let cleanBody = responseText;
    try {
      cleanBody = JSON.stringify(JSON.parse(responseText));
    } catch (_) {}

    return new Response(cleanBody, {
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
