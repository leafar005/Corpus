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
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const stashToken = Deno.env.get('STASH_JWT_TOKEN') || '';

    // Global feed of recent reviews
    const stashUrl = `https://api.stash.games/api/v1/games/reviews/latest?limit=25`;

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
      
      if (!review || !game || !game.id) {
        continue; 
      }

      // Prepare Game to upsert in public.games
      gamesMap.set(game.id, {
        igdb_id: game.id,
        title: game.name || 'Desconocido',
        cover_url: game.cover?.url || null
      });
  
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
          ignoreDuplicates: true // Solo queremos insertar si no existe, o actualizar el cover
        });
      if (gamesError) {
        console.error('Error upserting games:', gamesError);
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
        console.error('Error in upsert reviews:', upsertError);
        throw upsertError;
      }
      insertedCount = reviewsToInsert.length;
    }

    return new Response(JSON.stringify({ success: true, processed: insertedCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    console.error("Error fetch-stash-feed:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
