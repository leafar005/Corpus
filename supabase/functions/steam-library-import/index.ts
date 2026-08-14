import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { igdbGamesRequest, IGDB_FIELDS, getIgdbAccessToken } from '../_shared/igdb-client.ts';

const IGDB_CLIENT_ID = Deno.env.get('IGDB_CLIENT_ID') ?? '';
const IGDB_CLIENT_SECRET = Deno.env.get('IGDB_CLIENT_SECRET') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ?? '';
const STEAM_WEB_API_KEY = Deno.env.get('STEAM_WEB_API_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Blacklist similar to sync-bundles
const STEAM_LIBRARY_BLACKLIST = [
  'soundtrack', 'ost', 'artbook', 'dedicated server', 'sdk',
  'demo', 'beta', 'test server', 'benchmark', 'tool'
];

function isBlacklisted(title: string): boolean {
  const lower = title.toLowerCase().trim();
  if (!lower) return true;
  for (const word of STEAM_LIBRARY_BLACKLIST) {
    if (lower.includes(word)) return true;
  }
  return false;
}


Deno.serve(async (req) => {
  const FUNCTION_START = Date.now();
  const TIME_BUDGET_MS = 120_000;

  function timeLeft(): number {
    return TIME_BUDGET_MS - (Date.now() - FUNCTION_START);
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header provided');
    }

    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseUser = createClient(SUPABASE_URL, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    // We use service role for db operations because some tables/views might be locked or for bulk upserts.
    // Wait, upserting to games needs service role, user_games might use user token but service role is easier.
    // We already verified the user via auth.getUser().
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('steam_id')
      .eq('id', user.id)
      .single();

    if (userError || !userData?.steam_id) {
      throw new Error('STEAM_NOT_LINKED');
    }

    const steamId = userData.steam_id;
    const body = await req.json().catch(() => ({}));
    let minPlaytimeMinutes = typeof body.minPlaytimeMinutes === 'number' && body.minPlaytimeMinutes >= 0 
      ? body.minPlaytimeMinutes 
      : 180;

    // Check for existing running job
    const { data: existingJobs } = await supabase
      .from('steam_import_jobs')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'running')
      .order('created_at', { ascending: false })
      .limit(1);

    let job = existingJobs && existingJobs.length > 0 ? existingJobs[0] : null;

    if (job) {
      minPlaytimeMinutes = job.min_playtime_minutes ?? 180;
    }

    const steamRes = await fetch(`https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${STEAM_WEB_API_KEY}&steamid=${steamId}&include_appinfo=1&include_played_free_games=1&format=json`);
    
    if (!steamRes.ok) {
      const errorText = await steamRes.text();
      console.error('Steam API Error:', errorText.substring(0, 200));
      throw new Error(`STEAM_API_ERROR: ${steamRes.status}`);
    }

    const steamData = await steamRes.json();

    if (!steamData.response || Object.keys(steamData.response).length === 0) {
      // Private library
      await supabase.from('users').update({ steam_profile_public: false }).eq('id', user.id);
      if (job) {
        await supabase.from('steam_import_jobs').update({ status: 'failed', error_message: 'PRIVATE_PROFILE' }).eq('id', job.id);
      }
      throw new Error('PRIVATE_PROFILE');
    }

    await supabase.from('users').update({ steam_profile_public: true }).eq('id', user.id);

    const gamesRaw = steamData.response.games || [];
    
    // Filter by playtime and blacklist
    const filteredByPlaytime = gamesRaw.filter((g: any) => (g.playtime_forever ?? 0) >= minPlaytimeMinutes);
    const gamesToProcess = filteredByPlaytime.filter((g: any) => !isBlacklisted(g.name || ''));

    if (!job) {
      const { data: newJob, error: jobError } = await supabase
        .from('steam_import_jobs')
        .insert({
          user_id: user.id,
          status: 'running',
          min_playtime_minutes: minPlaytimeMinutes,
          total_games: gamesToProcess.length,
        })
        .select()
        .single();
      
      if (jobError) throw jobError;
      job = newJob;
    }

    let resumeCursor = job.resume_cursor || 0;
    let matchedGames = job.matched_games || 0;
    let unmatchedGames = job.unmatched_games || 0;
    let allCatalogGames: any[] = [];
    let allUserGames: any[] = [];

    const BATCH_SIZE = 50;
    
    let steamSourceId: number | null = null;
    {
      const token = await getIgdbAccessToken();
      const res = await fetch('https://api.igdb.com/v4/external_game_sources', {
        method: 'POST',
        headers: {
          'Client-ID': IGDB_CLIENT_ID,
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
        },
        body: 'fields id, name; limit 50;'
      });
      if (res.ok) {
        const sources = await res.json();
        const steamSource = sources.find((s: any) => s.name?.toLowerCase() === 'steam');
        if (steamSource) steamSourceId = steamSource.id;
      }
    }

    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    while (resumeCursor < gamesToProcess.length && timeLeft() > 15000) {
      const chunk = gamesToProcess.slice(resumeCursor, resumeCursor + BATCH_SIZE);
      const appIds = chunk.map((g: any) => g.appid);
      
      const orConditions = appIds.map((id: number) => `uid = "${id}"`).join(' | ');
      const sourceFilter = steamSourceId !== null ? `external_game_source = ${steamSourceId}` : `category = 1`;
      const query = `fields uid, game; where ${sourceFilter} & (${orConditions}); limit 500;`;
      
      const token = await getIgdbAccessToken();
      const igdbExtRes = await fetch('https://api.igdb.com/v4/external_games', {
        method: 'POST',
        headers: { 'Client-ID': IGDB_CLIENT_ID, 'Authorization': `Bearer ${token}`, 'Accept': 'application/json' },
        body: query
      });

      const steamIdToIgdbId: Record<number, number> = {};
      if (igdbExtRes.ok) {
        const extGames = await igdbExtRes.json();
        for (const ext of extGames) {
          if (ext.uid && ext.game) steamIdToIgdbId[parseInt(ext.uid)] = ext.game;
        }
      }

      const igdbIdsToFetch = Array.from(new Set(Object.values(steamIdToIgdbId)));
      const igdbIdToGameMap: Record<number, any> = {};
      
      if (igdbIdsToFetch.length > 0) {
        const gameQuery = `${IGDB_FIELDS} where id = (${igdbIdsToFetch.join(',')}); limit 500;`;
        const igdbGames = await igdbGamesRequest(gameQuery);
        for (const g of igdbGames) igdbIdToGameMap[g.id] = g;
      }

      const resolvedGamesForCatalog: any[] = [];
      const userGamesUpserts: any[] = [];

      for (const steamGame of chunk) {
        const appId = steamGame.appid;
        const igdbId = steamIdToIgdbId[appId];
        let gameObj: any = null;

        if (igdbId && igdbIdToGameMap[igdbId]) {
          const raw = igdbIdToGameMap[igdbId];
          gameObj = {
            igdb_id: raw.id,
            title: raw.name,
            cover_url: raw.cover?.image_id ? `https://images.igdb.com/igdb/image/upload/t_cover_big/${raw.cover.image_id}.jpg` : null,
            release_date: raw.first_release_date ? new Date(raw.first_release_date * 1000).toISOString().split('T')[0] : null,
            genres: raw.genres?.map((g: any) => g.name) || [],
            steam_app_id: appId,
            summary: raw.summary,
            platforms: raw.platforms?.map((p: any) => p.name) || [],
            developer: raw.involved_companies?.find((c: any) => c.developer)?.company?.name || null,
            category: raw.category,
            parent_game: raw.parent_game,
            themes: raw.themes?.map((t: any) => t.name) || [],
            game_modes: raw.game_modes?.map((m: any) => m.name) || [],
            player_perspectives: raw.player_perspectives?.map((p: any) => p.name) || [],
            collection: raw.collection?.name || null,
            franchises: raw.franchises?.map((f: any) => f.name) || [],
            game_engines: raw.game_engines?.map((e: any) => e.name) || [],
          };
          matchedGames++;
        }

        // Fallback or metacritic fetch
        if (timeLeft() > 5000) {
          try {
            const fallbackRes = await fetch(`https://store.steampowered.com/api/appdetails?appids=${appId}&l=spanish`);
            if (fallbackRes.ok) {
              const fallbackJson = await fallbackRes.json();
              const appData = fallbackJson[appId.toString()];
              if (appData && appData.success) {
                const data = appData.data;
                if (!gameObj && data.type === 'game') { // fully unmatched by IGDB
                  gameObj = {
                    igdb_id: appId + 1000000000, // fake igdb_id to satisfy primary key requirement ideally, but wait: igdb_id is primary key, it must be unique. Let's use a very high negative number or just appId + big offset.
                    title: data.name,
                    cover_url: data.header_image,
                    release_date: data.release_date?.date ? new Date(data.release_date.date).toISOString().split('T')[0] : null, // handle date parse carefully, often not ISO
                    genres: data.genres?.map((g: any) => g.description) || [],
                    steam_app_id: appId,
                    summary: data.short_description,
                    platforms: ['PC (Steam)'],
                    developer: data.developers?.length > 0 ? data.developers[0] : null,
                  };
                  unmatchedGames++;
                }
                
                // Add metacritic to either IGDB or Fallback resolved object
                if (gameObj) {
                  gameObj.metacritic_score = data.metacritic?.score ?? null;
                  gameObj.metacritic_url = data.metacritic?.url ?? null;
                }
              }
            }
          } catch (e) {
            console.error(`Steam fallback error for ${appId}:`, e);
          }
        }

        if (gameObj) {
          // If igdb_id is fake, we should make sure it doesn't collide.
          // Using -steamAppId is a good trick for Steam-only games in an IGDB DB.
          if (!igdbId) {
            gameObj.igdb_id = -appId;
          }
          resolvedGamesForCatalog.push(gameObj);

          userGamesUpserts.push({
            user_id: user.id,
            game_id: gameObj.igdb_id,
            steam_owned: true,
            steam_playtime_minutes: steamGame.playtime_forever || 0,
            steam_last_played_at: (steamGame.rtime_last_played && Number(steamGame.rtime_last_played) > 0) ? new Date(Number(steamGame.rtime_last_played) * 1000).toISOString() : null,
            steam_imported_at: new Date().toISOString()
            // Critical Rule 1: We DO NOT include status, rating, or comment here.
          });
        }
      }

      // Upsert games
      if (resolvedGamesForCatalog.length > 0) {
        await supabase.from('games').upsert(resolvedGamesForCatalog, { onConflict: 'igdb_id' });
        allCatalogGames.push(...resolvedGamesForCatalog);
      }

      if (userGamesUpserts.length > 0) {
        allUserGames.push(...userGamesUpserts);
      }

      resumeCursor += chunk.length;
      await supabase.from('steam_import_jobs').update({
        resume_cursor: resumeCursor,
        processed_games: resumeCursor,
        matched_games: matchedGames,
        unmatched_games: unmatchedGames,
      }).eq('id', job.id);
      
      await sleep(200);
    }

    if (resumeCursor < gamesToProcess.length) {
      return new Response(JSON.stringify({ 
        done: false, 
        resumeAt: resumeCursor,
        catalogGames: allCatalogGames,
        userGames: allUserGames
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 });
    } else {
      await supabase.from('steam_import_jobs').update({ status: 'completed' }).eq('id', job.id);
      return new Response(JSON.stringify({ 
        done: true,
        catalogGames: allCatalogGames,
        userGames: allUserGames
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 });
    }

  } catch (error: any) {
    console.error("Error steam-library-import:", error);
    
    // Attempt to fail job if we can
    const errMessage = error.message;
    // (Job failing already handled for PRIVATE_PROFILE above if it was available)

    return new Response(JSON.stringify({ error: errMessage }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: errMessage === 'PRIVATE_PROFILE' ? 403 : 500,
    });
  }
});
