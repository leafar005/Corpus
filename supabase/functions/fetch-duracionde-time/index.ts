// supabase/functions/fetch-duracionde-time/index.ts
//
// Scraper de duracionde.com para obtener tiempos de duración de juegos.
// Estrategia:
//   1. Caché 30 días en games.duracionde_time para no machacar el sitio.
//   2. Slugify del título → GET https://duracionde.com/{slug}
//   3. Parseo del JSON-LD <script type="application/ld+json"> con @type VideoGame
//      → additionalProperty[]: Main Story, Main + Extras, Completionist (en ISO 8601)
//   4. Si falla (404 / sin datos) → { found: false } guardado igualmente en caché.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const USER_AGENTS = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0",
];

function randomUA(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

function jitter(): Promise<void> {
  const ms = Math.floor(Math.random() * 400) + 200;
  return new Promise((r) => setTimeout(r, ms));
}

function log(
  level: "INFO" | "WARN" | "ERROR",
  msg: string,
  meta: Record<string, unknown> = {}
) {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      service: "fetch-duracionde-time",
      msg,
      ...meta,
    })
  );
}

// ---------------------------------------------------------------------------
// Slugify: mismo algoritmo que Metacritic para consistencia
// ---------------------------------------------------------------------------

function slugify(title: string): string {
  return title
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // quita diacríticos/tildes
    .toLowerCase()
    .replace(/[:'"®™©·]/g, "")       // quita puntuación problemática
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, "-")    // cualquier otro char → guión
    .replace(/^-+|-+$/g, "");       // recorta guiones iniciales/finales
}

// ---------------------------------------------------------------------------
// Parseo de ISO 8601 duration (PT26H58M41S → 26.97 horas)
// ---------------------------------------------------------------------------

function parseDuration(iso: string | null | undefined): number | null {
  if (!iso) return null;
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return null;
  const h = parseInt(m[1] ?? "0", 10);
  const min = parseInt(m[2] ?? "0", 10);
  const sec = parseInt(m[3] ?? "0", 10);
  const total = h + min / 60 + sec / 3600;
  return total > 0 ? Math.round(total * 10) / 10 : null;
}

// ---------------------------------------------------------------------------
// Parseo del JSON-LD con @type VideoGame
// ---------------------------------------------------------------------------

interface DuracionResult {
  found: boolean;
  slug?: string;
  matched_title?: string;
  main?: number | null;
  main_extra?: number | null;
  completionist?: number | null;
  checked_at: string;
}

function parseJsonLd(html: string, slug: string, title: string): DuracionResult {
  const now = new Date().toISOString();

  // Extraemos todos los bloques JSON-LD de la página
  const scripts = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];

  for (const s of scripts) {
    let json: Record<string, unknown>;
    try {
      json = JSON.parse(s[1]);
    } catch {
      continue;
    }

    // Buscamos el bloque VideoGame
    if (json["@type"] !== "VideoGame") continue;

    const props = json["additionalProperty"] as Array<{
      name: string;
      value: string;
    }> | undefined;

    if (!props || !Array.isArray(props)) continue;

    const findProp = (name: string) =>
      props.find((p) => p.name === name)?.value ?? null;

    const main = parseDuration(findProp("Main Story"));
    const mainExtra = parseDuration(findProp("Main + Extras"));
    const completionist = parseDuration(findProp("Completionist"));

    if (main !== null || mainExtra !== null || completionist !== null) {
      log("INFO", "JSON-LD parseado con éxito", { slug, main, mainExtra, completionist });
      return {
        found: true,
        slug,
        matched_title: (json["name"] as string | undefined) ?? title,
        main,
        main_extra: mainExtra,
        completionist,
        checked_at: now,
      };
    }

    // El bloque VideoGame existe pero no tiene additionalProperty con tiempos
    // (juego sin datos suficientes en el sitio)
    log("WARN", "VideoGame JSON-LD encontrado pero sin tiempos", { slug });
    return { found: false, checked_at: now };
  }

  log("WARN", "No se encontró bloque VideoGame en JSON-LD", { slug });
  return { found: false, checked_at: now };
}

// ---------------------------------------------------------------------------
// Handler principal
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Autenticación: requerimos un usuario válido (no es una función pública)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No authorization header");

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) throw new Error("Unauthorized");

    // Usamos service role para operaciones de BD
    const supabase = createClient(supabaseUrl, serviceKey);

    // Input
    const body = await req.json();
    const igdbId = parseInt(body?.igdb_id ?? body?.igdbId ?? "0", 10);
    const title = (body?.title ?? "").toString().trim();

    if (!Number.isInteger(igdbId) || igdbId <= 0 || !title) {
      return new Response(
        JSON.stringify({ error: "igdb_id y title son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Caché de 30 días: si ya tenemos datos recientes, los devolvemos sin llamar al sitio
    const { data: existing } = await supabase
      .from("games")
      .select("duracionde_time")
      .eq("igdb_id", igdbId)
      .maybeSingle();

    const cached = existing?.duracionde_time as DuracionResult | null;
    if (cached?.checked_at) {
      const diffDays =
        (Date.now() - new Date(cached.checked_at).getTime()) / 86_400_000;
      if (diffDays < 30) {
        log("INFO", "Devolviendo caché", { igdbId, diffDays: diffDays.toFixed(1) });
        return new Response(JSON.stringify(cached), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // Slug y fetch
    const slug = slugify(title);
    const url = `https://duracionde.com/${slug}`;
    log("INFO", "Fetching", { igdbId, title, slug, url });

    await jitter();

    const res = await fetch(url, {
      headers: {
        "User-Agent": randomUA(),
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "es-ES,es;q=0.9",
        "Cache-Control": "no-cache",
      },
      redirect: "follow",
    });

    const now = new Date().toISOString();
    let result: DuracionResult;

    if (res.status === 404) {
      log("WARN", "404 - juego no encontrado en duracionde.com", { slug });
      result = { found: false, checked_at: now };
    } else if (!res.ok) {
      log("ERROR", "Respuesta no OK", { slug, status: res.status });
      result = { found: false, checked_at: now };
    } else {
      const html = await res.text();
      result = parseJsonLd(html, slug, title);
    }

    // Upsert en BD (siempre guardamos, aunque sea found:false, para evitar re-intentos)
    const { error: upsertError } = await supabase
      .from("games")
      .update({ duracionde_time: result })
      .eq("igdb_id", igdbId);

    if (upsertError) {
      // Si no existe aún en la tabla games, hacemos upsert completo
      await supabase
        .from("games")
        .upsert({ igdb_id: igdbId, title, duracionde_time: result }, {
          onConflict: "igdb_id",
        });
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    log("ERROR", "Error fatal", { error: msg });
    return new Response(JSON.stringify({ error: msg }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
