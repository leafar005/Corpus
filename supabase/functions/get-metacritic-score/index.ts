// supabase/functions/get-metacritic-score/index.ts
//
// SCRAPER REAL DE METACRITIC (sin depender de la API de Steam)
// -------------------------------------------------------------
// Estrategia en 2 pasos:
//   1) RESOLVER el slug de metacritic a partir del título del juego,
//      usando el buscador público de metacritic.com/search/{query}/
//      (a menos que ya tengas el slug guardado en tu tabla `games`).
//   2) SCRAPEAR la ficha del juego en metacritic.com/game/{slug}/
//      y extraer metascore, user score, y metadata.
//
// Parseo en cascada (de más a menos fiable):
//   a) JSON embebido tipo Next.js (<script id="__NEXT_DATA__">)
//   b) JSON-LD (<script type="application/ld+json">)
//   c) Fallback por regex sobre el texto plano visible

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ---------------------------------------------------------------------------
// 1. CONFIG: rotación de User-Agents realistas + jitter
// ---------------------------------------------------------------------------

const USER_AGENTS = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
];

function randomUserAgent(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

function delay(ms: number): Promise<void> {
  return new Promise((res) => setTimeout(res, ms));
}

// Jitter moderado para no quemar la IP pero sin impactar UX (300ms–800ms)
function jitter(): Promise<void> {
  const ms = Math.floor(Math.random() * 500) + 300;
  return delay(ms);
}

function buildHeaders(userAgent: string): HeadersInit {
  return {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'no-cache',
    'Referer': 'https://www.metacritic.com/',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
  };
}

function makeLogger(service: string) {
  return (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, unknown> = {}) => {
    console.log(JSON.stringify({ timestamp: new Date().toISOString(), level, service, message, ...meta }));
  };
}
const log = makeLogger('get-metacritic-score');

// ---------------------------------------------------------------------------
// 2. SLUGIFICADO de respaldo
// ---------------------------------------------------------------------------

function slugifyTitle(title: string): string {
  return title
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // quita acentos
    .toLowerCase()
    .replace(/[:''"®™]/g, '')
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// ---------------------------------------------------------------------------
// 3. DETECCIÓN DE BLOQUEO (Cloudflare challenge / rate limit)
// ---------------------------------------------------------------------------

function detectBlocked(status: number, html: string): string | null {
  if (status === 403) return 'HTTP 403 - probablemente bloqueado por Cloudflare';
  if (status === 429) return 'HTTP 429 - rate limited, hay que bajar la frecuencia';
  const lower = html.slice(0, 3000).toLowerCase();
  if (
    lower.includes('just a moment') ||
    lower.includes('cf-browser-verification') ||
    lower.includes('checking your browser')
  ) {
    return 'Cloudflare challenge page detectada en el body';
  }
  return null;
}

// ---------------------------------------------------------------------------
// 4. FETCH con reintento simple (2 reintentos con backoff si hay 429/503)
// ---------------------------------------------------------------------------

async function fetchWithRetry(url: string, attempt = 0): Promise<{ status: number; html: string }> {
  const ua = randomUserAgent();
  const res = await fetch(url, { headers: buildHeaders(ua) });
  const html = await res.text();

  if ((res.status === 429 || res.status === 503) && attempt < 2) {
    const backoffMs = 3000 * (attempt + 1);
    log('WARN', 'Reintentando tras backoff', { url, status: res.status, attempt, backoffMs });
    await delay(backoffMs);
    return fetchWithRetry(url, attempt + 1);
  }

  return { status: res.status, html };
}

// ---------------------------------------------------------------------------
// 5. RESOLVER SLUG a partir del título, usando el buscador de metacritic
// ---------------------------------------------------------------------------

interface SearchResult {
  slug: string;
  title: string;
  url: string;
}

async function searchMetacriticSlug(gameTitle: string): Promise<SearchResult | null> {
  const query = encodeURIComponent(gameTitle.trim());
  const searchUrl = `https://www.metacritic.com/search/${query}/`;

  await jitter();
  const { status, html } = await fetchWithRetry(searchUrl);

  const blocked = detectBlocked(status, html);
  if (blocked) {
    log('ERROR', 'Bloqueado al buscar slug', { gameTitle, status, blocked });
    throw new Error(`Metacritic bloqueó la búsqueda: ${blocked}`);
  }

  // Buscamos enlaces a fichas de juego: /game/{slug}/
  const linkPattern = /href="\/game\/([a-z0-9-]+)\/?"/gi;
  const candidates: string[] = [];
  let match;
  while ((match = linkPattern.exec(html)) !== null) {
    if (!candidates.includes(match[1])) candidates.push(match[1]);
  }

  if (candidates.length === 0) {
    log('WARN', 'Sin candidatos de slug en la búsqueda', { gameTitle, htmlLength: html.length });
    return null;
  }

  // El primer resultado es normalmente el más relevante
  const bestSlug = candidates[0];
  return {
    slug: bestSlug,
    title: gameTitle,
    url: `https://www.metacritic.com/game/${bestSlug}/`,
  };
}

// ---------------------------------------------------------------------------
// 6. PARSEO EN CASCADA de la ficha del juego
// ---------------------------------------------------------------------------

interface MetacriticData {
  slug: string;
  url: string;
  metascore: number | null;
  metascore_label: string | null; // "Universal Acclaim", "Generally Favorable", etc.
  critic_review_count: number | null;
  user_score: number | null;
  user_rating_count: number | null;
  parse_strategy: 'next_data' | 'json_ld' | 'regex_fallback' | 'none';
}

function deepFindAll(obj: unknown, key: string, results: unknown[] = []): unknown[] {
  if (obj === null || typeof obj !== 'object') return results;
  if (key in (obj as Record<string, unknown>)) {
    results.push((obj as Record<string, unknown>)[key]);
  }
  for (const k of Object.keys(obj as Record<string, unknown>)) {
    deepFindAll((obj as Record<string, unknown>)[k], key, results);
  }
  return results;
}

function deepFindScoreSummary(json: unknown, key: string): any {
  const candidates = deepFindAll(json, key);
  return candidates.find(
    (c) => c !== null && typeof c === 'object' && typeof (c as any).score === 'number',
  ) ?? null;
}

function tryParseNextData(html: string): Partial<MetacriticData> | null {
  const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) return null;
  try {
    const json = JSON.parse(m[1]);
    const critic = deepFindScoreSummary(json, 'criticScoreSummary');
    const user = deepFindScoreSummary(json, 'userScoreSummary');

    if (!critic && !user) return null;

    return {
      metascore: critic ? critic.score : null,
      user_score: user ? user.score : null,
      critic_review_count: typeof critic?.reviewCount === 'number' ? critic.reviewCount : null,
      user_rating_count: typeof user?.reviewCount === 'number' ? user.reviewCount : null,
      metascore_label: typeof critic?.label === 'string' ? critic.label : null,
      parse_strategy: 'next_data',
    };
  } catch (e) {
    log('WARN', 'Fallo parseando __NEXT_DATA__ como JSON', { error: String(e) });
    return null;
  }
}

function tryParseJsonLd(html: string): Partial<MetacriticData> | null {
  const scripts = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
  for (const s of scripts) {
    try {
      const json = JSON.parse(s[1]);
      const rating = json.aggregateRating;
      // El campo real es "reviewCount", no "ratingCount".
      const reviewCount = Number(rating?.reviewCount ?? 0);
      if (rating && rating.ratingValue != null && reviewCount >= 4) {
        return {
          metascore: Math.round(parseFloat(rating.ratingValue)),
          critic_review_count: reviewCount || null,
          parse_strategy: 'json_ld',
        };
      }
    } catch {
      continue;
    }
  }
  return null;
}

function tryParseRegexFallback(html: string): Partial<MetacriticData> | null {
  // Metascore: demasiado propenso a falsos positivos, lo desactivamos aquí.
  // Solo confiamos en next_data / json_ld para el número de crítica.
  const userScoreMatch = html.match(/User [Ss]core[\s\S]{0,80}?(\d{1,2}(?:\.\d)?)/);
  const userCountMatch = html.match(/Based on ([\d,]+) User Ratings?/i);

  if (!userScoreMatch) return null;

  return {
    user_score: parseFloat(userScoreMatch[1]),
    user_rating_count: userCountMatch ? parseInt(userCountMatch[1].replace(/,/g, '')) : null,
    parse_strategy: 'regex_fallback',
  };
}

async function scrapeMetacriticGame(slug: string, url: string): Promise<MetacriticData> {
  const { status, html } = await fetchWithRetry(url);

  const blocked = detectBlocked(status, html);
  if (blocked) {
    log('ERROR', 'Bloqueado al scrapear ficha de juego', { slug, status, blocked });
    throw new Error(`Metacritic bloqueó el scraping de la ficha: ${blocked}`);
  }
  if (status === 404) {
    throw new Error(`Ficha no encontrada (404) para el slug "${slug}"`);
  }



  const base: MetacriticData = {
    slug,
    url,
    metascore: null,
    metascore_label: null,
    critic_review_count: null,
    user_score: null,
    user_rating_count: null,
    parse_strategy: 'none',
  };

  // Ejecutamos SIEMPRE las tres, en orden de fiabilidad
  const nextData = tryParseNextData(html);
  const jsonLd = tryParseJsonLd(html);
  const fallback = tryParseRegexFallback(html);
  const results = [nextData, jsonLd, fallback];

  const merged: MetacriticData = { ...base };
  let metascoreStrategy: MetacriticData['parse_strategy'] = 'none';
  let userScoreStrategy: MetacriticData['parse_strategy'] = 'none';

  for (const r of results) {
    if (!r) continue;
    if (merged.metascore === null && r.metascore != null) {
      merged.metascore = r.metascore;
      merged.metascore_label = r.metascore_label ?? merged.metascore_label;
      merged.critic_review_count = r.critic_review_count ?? merged.critic_review_count;
      metascoreStrategy = r.parse_strategy!;
    }
    if (merged.user_score === null && r.user_score != null) {
      merged.user_score = r.user_score;
      merged.user_rating_count = r.user_rating_count ?? merged.user_rating_count;
      userScoreStrategy = r.parse_strategy!;
    }
  }

  // Si NINGÚN campo se resolvió, es 'none' de verdad
  merged.parse_strategy = metascoreStrategy !== 'none' ? metascoreStrategy
                          : userScoreStrategy !== 'none' ? userScoreStrategy
                          : 'none';

  // No confiamos en el metascore si SOLO vino del regex de última instancia:
  // lo devolvemos igual al front (mejor un dato dudoso visible que nada),
  // pero marcamos que no se debe persistir en BD.
  (merged as any)._metascoreLowConfidence = metascoreStrategy === 'regex_fallback';

  if (results.every((r) => r === null)) {
    log('ERROR', 'Ninguna estrategia de parseo encontró datos', { slug, htmlPreview: html.slice(0, 1500) });
  } else {
    log('INFO', 'Parseo exitoso', { slug, metascoreStrategy, userScoreStrategy });
  }

  return merged;
}

// ---------------------------------------------------------------------------
// 7. HANDLER PRINCIPAL
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('No authorization header provided');

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) throw new Error('Unauthorized');

    const body = await req.json();
    // gameId: id interno en tu tabla `games` (para cachear el resultado)
    // gameTitle: título del juego para resolver el slug via búsqueda
    // metacriticSlug: si ya tienes el slug cacheado, omite la búsqueda
    const gameId: string | undefined = body?.gameId;
    const gameTitle: string | undefined = body?.gameTitle;
    const metacriticSlug: string | undefined = body?.metacriticSlug;

    if (!gameTitle && !metacriticSlug) {
      throw new Error('Debes proporcionar gameTitle o metacriticSlug');
    }

    let resolved: { slug: string; url: string };

    if (metacriticSlug) {
      // Slug ya conocido — ir directo a la ficha
      resolved = { slug: metacriticSlug, url: `https://www.metacritic.com/game/${metacriticSlug}/` };
    } else {
      // Primero intentamos el slug "adivinado" (1 request). Si falla,
      // recurrimos al buscador (1 request extra).
      const guessedSlug = slugifyTitle(gameTitle!);
      const guessedUrl = `https://www.metacritic.com/game/${guessedSlug}/`;

      await jitter();
      const guessRes = await fetchWithRetry(guessedUrl);

      if (guessRes.status === 200 && !detectBlocked(guessRes.status, guessRes.html)) {
        log('INFO', 'Slug adivinado directamente funcionó', { gameTitle, guessedSlug });
        resolved = { slug: guessedSlug, url: guessedUrl };
      } else {
        log('INFO', 'Slug adivinado falló, recurriendo al buscador', {
          gameTitle,
          guessedSlug,
          status: guessRes.status,
        });
        const searchResult = await searchMetacriticSlug(gameTitle!);
        if (!searchResult) {
          throw new Error(`No se encontró ninguna ficha de Metacritic para "${gameTitle}"`);
        }
        resolved = searchResult;
      }
    }

    const data = await scrapeMetacriticGame(resolved.slug, resolved.url);

    // Guardar en BD si tenemos datos válidos (lazy backfill)
    if (gameId && data.parse_strategy !== 'none' && !(data as any)._metascoreLowConfidence) {
      const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ?? '';
      const supabase = createClient(supabaseUrl, SUPABASE_SERVICE_ROLE_KEY);

      const { error: updateError } = await supabase
        .from('games')
        .update({
          metacritic_slug: data.slug,
          metacritic_score: data.metascore,
          metacritic_url: data.url,
          metacritic_user_score: data.user_score,
          metacritic_updated_at: new Date().toISOString(),
        })
        .eq('igdb_id', gameId);

      if (updateError) {
        log('ERROR', 'Error guardando en la tabla games', { error: updateError.message });
      }
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    log('ERROR', 'Error fatal en get-metacritic-score', { error: message });
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
