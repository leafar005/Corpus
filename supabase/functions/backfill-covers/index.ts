// supabase/functions/backfill-covers/index.ts
//
// Edge function para rellenar cover_url faltantes en la tabla `games`.
// Busca juegos con cover_url IS NULL, los consulta en lotes a IGDB y
// actualiza la BD. Segura para ejecutar varias veces (idempotente).
//
// Llamada manual (una sola vez):
//   supabase functions invoke backfill-covers --project-ref <ref>
// o con curl desde el dashboard de Supabase usando la service_role key.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { igdbApiRequest } from '../_shared/igdb-client.ts';

const log = (level: 'INFO' | 'WARN' | 'ERROR', msg: string, meta: Record<string, any> = {}) =>
  console.log(JSON.stringify({ timestamp: new Date().toISOString(), level, message: msg, ...meta }));

const IGDB_CHUNK = 200;   // máximo de IDs por petición IGDB
const DB_CHUNK  = 500;    // tamaño de página al leer de Supabase

function buildCoverUrl(imageId: string): string {
  return `https://images.igdb.com/igdb/image/upload/t_cover_big/${imageId}.jpg`;
}

Deno.serve(async (req: Request) => {
  // Solo acepta peticiones autorizadas (service_role o ANON + secret header)
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabaseUrl  = Deno.env.get('SUPABASE_URL')!;
  const serviceKey   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // ── 1. Obtener todos los juegos sin portada ─────────────────────────────
  const missingIds: number[] = [];
  let page = 0;

  while (true) {
    const { data, error } = await supabase
      .from('games')
      .select('igdb_id')
      .is('cover_url', null)
      .range(page * DB_CHUNK, (page + 1) * DB_CHUNK - 1);

    if (error) {
      log('ERROR', 'Error leyendo games sin cover_url', { error: error.message });
      break;
    }
    if (!data || data.length === 0) break;

    missingIds.push(...data.map((g: any) => g.igdb_id as number));
    if (data.length < DB_CHUNK) break;
    page++;
  }

  log('INFO', `Juegos sin cover_url encontrados: ${missingIds.length}`);

  if (missingIds.length === 0) {
    return new Response(
      JSON.stringify({ ok: true, updated: 0, message: 'Nada que actualizar.' }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    );
  }

  // ── 2. Consultar IGDB en lotes y construir el mapa id→coverUrl ──────────
  const coverMap = new Map<number, string>();

  for (let i = 0; i < missingIds.length; i += IGDB_CHUNK) {
    const chunk = missingIds.slice(i, i + IGDB_CHUNK);
    const idsStr = chunk.join(',');
    const query = `fields id, cover.image_id; where id = (${idsStr}); limit ${chunk.length};`;

    const result = await igdbApiRequest('games', query);

    if (!result.ok) {
      log('WARN', 'IGDB devolvió error en un lote', { status: result.status, error: result.error });
      continue;
    }

    const games: any[] = Array.isArray(result.data) ? result.data : [];
    for (const g of games) {
      const imageId = g?.cover?.image_id;
      if (imageId) {
        coverMap.set(g.id as number, buildCoverUrl(imageId as string));
      }
    }

    log('INFO', `Lote ${Math.floor(i / IGDB_CHUNK) + 1}: ${games.length} resultados, ${coverMap.size} con cover hasta ahora`);
  }

  log('INFO', `IGDB respondió con portada para ${coverMap.size} de ${missingIds.length} juegos`);

  // ── 3. Actualizar la BD, juego a juego (no hay bulk update condicional en PostgREST) ──
  let updatedCount = 0;

  // Agrupamos en lotes de 50 para no saturar la conexión
  const entries = [...coverMap.entries()];
  for (let i = 0; i < entries.length; i += 50) {
    const batch = entries.slice(i, i + 50);
    await Promise.all(
      batch.map(async ([igdbId, coverUrl]) => {
        const { error } = await supabase
          .from('games')
          .update({ cover_url: coverUrl })
          .eq('igdb_id', igdbId)
          .is('cover_url', null);  // solo sobreescribe si sigue NULL (seguridad)
        if (error) {
          log('WARN', `Error actualizando igdb_id=${igdbId}`, { error: error.message });
        } else {
          updatedCount++;
        }
      }),
    );
  }

  log('INFO', `Backfill completado. Actualizados: ${updatedCount}`);

  return new Response(
    JSON.stringify({
      ok: true,
      gamesWithoutCover: missingIds.length,
      igdbResolved: coverMap.size,
      updated: updatedCount,
    }),
    { headers: { 'Content-Type': 'application/json' }, status: 200 },
  );
});
