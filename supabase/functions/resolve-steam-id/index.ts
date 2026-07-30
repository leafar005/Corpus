import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const STEAM_WEB_API_KEY = Deno.env.get('STEAM_WEB_API_KEY') ?? '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header provided');
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const { urlOrId } = await req.json();
    if (!urlOrId) {
      throw new Error('No URL or ID provided');
    }

    let steamId64 = '';
    const inputStr = urlOrId.toString().trim();

    // Check if it's already a 17-digit steam ID
    if (/^7656119\d{10}$/.test(inputStr)) {
      steamId64 = inputStr;
    } else {
      // It's a URL or a vanity name
      let vanityName = inputStr;
      
      // Try extracting vanity name or ID from URL
      const idMatch = inputStr.match(/\/profiles\/(\d{17})/);
      if (idMatch) {
        steamId64 = idMatch[1];
      } else {
        const vanityMatch = inputStr.match(/\/id\/([^\/]+)/);
        if (vanityMatch) {
          vanityName = vanityMatch[1];
        }

        // Call Steam API to resolve vanity
        const res = await fetch(`https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?key=${STEAM_WEB_API_KEY}&vanityurl=${encodeURIComponent(vanityName)}`);
        if (!res.ok) {
          throw new Error(`Steam API error: ${res.status}`);
        }
        const data = await res.json();
        if (data.response && data.response.success === 1 && data.response.steamid) {
          steamId64 = data.response.steamid;
        } else {
          throw new Error('No se pudo encontrar un usuario de Steam con ese nombre o enlace.');
        }
      }
    }

    if (!steamId64) {
      throw new Error('Could not resolve Steam ID');
    }

    let steamName = steamId64;
    let currently_playing_appid: number | null = null;
    let currently_playing_name: string | null = null;
    let currently_playing_since: string | null = null;
    
    try {
      const summaryRes = await fetch(`https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=${STEAM_WEB_API_KEY}&steamids=${steamId64}`);
      if (summaryRes.ok) {
        const summaryData = await summaryRes.json();
        if (summaryData.response?.players?.length > 0) {
          const p = summaryData.response.players[0];
          steamName = p.personaname;
          
          if (p.gameid) {
            currently_playing_appid = parseInt(p.gameid);
            currently_playing_name = p.gameextrainfo ?? null;
            currently_playing_since = new Date().toISOString();
          }
        }
      }
    } catch (e) {
      console.error("Error fetching steam name:", e);
    }

    // Update user in database
    const updatePayload: any = {
      steam_id: steamId64,
      steam_name: steamName,
      steam_linked_at: new Date().toISOString(),
      currently_playing_appid: currently_playing_appid,
      currently_playing_name: currently_playing_name,
      currently_playing_since: currently_playing_since
    };

    const { error: updateError } = await supabase
      .from('users')
      .update(updatePayload)
      .eq('id', user.id);

    if (updateError) {
      throw updateError;
    }

    return new Response(JSON.stringify({ success: true, steamId: steamId64, steamName: steamName }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Error resolve-steam-id:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
