/**
 * notify-bundle-expiring
 * ──────────────────────
 * Función invocada por pg_cron diariamente.
 * Busca bundles cuya fecha de fin esté en las próximas 25h (margen de 1h por
 * si el cron corre con algo de retraso) y notifica a todos los usuarios
 * que tienen la preferencia `bundle_expiring` activada.
 *
 * También se encarga de la notificación de bundles nuevos cuando se invoca
 * con { type: "new_bundles", bundleTitles: string[] } desde sync-bundles.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SELF_URL = Deno.env.get("SUPABASE_URL")?.replace("supabase.co", "supabase.co/functions/v1") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function sendToUsersWithPref(
  prefKey: string,
  title: string,
  body: string,
  data: Record<string, string>,
  supabase: ReturnType<typeof createClient>
): Promise<{ sent: number; skipped: number }> {
  // Obtener usuarios con esa preferencia desactivada (o no configurada → default true)
  const { data: disabledPrefs } = await supabase
    .from("notification_preferences")
    .select("user_id")
    .eq(prefKey, false);

  const disabledUserIds = new Set((disabledPrefs ?? []).map((p: any) => p.user_id));

  // Obtener todos los tokens, excluyendo los usuarios que desactivaron la pref
  const { data: tokenRows } = await supabase
    .from("push_tokens")
    .select("token, user_id");

  const tokens = (tokenRows ?? [])
    .filter((r: any) => !disabledUserIds.has(r.user_id))
    .map((r: any) => r.token);

  if (tokens.length === 0) return { sent: 0, skipped: disabledUserIds.size };

  const sendRes = await fetch(`${SELF_URL}/send-push-notification`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ tokens, title, body, data }),
  });

  const result = await sendRes.json();
  return { sent: result.sent ?? tokens.length, skipped: disabledUserIds.size };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Leer body para ver si es llamada de "nuevo bundle" desde sync-bundles
    let body: any = {};
    try {
      body = await req.json();
    } catch (_) {
      // Si no hay body (llamada de cron), usamos body vacío
    }

    // ─── Caso A: Notificación de bundles nuevos (llamado desde sync-bundles) ──
    if (body?.type === "new_bundles" && Array.isArray(body.bundleTitles) && body.bundleTitles.length > 0) {
      const titles = body.bundleTitles as string[];
      const bundleList = titles.length === 1
        ? titles[0]
        : titles.length <= 3
          ? titles.join(", ")
          : `${titles.slice(0, 2).join(", ")} y ${titles.length - 2} más`;

      const result = await sendToUsersWithPref(
        "new_bundle",
        "Nuevo bundle disponible",
        `Ahora en activo: ${bundleList}`,
        { type: "new_bundle" },
        supabase
      );

      return new Response(JSON.stringify({ success: true, ...result }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── Caso B: Bundles que expiran en ~24h (llamado por cron diariamente) ───
    const now = new Date();
    const in25h = new Date(now.getTime() + 25 * 60 * 60 * 1000);
    const in23h = new Date(now.getTime() + 23 * 60 * 60 * 1000);

    // Bundles que expiran entre 23h y 25h desde ahora (ventana de 2h para evitar duplicados)
    const { data: expiringBundles, error } = await supabase
      .from("active_bundles")
      .select("id, title")
      .gte("end_date", in23h.toISOString())
      .lte("end_date", in25h.toISOString());

    if (error) throw error;

    if (!expiringBundles || expiringBundles.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: "no bundles expiring soon" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const bundleNames = expiringBundles.map((b: any) => b.title);
    const bundleList = bundleNames.length === 1
      ? bundleNames[0]
      : bundleNames.length <= 3
        ? bundleNames.join(", ")
        : `${bundleNames.slice(0, 2).join(", ")} y ${bundleNames.length - 2} más`;

    const result = await sendToUsersWithPref(
      "bundle_expiring",
      "Bundle a punto de terminar",
      `Queda menos de 24h para que acabe: ${bundleList}`,
      { type: "bundle_expiring" },
      supabase
    );

    return new Response(JSON.stringify({ success: true, bundles: bundleNames.length, ...result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("[notify-bundle-expiring] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
