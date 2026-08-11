// supabase/functions/_shared/igdb-client.ts
//
// Cliente compartido para la API v4 de IGDB y la autenticación OAuth de Twitch.
// Consolida la lógica que antes estaba duplicada en igdb-proxy, sync-bundles
// y steam-library-import (Fase 4 del plan de auditoría, agosto 2026).

const log = (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, any> = {}) => {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      service: 'igdb-client',
      message,
      ...meta,
    })
  );
};

// Caché en memoria del token de acceso a Twitch/IGDB.
// Nota: es un caché "best effort" por isolate de Deno. En cold starts o
// isolates paralelos puede pedirse el token más de una vez — aceptable,
// Twitch no penaliza por ello.
let cachedToken: string | null = null;
let tokenExpiresAt: Date | null = null;

/**
 * Obtiene (y cachea en memoria) un token de acceso OAuth de Twitch para IGDB.
 * Lanza un Error si faltan credenciales o si Twitch rechaza la petición.
 */
export async function getIgdbAccessToken(): Promise<string> {
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

  const expiresInSeconds = typeof data.expires_in === 'number' ? data.expires_in : 3600;
  tokenExpiresAt = new Date(Date.now() + (expiresInSeconds - 300) * 1000);

  log('INFO', 'Token de Twitch obtenido con éxito', { expiresInSeconds });
  return cachedToken!;
}

export type IgdbApiResult =
  | { ok: true; status: number; data: any }
  | { ok: false; status: number; error: string };

/**
 * Petición genérica de bajo nivel a cualquier endpoint de la API v4 de IGDB.
 * No lanza excepciones por respuestas de error de IGDB (4xx/5xx) — las
 * devuelve como { ok: false } para que cada caller decida cómo tratarlas.
 * Si lanza, es por un fallo real (credenciales ausentes, red).
 */
export async function igdbApiRequest(endpoint: string, query: string): Promise<IgdbApiResult> {
  const clientId = Deno.env.get('IGDB_CLIENT_ID');
  if (!clientId) {
    log('ERROR', 'Falta IGDB_CLIENT_ID en variables de entorno');
    throw new Error('Server misconfigured: missing IGDB_CLIENT_ID');
  }

  const token = await getIgdbAccessToken();

  const res = await fetch(`https://api.igdb.com/v4/${endpoint}`, {
    method: 'POST',
    headers: {
      'Client-ID': clientId,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'text/plain',
    },
    body: query,
  });

  const responseText = await res.text();

  if (!res.ok) {
    log('ERROR', 'Error devuelto por IGDB API', { status: res.status, endpoint, error: responseText });
    return { ok: false, status: res.status, error: responseText };
  }

  let parsed: any = responseText;
  try {
    parsed = JSON.parse(responseText);
  } catch (_) {
    // Respuesta no-JSON inesperada; se devuelve el texto crudo.
  }

  return { ok: true, status: res.status, data: parsed };
}

/**
 * Fields compartidos usados por sync-bundles y steam-library-import al
 * resolver juegos completos desde IGDB. Idéntico al que ya usaban ambas
 * funciones antes de la consolidación — ningún campo ha cambiado.
 */
export const IGDB_FIELDS =
  'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name, external_games.uid, external_games.category;';

/**
 * Wrapper de compatibilidad para sync-bundles y steam-library-import: mismo
 * comportamiento exacto que su antiguo `igdbRequest(bodyQuery)` local
 * (siempre contra el endpoint 'games', nunca lanza, devuelve [] en error).
 * El cambio en esos dos archivos se reduce así a un import + rename.
 */
export async function igdbGamesRequest(bodyQuery: string): Promise<any[]> {
  try {
    const result = await igdbApiRequest('games', bodyQuery);
    if (!result.ok) {
      log('ERROR', 'IGDB Error (games)', { status: result.status, error: result.error });
      return [];
    }
    return Array.isArray(result.data) ? result.data : [];
  } catch (error: any) {
    log('ERROR', 'Excepción en igdbGamesRequest', { error: error?.message || String(error) });
    return [];
  }
}
