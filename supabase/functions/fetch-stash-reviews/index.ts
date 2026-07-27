import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const log = (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, any> = {}) => {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      service: 'fetch-stash-reviews',
      message,
      ...meta,
    })
  );
};


const USER_AGENTS = [
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:1; iOS 26.5.2) Alamofire/5.4.4',
  'Stash/2.6.8 (Android; 33; Scale/2.75)',
  'Stash/2.6.8 (Android; 34; Scale/3.00)',
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:2; iOS 27.0) Alamofire/5.4.4',
];

const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    // Validación de entrada: igdb_id debe ser un entero positivo
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
      console.error('STASH_JWT_TOKEN environment variable is not set');
      return new Response(
        JSON.stringify({ error: 'Stash token not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 503 }
      );
    }

    const stashUrl = `https://api.stash.games/api/v1/games/${igdbId}/reviews?limit=20&offset=0&sort.direction=DESC&sort.field=DATE_ADDED`;

    // Jitter: retraso aleatorio entre 500ms y 2000ms
    const jitterMs = Math.floor(Math.random() * 1500) + 500;
    await delay(jitterMs);

    const randomUA = USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];

    const res = await fetch(stashUrl, {
      method: 'GET',
      headers: {
        'Host': 'api.stash.games',
        'Accept': '*/*',
        'Accept-Locale': 'es_ES',
        'Time-Zone': 'Europe/Madrid',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept-Language': 'es',
        'Content-Type': 'application/json',
        'User-Agent': randomUA,
        'X-Game-Status-Version': 'v2',
        'Authorization': `Bearer ${stashToken}`
      }
    });

    if (!res.ok) {
      const errText = await res.text();
      log('ERROR', 'Stash API devolvió error HTTP', { status: res.status, errorText: errText });
      throw new Error(`Stash API responded with status ${res.status}`);
    }

    const data = await res.json();
    const allItems = data.items || [];
    
    log('INFO', 'Reseñas recibidas de la API de Stash', { igdbId, itemsCount: allItems.length });

    const gamesMap = new Map();
    const reviewsMap = new Map();
    
    for (const item of allItems) {
      const { user, review, game } = item;
      
      if (!review || !review.comment || review.comment.trim() === '') {
        continue; 
      }

      if (game && game.id) {
        gamesMap.set(game.id, {
          igdb_id: game.id,
          title: game.name || 'Desconocido',
          cover_url: game.cover?.url || null
        });
      }
  
      const stashCreatedAt = review.modificationDate 
        ? new Date(review.modificationDate * 1000).toISOString() 
        : null;
        
      const userName = user?.fullName || user?.login || 'Usuario Desconocido';
  
      const key = `${game ? game.id : igdbId}_${userName}`;
      reviewsMap.set(key, {
        game_id: game ? game.id : igdbId, 
        stash_user_display_name: userName,
        stash_user_avatar_url: user?.imageUrl || null,
        comment: review.comment.trim(),
        rating: review.ratingFloat || review.rating || null,
        source_context: 'game_reviews',
        stash_created_at: stashCreatedAt,
      });
    }

    const gamesToUpsert = Array.from(gamesMap.values());
    const reviewsToInsert = Array.from(reviewsMap.values());

    if (gamesToUpsert.length > 0) {
      const { error: gamesError } = await supabase
        .from('games')
        .upsert(gamesToUpsert, { 
          onConflict: 'igdb_id',
          ignoreDuplicates: true 
        });
      if (gamesError) {
        log('ERROR', 'Error en upsert de juegos referenciados', { error: gamesError.message });
      }
    }

    let insertedCount = 0;
    if (reviewsToInsert.length > 0) {
      const { error: upsertError } = await supabase
        .from('stash_community_reviews')
        .upsert(reviewsToInsert, { 
          onConflict: 'game_id, stash_user_display_name',
          ignoreDuplicates: false 
        });
        
      if (upsertError) {
        log('ERROR', 'Error en upsert idempotente de reseñas', { error: upsertError.message });
        throw upsertError;
      }
      insertedCount = reviewsToInsert.length;
    }

    // Actualizar metadata para la caché
    const { error: metaError } = await supabase
      .from('stash_sync_metadata')
      .upsert({ game_id: igdbId, last_checked_at: new Date().toISOString() });
      
    if (metaError) {
      log('ERROR', 'Error en upsert de metadata de caché', { error: metaError.message });
    }

    log('INFO', 'Sincronización de reseñas completada', { igdbId, upsertedCount: insertedCount });

    return new Response(JSON.stringify({ success: true, processed: insertedCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    log('ERROR', 'Error fatal en fetch-stash-reviews', { error: error.message || String(error) });
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

