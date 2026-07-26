import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const USER_AGENTS = [
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:1; iOS 26.5.2) Alamofire/5.4.4',
  'Stash/2.6.8 (Android; 33; Scale/2.75)',
  'Stash/2.6.8 (Android; 34; Scale/3.00)',
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:2; iOS 27.0) Alamofire/5.4.4',
];

const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { igdb_id } = await req.json();

    if (!igdb_id) {
      throw new Error('igdb_id is required');
    }

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Stash API parameters
    // Preferimos la variable de entorno, pero usamos tu token actual como fallback seguro
    const stashToken = Deno.env.get('STASH_JWT_TOKEN') || 'eyJraWQiOiJ3MjdhNzM1Ni00NTFmLTQ5M2ItOTY2OC1hNDY4TDMkYmE2IjlcJ0eXAiOiJKV1QilCJhbGciOiJSUzI1NiJ9.eyJzZWIiOiIxMTQ4OTEzIiwiZGV2aWNlX2lkIjoiRUVCRkMzN0UtNDcxNS00ODcyLUJFRjMtRTA0MUZFNkU0MjA3IiwidXNlcl9pZCI6IjExNTYxMzI5MjYzOTE4OTUyMDQzNiIsImlhdCI6MTcyMTk5MzYyNCwic29jaWFsX3R5cGUiOiJnb29nbGUiLCJleHAiOjE3ODk5MzYyNjQsInN1YiI6IjExNDg5MTMiLCJpc3MiOiJodHRwczpcL1wvc3Rhc2guZ2FtZXMiLCJqdGkiOiI0OTYxMzQ0My1jYmI1LTQ5MTEtOGI4Yy1hOTgwYzExY2I2NGRlIiwibmJmIjoxNzgxOTI5NjI0LCJzY29wZSI6WyJ1c2VyIiwiZGV2aWNlIl19.HqBqdwlmcnf3Lb22-cn9Vc8SwOTajaxz3_Bf_Aad-52k0hGVzrz9_XOwbbrojAmN3xNXtlYM8OO2HM0StwEO4Id-t9vK1ZkjhsyHbhOGi7y8Fojl-iywZ3umrOhPAsCmztWl3CLNEGLvoNOJiCK8HuzKG74OR9qGNpAAWpyFDTXbMKK-Mue7m060YDCrkbsXzCoDdSGqQOkyK1C0DuVAMuc64NeATz6xGo8KYPiDI3nKB7GF9fGdLAwZ1Qs2O0A_DHn7eFnRnI0GbU1qA7fn4fR8BjRILemEIQggCZBJN4Jm4pvufH41o1m8XBBaaAO5EwTXUYWvo_6x4yySa4Vgw';
    
    const stashUrl = `https://api.stash.games/api/v1/games/${igdb_id}/reviews?limit=20&offset=0&sort.direction=DESC&sort.field=DATE_ADDED`;

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
      console.error(`Stash API Error: ${res.status} ${errText}`);
      throw new Error(`Stash API responded with status ${res.status}`);
    }

    const data = await res.json();
    const allItems = data.items || [];
    
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
  
      const key = `${game ? game.id : igdb_id}_${userName}`;
      reviewsMap.set(key, {
        game_id: game ? game.id : igdb_id, 
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
        console.error('Error upserting games:', gamesError);
      }
    }

    let insertedCount = 0;
    if (reviewsToInsert.length > 0) {
      // Upsert basado en game_id y nombre de usuario para actualizar reseñas viejas del mismo usuario
      const { error: upsertError } = await supabase
        .from('stash_community_reviews')
        .upsert(reviewsToInsert, { 
          onConflict: 'game_id, stash_user_display_name',
          ignoreDuplicates: false 
        });
        
      if (upsertError) {
        console.error('Error in upsert:', upsertError);
        throw upsertError;
      }
      insertedCount = reviewsToInsert.length;
    }

    // Actualizar metadata para la caché
    const { error: metaError } = await supabase
      .from('stash_sync_metadata')
      .upsert({ game_id: igdb_id, last_checked_at: new Date().toISOString() });
      
    if (metaError) {
      console.error('Error updating metadata:', metaError);
    }

    return new Response(JSON.stringify({ success: true, processed: insertedCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    console.error("Error fetch-stash-reviews:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
