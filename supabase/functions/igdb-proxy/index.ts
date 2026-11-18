// supabase/functions/igdb-proxy/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeadersForRequest, handleCorsPreflight } from '../_shared/cors.ts';
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

function getServiceSupabase() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceKey) return null;
  return createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });
}

function nonEmptyStr(val: unknown): string | null {
  if (typeof val !== 'string') return null;
  const trimmed = val.trim();
  return trimmed.length > 0 && trimmed !== 'null' ? trimmed : null;
}

function nonEmptyStrArray(val: unknown): string[] | null {
  if (!Array.isArray(val) || val.length === 0) return null;
  const out = val
    .map((item) => {
      if (typeof item === 'string') return item.trim();
      if (item && typeof item === 'object' && typeof (item as Record<string, unknown>).name === 'string') {
        return ((item as Record<string, unknown>).name as string).trim();
      }
      return '';
    })
    .filter((s) => s.length > 0);
  return out.length > 0 ? out : null;
}

function buildPatchFromExisting(
  existing: Record<string, any>,
  candidate: Record<string, any>,
): Record<string, any> {
  const patch: Record<string, any> = {};

  const coverUrl = nonEmptyStr(candidate.cover_url);
  if ((!existing.cover_url || existing.cover_url === '') && coverUrl && coverUrl.startsWith('https://')) {
    patch.cover_url = coverUrl;
  }

  const rawDate = nonEmptyStr(candidate.release_date);
  const releaseDate = rawDate ? rawDate.split('T')[0] : null;
  if (!existing.release_date && releaseDate && /^\d{4}-\d{2}-\d{2}$/.test(releaseDate)) {
    patch.release_date = releaseDate;
  }

  const summary = nonEmptyStr(candidate.summary);
  if ((!existing.summary || existing.summary === '') && summary) {
    patch.summary = summary;
  }

  const dev = nonEmptyStr(candidate.developer);
  const existingDev = nonEmptyStr(existing.developer);
  const existingDevMissing = !existingDev || existingDev === 'Desconocido' || existingDev === 'Desarrollador desconocido';
  if (existingDevMissing && dev && dev !== 'Desconocido' && dev !== 'Desarrollador desconocido') {
    patch.developer = dev;
  }

  for (const col of ['genres', 'platforms', 'themes', 'game_modes', 'player_perspectives'] as const) {
    const existingList = existing[col];
    const hasExisting = Array.isArray(existingList) && existingList.length > 0;
    if (!hasExisting) {
      const nextList = nonEmptyStrArray(candidate[col]);
      if (nextList) patch[col] = nextList;
    }
  }

  if (existing.category == null && typeof candidate.category === 'number' && Number.isFinite(candidate.category)) {
    patch.category = Math.trunc(candidate.category);
  }

  return patch;
}

async function backfillGameMetadata(igdbId: number, candidate: Record<string, any>): Promise<boolean> {
  const supabase = getServiceSupabase();
  if (!supabase) return false;

  const { data: existing, error: selectErr } = await supabase
    .from('games')
    .select('igdb_id, cover_url, release_date, summary, developer, genres, platforms, themes, game_modes, player_perspectives, category')
    .eq('igdb_id', igdbId)
    .maybeSingle();

  if (selectErr || !existing) return false;

  const patch = buildPatchFromExisting(existing, candidate);
  if (Object.keys(patch).length === 0) return false;

  const { error: updateErr } = await supabase
    .from('games')
    .update(patch)
    .eq('igdb_id', igdbId);

  if (updateErr) {
    log('WARN', 'Error en backfill de public.games', { igdbId, error: updateErr.message });
    return false;
  }
  log('INFO', 'Backfill de public.games completado', { igdbId, fields: Object.keys(patch) });
  return true;
}

function extractDeveloperFromIgdb(igdbGame: Record<string, any>): string | null {
  const companies = igdbGame.involved_companies;
  if (!Array.isArray(companies) || companies.length === 0) return null;
  const devEntry = companies.find((c: any) => c?.developer === true && c?.company?.name)
    ?? companies.find((c: any) => c?.company?.name);
  return nonEmptyStr(devEntry?.company?.name);
}

async function healSkeletonFromIgdb(igdbGame: Record<string, any>): Promise<void> {
  const igdbId = typeof igdbGame?.id === 'number' ? igdbGame.id : Number(igdbGame?.id);
  const imageId = nonEmptyStr(igdbGame?.cover?.image_id);
  if (!Number.isFinite(igdbId) || igdbId <= 0 || !imageId) return;

  const candidate: Record<string, any> = {
    cover_url: `https://images.igdb.com/igdb/image/upload/t_cover_big/${imageId}.jpg`,
    summary: igdbGame.summary,
    developer: extractDeveloperFromIgdb(igdbGame),
    genres: igdbGame.genres,
    platforms: igdbGame.platforms,
    themes: igdbGame.themes,
    game_modes: igdbGame.game_modes,
    player_perspectives: igdbGame.player_perspectives,
    category: typeof igdbGame.game_type === 'number'
      ? igdbGame.game_type
      : (typeof igdbGame.category === 'number' ? igdbGame.category : undefined),
  };

  if (typeof igdbGame.first_release_date === 'number' && Number.isFinite(igdbGame.first_release_date)) {
    candidate.release_date = new Date(igdbGame.first_release_date * 1000).toISOString().split('T')[0];
  }

  await backfillGameMetadata(igdbId, candidate);
}

Deno.serve(async (req: Request) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  const corsHeaders = corsHeadersForRequest(req);

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

    if (endpoint === 'backfill_game') {
      const authHeader = req.headers.get('Authorization') ?? '';
      const token = authHeader.replace(/^Bearer\s+/i, '').trim();
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
      const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
      if (!token || token === supabaseAnonKey) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        });
      }

      const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { persistSession: false },
      });
      const { data: { user }, error: authErr } = await supabaseUser.auth.getUser(token);
      if (authErr || !user) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        });
      }

      const game = body?.game;
      const igdbId = typeof game?.igdb_id === 'number' ? game.igdb_id : Number(game?.igdb_id);
      if (!game || typeof game !== 'object' || !Number.isFinite(igdbId) || igdbId <= 0) {
        return new Response(JSON.stringify({ error: 'Invalid game payload for backfill_game' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        });
      }

      const updated = await backfillGameMetadata(igdbId, game as Record<string, any>);
      return new Response(JSON.stringify({ ok: true, updated }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

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

    if (
      endpoint === 'games' &&
      Array.isArray(result.data) &&
      result.data.length === 1 &&
      result.data[0]?.id &&
      result.data[0]?.cover?.image_id
    ) {
      const bgTask = healSkeletonFromIgdb(result.data[0]).catch((e) =>
        log('WARN', 'Error en backfill automático desde IGDB', { error: String(e) })
      );
      const edgeRuntime = (globalThis as {
        EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void };
      }).EdgeRuntime;
      if (edgeRuntime && typeof edgeRuntime.waitUntil === 'function') {
        edgeRuntime.waitUntil(bgTask);
      } else {
        await bgTask;
      }
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
