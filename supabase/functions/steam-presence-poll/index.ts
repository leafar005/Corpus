import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const STEAM_WEB_API_KEY = Deno.env.get('STEAM_WEB_API_KEY') ?? '';

Deno.serve(async (req) => {
  // Use a custom header to bypass Supabase Kong JWT verification
  const authHeader = req.headers.get('x-cron-secret');
  if (authHeader !== Deno.env.get('CRON_SECRET')) {
    console.warn('steam-presence-poll invoked without valid cron secret');
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    // We still need the service role key to perform DB operations
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(SUPABASE_URL, serviceRoleKey);

    // Get linked users
    const { data: users, error } = await supabase
      .from('users')
      .select('id, steam_id, currently_playing_appid')
      .not('steam_id', 'is', null)
      .eq('steam_profile_public', true);

    if (error) throw error;
    if (!users || users.length === 0) {
      return new Response('No linked users found', { status: 200 });
    }

    const chunks = (arr: any[], size: number) =>
      Array.from({ length: Math.ceil(arr.length / size) }, (v, i) =>
        arr.slice(i * size, i * size + size)
      );

    const userChunks = chunks(users, 100);

    for (const batch of userChunks) {
      const steamIds = batch.map((u: any) => u.steam_id).join(',');
      const res = await fetch(`https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=${STEAM_WEB_API_KEY}&steamids=${steamIds}`);
      if (!res.ok) {
        console.error('Steam API error:', await res.text());
        continue;
      }

      const data = await res.json();
      const players = data.response?.players || [];

      for (const player of players) {
        const user = batch.find((u: any) => u.steam_id === player.steamid);
        if (!user) continue;

        const newAppId = player.gameid ? parseInt(player.gameid) : null;
        const changed = newAppId !== user.currently_playing_appid;

        const updateData: any = {
          currently_playing_appid: newAppId,
          currently_playing_name: player.gameextrainfo ?? null,
          steam_presence_updated_at: new Date().toISOString(),
        };

        if (changed) {
          updateData.currently_playing_since = newAppId ? new Date().toISOString() : null;
        }

        await supabase.from('users').update(updateData).eq('id', user.id);
      }

      // courtesy sleep
      await new Promise(r => setTimeout(r, 200));
    }

    return new Response('Presence updated', { status: 200 });
  } catch (error: any) {
    console.error("Error steam-presence-poll:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
