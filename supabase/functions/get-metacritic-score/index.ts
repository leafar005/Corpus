import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const { steamAppId } = await req.json();
    if (!steamAppId) {
      throw new Error('No steamAppId provided');
    }

    const res = await fetch(`https://store.steampowered.com/api/appdetails?appids=${steamAppId}&l=spanish`);
    if (!res.ok) {
      throw new Error(`Steam Store API error: ${res.status}`);
    }

    const jsonResp = await res.json();
    const appData = jsonResp[steamAppId.toString()];

    let score = null;
    let url = null;

    if (appData && appData.success && appData.data) {
      score = appData.data.metacritic?.score ?? null;
      url = appData.data.metacritic?.url ?? null;
    }

    // Guardar en la base de datos para no tener que volver a pedirlo (lazy backfill)
    if (score !== null || url !== null) {
      const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ?? '';
      const supabase = createClient(supabaseUrl, SUPABASE_SERVICE_ROLE_KEY);

      await supabase
        .from('games')
        .update({
          metacritic_score: score,
          metacritic_url: url,
          metacritic_updated_at: new Date().toISOString()
        })
        .eq('steam_app_id', steamAppId);
    }

    return new Response(JSON.stringify({ score, url }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Error get-metacritic-score:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
