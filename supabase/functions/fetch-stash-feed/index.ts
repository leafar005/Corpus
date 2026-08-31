import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders, randomUserAgent, jitter, buildStashHeaders, makeLogger } from '../_shared/stash-client.ts';
import { checkRateLimit } from '../_shared/rate-limit.ts';

const log = makeLogger('fetch-stash-feed');

const STASH_RATE_LIMIT_BUCKET = 'stash-shared-account';
const STASH_RATE_LIMIT_MAX = 20;
const STASH_RATE_LIMIT_WINDOW_SECONDS = 60;

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
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const stashToken = Deno.env.get('STASH_JWT_TOKEN') ?? '';
    if (!stashToken) {
      console.error('STASH_JWT_TOKEN environment variable is not set');
      return new Response(
        JSON.stringify({ error: 'Stash token not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 503 }
      );
    }

    // Global feed of recent reviews
    const stashUrl = `https://api.stash.games/api/v1/games/reviews/latest?limit=25`;

    await jitter();

    const randomUA = randomUserAgent();
    const headers = buildStashHeaders(stashToken, randomUA);

    const res = await fetch(stashUrl, {
      method: 'GET',
      headers,
    });

    if (!res.ok) {
      const errText = await res.text();
      log('ERROR', 'Stash API devolvió error HTTP', { status: res.status, errorText: errText });
      throw new Error(`Stash API responded with status ${res.status}`);
    }

    const data = await res.json();
    const allItems = data.items || [];

    log('INFO', 'Feed reciente de Stash obtenido', { itemsCount: allItems.length });

    const gamesMap = new Map();
    const reviewsMap = new Map();
    
    for (const item of allItems) {
      const { user, review, game } = item;
      
      if (!review || !game || !game.id) {
        continue; 
      }

      // Prepare Game to upsert in public.games
      // Solo incluimos cover_url si Stash realmente nos lo dio.
      // Así nunca pisamos un cover_url bueno que ya exista en games.
      const gameEntry: Record<string, unknown> = {
        igdb_id: game.id,
        title: game.name || 'Desconocido',
      };
      if (game.cover?.url) {
        gameEntry.cover_url = game.cover.url;
      }
      gamesMap.set(game.id, gameEntry);
  
      if (!review.comment || review.comment.trim() === '') {
        continue; 
      }

      const stashCreatedAt = review.modificationDate 
        ? new Date(review.modificationDate * 1000).toISOString() 
        : null;
        
      const userName = user?.fullName || user?.login || 'Usuario Desconocido';
      
      const key = `${game.id}_${userName}`;
      reviewsMap.set(key, {
        game_id: game.id,
        stash_user_display_name: userName,
        stash_user_avatar_url: user?.imageUrl || null,
        comment: review.comment.trim(),
        rating: review.ratingFloat || review.rating || null,
        source_context: 'recent_activity_feed',
        stash_created_at: stashCreatedAt,
      });
    }

    const gamesToUpsert = Array.from(gamesMap.values());
    const reviewsToInsert = Array.from(reviewsMap.values());

    // 1. Upsert Games
    if (gamesToUpsert.length > 0) {
      const { error: gamesError } = await supabase
        .from('games')
        .upsert(gamesToUpsert, {
          onConflict: 'igdb_id',
          ignoreDuplicates: true
        });
      if (gamesError) {
        log('ERROR', 'Error al hacer upsert de juegos referenciados', { error: gamesError.message });
      }
    }

    // 2. Upsert Reviews
    let insertedCount = 0;
    if (reviewsToInsert.length > 0) {
      const { error: upsertError } = await supabase
        .from('stash_community_reviews')
        .upsert(reviewsToInsert, {
          onConflict: 'game_id, stash_user_display_name',
          ignoreDuplicates: false
        });

      if (upsertError) {
        log('ERROR', 'Error en upsert idempotente de feed de reseñas', { error: upsertError.message });
        throw upsertError;
      }
      insertedCount = reviewsToInsert.length;
    }

    log('INFO', 'Sincronización de feed reciente completada', { upsertedCount: insertedCount });

    return new Response(JSON.stringify({ success: true, processed: insertedCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    log('ERROR', 'Error fatal en fetch-stash-feed', { error: error.message || String(error) });
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

