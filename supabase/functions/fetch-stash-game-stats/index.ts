// supabase/functions/fetch-stash-game-stats/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders, randomUserAgent, jitter, buildStashHeaders, makeLogger } from '../_shared/stash-client.ts';
import { checkRateLimit } from '../_shared/rate-limit.ts';

const log = makeLogger('fetch-stash-game-stats');

const STASH_RATE_LIMIT_BUCKET = 'stash-shared-account';
const STASH_RATE_LIMIT_MAX = 20;
const STASH_RATE_LIMIT_WINDOW_SECONDS = 60;

// Rutas confirmadas contra la API real de Stash
const STASH_GAME_DETAIL_URL = (id: number) => `https://api.stash.games/api/v1/games/${id}`;
const STASH_STATUS_STATISTIC_URL = (id: number) => `https://api.stash.games/api/v1/games/${id}/statuses/statistic`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const rateLimit = await checkRateLimit({
    bucketKey: STASH_RATE_LIMIT_BUCKET,
    maxRequests: STASH_RATE_LIMIT_MAX,
    windowSeconds: STASH_RATE_LIMIT_WINDOW_SECONDS,
  });
  if (!rateLimit.allowed) {
    log('WARN', 'Rate limit de Stash excedido, petición rechazada');
    return new Response(JSON.stringify({ error: 'Too many requests, please slow down' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': String(STASH_RATE_LIMIT_WINDOW_SECONDS) },
      status: 429,
    });
  }

  try {
    const body = await req.json();
    const igdbId = parseInt(body?.igdb_id);
    if (!Number.isInteger(igdbId) || igdbId <= 0) {
      return new Response(
        JSON.stringify({ error: 'igdb_id must be a positive integer' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const stashToken = Deno.env.get('STASH_JWT_TOKEN') ?? '';
    if (!stashToken) {
      log('ERROR', 'STASH_JWT_TOKEN no configurado');
      return new Response(
        JSON.stringify({ error: 'Stash token not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 503 }
      );
    }

    // Misma UA para ambas llamadas: en la app real, ambas peticiones salen
    // de la misma sesión al abrir la ficha del juego, así que deben parecer
    // el mismo cliente.
    const userAgent = randomUserAgent();
    const headers = buildStashHeaders(stashToken, userAgent);

    // --- Llamada 1: detalle del juego (trae stashRating) ---
    await jitter();
    const detailRes = await fetch(STASH_GAME_DETAIL_URL(igdbId), { method: 'GET', headers });

    let stashRating: number | null = null;
    let gameName: string | null = null;

    if (detailRes.ok) {
      const detailData = await detailRes.json();
      stashRating = typeof detailData?.game?.stashRating === 'number' ? detailData.game.stashRating : null;
      gameName = detailData?.game?.name ?? null;
    } else if (detailRes.status === 404) {
      log('WARN', 'Juego no encontrado en Stash (detalle)', { igdbId });
    } else {
      const errText = await detailRes.text();
      log('ERROR', 'Error HTTP en detalle de juego', { status: detailRes.status, errorText: errText });
    }

    // --- Llamada 2: status counts (want/playing/played) ---
    await jitter();
    const countsRes = await fetch(STASH_STATUS_STATISTIC_URL(igdbId), { method: 'GET', headers });

    let wantCount: number | null = null;
    let playingCount: number | null = null;
    let playedCount: number | null = null;

    if (countsRes.ok) {
      const countsData = await countsRes.json();
      wantCount = typeof countsData?.want === 'number' ? countsData.want : null;
      playingCount = typeof countsData?.playing === 'number' ? countsData.playing : null;
      playedCount = typeof countsData?.played === 'number' ? countsData.played : null;
    } else if (countsRes.status === 404) {
      log('WARN', 'Juego no encontrado en Stash (status-counts)', { igdbId });
    } else {
      const errText = await countsRes.text();
      log('ERROR', 'Error HTTP en status-counts', { status: countsRes.status, errorText: errText });
    }

    // Si las DOS llamadas fallaron (no 404, sino error real), no marcamos
    // last_stats_checked_at para que el cliente reintente pronto en vez de
    // quedarse con un "ya lo comprobé" falso.
    const bothFailedHard = !detailRes.ok && detailRes.status !== 404 && !countsRes.ok && countsRes.status !== 404;
    if (bothFailedHard) {
      return new Response(
        JSON.stringify({ error: 'Stash API unavailable for both endpoints' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 502 }
      );
    }

    // Asegurar que existe la fila en games (por si el usuario abre un juego
    // que nunca pasó por fetch-stash-reviews/feed)
    if (gameName) {
      const { error: gameError } = await supabase
        .from('games')
        .upsert({ igdb_id: igdbId, title: gameName }, { onConflict: 'igdb_id', ignoreDuplicates: true });
      if (gameError) {
        log('ERROR', 'Error en upsert de juego referenciado', { error: gameError.message });
      }
    }

    const { error: statsError } = await supabase
      .from('stash_game_stats')
      .upsert(
        {
          game_id: igdbId,
          stash_rating: stashRating,
          want_count: wantCount,
          playing_count: playingCount,
          played_count: playedCount,
          last_stats_checked_at: new Date().toISOString(),
        },
        { onConflict: 'game_id' }
      );

    if (statsError) {
      log('ERROR', 'Error en upsert de stash_game_stats', { error: statsError.message });
      throw statsError;
    }

    log('INFO', 'Stats de Stash sincronizadas', { igdbId, stashRating, wantCount, playingCount, playedCount });

    return new Response(
      JSON.stringify({ success: true, stashRating, wantCount, playingCount, playedCount }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error: any) {
    log('ERROR', 'Error fatal en fetch-stash-game-stats', { error: error.message || String(error) });
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
