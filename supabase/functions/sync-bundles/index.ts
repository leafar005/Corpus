import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const IGDB_CLIENT_ID = Deno.env.get('IGDB_CLIENT_ID') ?? '';
const IGDB_CLIENT_SECRET = Deno.env.get('IGDB_CLIENT_SECRET') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Blacklist (A)
const BLACKLIST = [
  'coupon', 'voucher', 'discount', 'ign plus', 'dc universe', '1-month', '3-month',
  'membership', 'subscription', 'soundtrack', 'artbook', 'audio_only', 'stl', '3d print',
  'null', 'juego desconocido', 'bundle sin título'
];

function isBlacklisted(title: string): boolean {
  const lower = title.toLowerCase().trim();
  if (!lower) return true;
  for (const word of BLACKLIST) {
    if (lower.includes(word)) return true;
  }
  return false;
}

// Sanitizer (B)
function sanitizeTitle(title: string): string {
  return title
    .replace(/\s*-?\s*(Digital\s+)?Deluxe\s+Edition.*$/i, '')
    .replace(/\s*-?\s*Game\s+of\s+the\s+Year\s+Edition.*$/i, '')
    .replace(/\s*-?\s*Collector(')?s\s+Edition.*$/i, '')
    .replace(/\s*-?\s*Expansion\s+Standalone.*$/i, '')
    .replace(/\s*-?\s*Premium\s+Edition.*$/i, '')
    .replace(/\s*-?\s*Ultimate\s+Edition.*$/i, '')
    .replace(/\s*-?\s*Complete\s+Edition.*$/i, '')
    .replace(/\s*\(.*?\)/g, '')
    .replace(/\s*\[.*?\]/g, '')
    .replace(/-/g, ' ')
    .trim();
}

// Global IGDB Auth State
let igdbToken = '';
let tokenExpiration = 0;

async function getIgdbToken(): Promise<string> {
  const now = Date.now();
  if (igdbToken && now < tokenExpiration) return igdbToken;

  const res = await fetch(`https://id.twitch.tv/oauth2/token?client_id=${IGDB_CLIENT_ID}&client_secret=${IGDB_CLIENT_SECRET}&grant_type=client_credentials`, { method: 'POST' });
  if (!res.ok) throw new Error('Failed to get IGDB token');
  const data = await res.json();
  igdbToken = data.access_token;
  tokenExpiration = now + ((data.expires_in - 300) * 1000);
  return igdbToken;
}

async function igdbRequest(bodyQuery: string): Promise<any[]> {
  const token = await getIgdbToken();
  const res = await fetch('https://api.igdb.com/v4/games', {
    method: 'POST',
    headers: {
      'Client-ID': IGDB_CLIENT_ID,
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/json',
    },
    body: bodyQuery
  });
  if (!res.ok) {
    console.error('IGDB Error:', await res.text());
    return [];
  }
  return await res.json();
}

const IGDB_FIELDS = 'fields name, cover.image_id, first_release_date, summary, category, game_type, parent_game, total_rating_count, genres.name, themes.name, game_modes.name, player_perspectives.name, platforms.name, involved_companies.developer, involved_companies.company.name, screenshots.image_id, artworks.image_id, videos.video_id, collection.id, collection.name, franchises.id, franchises.name, game_engines.name, external_games.uid, external_games.category;';

serve(async (req) => {
  const FUNCTION_START = Date.now();
  const TIME_BUDGET_MS = 120_000; // dejamos margen bajo los 150s del límite

  function timeLeft(): number {
    return TIME_BUDGET_MS - (Date.now() - FUNCTION_START);
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log("Fetching active bundles from Barter.vg...");
    const barterRes = await fetch('https://barter.vg/bundles/json/', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    });
    if (!barterRes.ok) throw new Error("Failed to fetch barter.vg");
    const decoded = await barterRes.json();

    console.log(`Barter.vg respondió con status ${barterRes.status}`);
    console.log(`Tipo de 'decoded': ${typeof decoded}, claves top-level: ${decoded ? Object.keys(decoded).join(', ') : 'null'}`);

    let rawBundles = decoded;
    if (decoded && decoded.bundles) {
      rawBundles = decoded.bundles;
    } else if (decoded && decoded.data) {
      rawBundles = decoded.data;
    }

    const totalBundleKeys = Object.keys(rawBundles || {}).length;
    console.log(`Total de bundles recibidos de barter.vg (antes de filtrar por tienda): ${totalBundleKeys}`);

    const activeBundles: any[] = [];
    const resolvedMap: Record<string, any> = {};

    const steamIdsToResolve: Set<number> = new Set();
    const titlesToResolve: Set<string> = new Set();

    // Parse bundles and collect items
    let matchedStoreCount = 0;
    for (const [bundleId, bundleData] of Object.entries(rawBundles)) {
      const b = bundleData as any;
      if (!b || typeof b !== 'object') continue;

      const fullString = JSON.stringify(b).toLowerCase();
      const isHumble = fullString.includes('humble');
      const isFanatical = fullString.includes('fanatical');
      if (!isHumble && !isFanatical) continue;
      matchedStoreCount++;

      const rawGamesDebug = b.games || b.items;
      console.log(`[DEBUG bundle ${bundleId}] claves top-level: ${Object.keys(b).join(', ')}`);
      console.log(`[DEBUG bundle ${bundleId}] tipo de games/items: ${typeof rawGamesDebug}, valor: ${JSON.stringify(rawGamesDebug)?.slice(0, 300)}`);

      const meta = b.meta || {};
      const title = meta.title || b.title || b.name || `Bundle ${bundleId}`;
      if (isBlacklisted(title)) continue;

      const rawGames = b.games || b.items;
      if (rawGames && typeof rawGames === 'object') {
        for (const [itemId, item] of Object.entries(rawGames) as any[]) {
          let steamAppId = 0;
          const gameType = parseInt(item.type || '1');
          if (gameType === 2 && item.included && typeof item.included === 'object') {
            const keys = Object.keys(item.included).sort((x, y) => parseInt(x) - parseInt(y));
            if (keys.length > 0) {
              const baseId = item.included[keys[0]];
              steamAppId = parseInt(baseId || '0');
            }
          }
          if (!steamAppId) {
            steamAppId = parseInt(item.id || item.steam_app_id || item.appid || item.steam_id || '0');
          }

          const itemTitle = item.title || item.name || item.game_title || 'Juego Desconocido';

          if (steamAppId > 0) {
            steamIdsToResolve.add(steamAppId);
          } else if (itemTitle !== 'Juego Desconocido' && !isBlacklisted(itemTitle)) {
            titlesToResolve.add(itemTitle);
          }
        }
      }
    }

    console.log(`Bundles que coinciden con Humble/Fanatical: ${matchedStoreCount}`);
    console.log(`Need to resolve ${steamIdsToResolve.size} Steam IDs and ${titlesToResolve.size} Titles`);

    // Resolver el ID exacto de "Steam" en la tabla de referencia (evita problemas de mayúsculas/formato)
    let steamSourceId: number | null = null;
    {
      const token = await getIgdbToken();
      const res = await fetch('https://api.igdb.com/v4/external_game_sources', {
        method: 'POST',
        headers: {
          'Client-ID': IGDB_CLIENT_ID,
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
        },
        body: 'fields id, name; limit 50;'
      });
      const text = await res.text();
      console.log(`[external_game_sources] status=${res.status} body=${text}`);

      if (res.ok) {
        const sources = JSON.parse(text);
        const steamSource = sources.find((s: any) => s.name?.toLowerCase() === 'steam');
        if (steamSource) {
          steamSourceId = steamSource.id;
          console.log(`Steam source ID encontrado: ${steamSourceId}`);
        } else {
          console.warn('No se encontró "steam" en external_game_sources:', JSON.stringify(sources));
        }
      }
    }

    // LAYER 1: Resolve by Steam ID in IGDB
    const steamIdsArr = Array.from(steamIdsToResolve);
    const steamIdToIgdbId: Record<number, number> = {};
    for (let i = 0; i < steamIdsArr.length; i += 50) {
      const chunk = steamIdsArr.slice(i, i + 50);
      const orConditions = chunk.map(id => `uid = "${id}"`).join(' | ');

      // Si encontramos el ID, filtramos por ID (robusto). Si no, fallback a category=1 (deprecado pero mejor que nada)
      const sourceFilter = steamSourceId !== null
        ? `external_game_source = ${steamSourceId}`
        : `category = 1`;

      const query = `fields uid, game; where ${sourceFilter} & (${orConditions}); limit 500;`;

      const token = await getIgdbToken();
      const res = await fetch('https://api.igdb.com/v4/external_games', {
        method: 'POST',
        headers: {
          'Client-ID': IGDB_CLIENT_ID,
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
        },
        body: query
      });

      const responseText = await res.text();
      console.log(`[LAYER1] chunk ${i}-${i + 50}: status=${res.status}, body_len=${responseText.length}, preview=${responseText.slice(0, 200)}`);

      if (res.ok) {
        const extGames = JSON.parse(responseText);
        for (const ext of extGames) {
          if (ext.uid && ext.game) {
            steamIdToIgdbId[parseInt(ext.uid)] = ext.game;
          }
        }
      }
    }

    const igdbIdsToFetch = Array.from(new Set(Object.values(steamIdToIgdbId)));
    const igdbIdToGameMap: Record<number, any> = {};

    for (let i = 0; i < igdbIdsToFetch.length; i += 100) {
      const chunk = igdbIdsToFetch.slice(i, i + 100);
      const query = `${IGDB_FIELDS} where id = (${chunk.join(',')}); limit 500;`;
      const igdbGames = await igdbRequest(query);
      for (const game of igdbGames) {
        igdbIdToGameMap[game.id] = game;
      }
    }

    // Populate resolvedMap with steam: steam_app_id -> game object
    for (const [steamIdStr, igdbId] of Object.entries(steamIdToIgdbId)) {
      const game = igdbIdToGameMap[igdbId];
      if (game) {
        resolvedMap[`steam:${steamIdStr}`] = game;
      }
    }

    // Identify which Steam IDs failed Layer 1
    const failedSteamIds = steamIdsArr.filter(id => !resolvedMap[`steam:${id}`]);
    console.log(`${failedSteamIds.length} Steam IDs failed IGDB resolution. Moving to Layer 3 for these.`);

    // Helper to sleep
    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    // LAYER 3: Steam Store API Fallback (con presupuesto de tiempo y concurrencia limitada)
    const CONCURRENCY = 8;
    let idx = 0;

    async function resolveOne(appId: number) {
      try {
        const res = await fetch(`https://store.steampowered.com/api/appdetails?appids=${appId}&l=spanish`);
        if (res.status === 429) return; // sin reintento: si nos limitan, seguimos con el resto
        if (res.ok) {
          const jsonResp = await res.json();
          const appData = jsonResp[appId.toString()];
          if (appData && appData.success === true) {
            const data = appData.data;
            const type = (data.type || '').toString().toLowerCase();
            if (type === 'game') {
              const genres = data.genres || [];
              const genreNames = genres.map((g: any) => g.description);
              resolvedMap[`steam:${appId}`] = {
                id: appId,
                igdb_id: null,
                name: data.name || 'Juego de Steam',
                title: data.name || 'Juego de Steam',
                cover_url: data.header_image || data.capsule_image || '',
                developer: data.developers?.length > 0 ? data.developers[0] : 'Desconocido',
                summary: data.short_description || data.detailed_description || 'Sin descripción disponible.',
                platforms: ['PC (Steam)'],
                genres: genreNames,
                release_date: data.release_date?.date,
                steam_app_id: appId
              };
            }
          }
        }
      } catch (e) {
        console.error(`Steam API fallback failed for appId ${appId}:`, e);
      }
    }

    console.log(`Empezando Layer 3 con presupuesto de ${timeLeft()}ms restantes para ${failedSteamIds.length} IDs`);

    while (idx < failedSteamIds.length && timeLeft() > 5000) {
      const batch = failedSteamIds.slice(idx, idx + CONCURRENCY);
      await Promise.all(batch.map(resolveOne));
      idx += CONCURRENCY;
    }

    if (idx < failedSteamIds.length) {
      console.warn(`Layer 3 cortada por presupuesto de tiempo: resueltos hasta índice ${idx} de ${failedSteamIds.length}`);
    }

    // Now Layer 2 for items without Steam IDs
    const titlesArr = Array.from(titlesToResolve);
    for (const rawTitle of titlesArr) {
      if (timeLeft() < 5000) {
        console.warn('Layer 2 cortada por presupuesto de tiempo');
        break;
      }
      if (isBlacklisted(rawTitle)) continue;
      const cleanTitle = sanitizeTitle(rawTitle);
      if (!cleanTitle) continue;

      const query = `${IGDB_FIELDS} search "${cleanTitle}"; limit 1;`;
      const igdbGames = await igdbRequest(query);
      if (igdbGames.length > 0) {
        resolvedMap[`title:${rawTitle}`] = igdbGames[0];
      }
    }

    console.log(`Total resuelto en resolvedMap: ${Object.keys(resolvedMap).length} de ${steamIdsArr.length + titlesArr.length} intentados`);

    // D. Assembly & Destruction
    const parsedBundles: any[] = [];

    for (const [bundleId, bundleData] of Object.entries(rawBundles)) {
      const b = bundleData as any;
      if (!b || typeof b !== 'object') continue;

      const fullString = JSON.stringify(b).toLowerCase();
      const isHumble = fullString.includes('humble');
      const isFanatical = fullString.includes('fanatical');
      if (!isHumble && !isFanatical) continue;

      const meta = b.meta || {};
      const title = meta.title || b.title || b.name || `Bundle ${bundleId}`;
      if (isBlacklisted(title)) continue;

      const storeName = isHumble ? 'Humble Bundle' : 'Fanatical';
      const url = meta.url || b.url || b.bundle_url || `https://barter.vg/bundle/${bundleId}/`;

      let endDate = null;
      const endRaw = meta.end || b.end;
      if (endRaw) {
        const endStr = endRaw.toString().trim();
        if (endStr !== '0' && endStr.length > 0 && endStr !== 'null') {
          const endTimestamp = parseInt(endStr);
          if (endTimestamp > 0) {
            const isSeconds = endStr.length <= 10;
            const ms = isSeconds ? endTimestamp * 1000 : endTimestamp;
            endDate = new Date(ms).toISOString();
          }
        }
      }

      // 👇 NUEVO: descartar bundles ya caducados (con 24h de margen por husos horarios)
      if (endDate) {
        const endDateObj = new Date(endDate);
        const graceperiod = new Date(Date.now() - 24 * 60 * 60 * 1000);
        if (endDateObj < graceperiod) {
          continue; // saltamos este bundle, ya caducó
        }
      }

      const rawGames = b.games || b.items;
      if (!rawGames || typeof rawGames !== 'object') continue;

      const gamesByTier: Record<number, any[]> = {};

      for (const [itemId, item] of Object.entries(rawGames) as any[]) {
        const itemTitle = item.title || item.name || item.game_title || 'Juego Desconocido';
        let steamAppId = 0;
        const gameType = parseInt(item.type || '1');
        if (gameType === 2 && item.included && typeof item.included === 'object') {
          const keys = Object.keys(item.included).sort((x, y) => parseInt(x) - parseInt(y));
          if (keys.length > 0) {
            const baseId = item.included[keys[0]];
            steamAppId = parseInt(baseId || '0');
          }
        }
        if (!steamAppId) {
          steamAppId = parseInt(item.id || item.steam_app_id || item.appid || item.steam_id || '0');
        }

        let resolvedGame = null;
        if (steamAppId > 0 && resolvedMap[`steam:${steamAppId}`]) {
          resolvedGame = resolvedMap[`steam:${steamAppId}`];
        } else if (resolvedMap[`title:${itemTitle}`]) {
          resolvedGame = resolvedMap[`title:${itemTitle}`];
        }

        if (resolvedGame) {
          const clonedGame = { ...resolvedGame };
          const coverId = clonedGame.cover?.image_id;
          if (coverId && !clonedGame.cover_url) {
            clonedGame.cover_url = `https://images.igdb.com/igdb/image/upload/t_cover_big/${coverId}.jpg`;
          }
          if (!clonedGame.title) {
            clonedGame.title = clonedGame.name;
          }

          if (isBlacklisted(clonedGame.title || clonedGame.name || '')) continue;

          const tierId = isHumble ? parseInt(item.tier || '1') : 1;
          if (!gamesByTier[tierId]) gamesByTier[tierId] = [];
          gamesByTier[tierId].push(clonedGame);
        }
      }

      const parsedTiers: any[] = [];
      const tiersMap = b.tiers || b.tier || b.prices || b.levels || {};

      for (const [tierIdStr, games] of Object.entries(gamesByTier)) {
        if (games.length === 0) continue;
        const tierId = parseInt(tierIdStr);
        const tDef = tiersMap[tierIdStr] || {};

        const tierName = tDef.name || `Tier ${tierId}`;
        let price: number | null = null;

        const rawPrice = tDef.price_eur || tDef.price_usd || tDef.price || tDef.cost || tDef.min_price || b.price_eur || b.price_usd || b.price || b.cost;
        if (rawPrice) {
          const s = rawPrice.toString().replace(/[$€£a-z]/gi, '').trim().replace(',', '.');
          const val = parseFloat(s);
          if (val > 0) price = val;
        }
        if (!price) {
          const match = tierName.match(/(\d+(?:\.\d+)?)\s*(?:€|\$|USD|EUR)|(?:€|\$|USD|EUR)\s*(\d+(?:\.\d+)?)/i);
          if (match) {
            const strNum = match[1] || match[2];
            if (strNum) price = parseFloat(strNum.replace(',', '.'));
          }
        }

        parsedTiers.push({
          name: tierName,
          price: price,
          games: games
        });
      }

      if (parsedTiers.length > 0) {
        parsedBundles.push({
          id: bundleId,
          title: title,
          store_name: storeName,
          url: url,
          end_date: endDate,
          tiers: parsedTiers
        });
      }
    }

    // Upsert into Supabase
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (parsedBundles.length > 0) {
      // 1. Upsert current bundles
      const { error: upsertError } = await supabase
        .from('active_bundles')
        .upsert(parsedBundles, { onConflict: 'id' });

      if (upsertError) throw upsertError;

      // 2. Delete bundles that are no longer active
      const currentIds = parsedBundles.map(b => b.id);
      const { error: deleteError } = await supabase
        .from('active_bundles')
        .delete()
        .not('id', 'in', `(${currentIds.map(id => `"${id}"`).join(',')})`);

      if (deleteError) {
        console.error('Error borrando bundles obsoletos:', deleteError);
      }
    } else {
      console.warn('parsedBundles vacío — no se ejecuta la limpieza para evitar borrar todo por error.');
    }

    return new Response(JSON.stringify({ success: true, processed: parsedBundles.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("Error sync-bundles:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
})
