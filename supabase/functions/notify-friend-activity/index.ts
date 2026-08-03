/**
 * notify-friend-activity
 * ──────────────────────
 * Invocada por un Database Webhook en INSERT sobre la tabla `activity_feed`.
 * Notifica a los amigos cuando:
 *   - Un amigo empieza a jugar (action_type='status_change', metadata.status='playing')
 *   - Un amigo termina un juego (action_type='status_change', metadata.status='beaten')
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SELF_URL = Deno.env.get("SUPABASE_URL")?.replace("supabase.co", "supabase.co/functions/v1") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // El webhook de Supabase envía { type, table, record, old_record, schema }
    const record = payload.record ?? payload;
    const actionType = record?.action_type;
    const userId = record?.user_id;
    const metadata = record?.metadata ?? {};
    const gameId = record?.game_id;

    // Solo procesamos status_change de playing y beaten
    if (actionType !== "status_change") {
      return new Response(JSON.stringify({ skipped: "not a status_change" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const status = metadata?.status as string | undefined;
    if (status !== "playing" && status !== "beaten") {
      return new Response(JSON.stringify({ skipped: `status '${status}' not notifiable` }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Obtener el nombre del usuario que generó la actividad
    const { data: actorUser } = await supabase
      .from("users")
      .select("username, display_name")
      .eq("id", userId)
      .maybeSingle();

    const actorName = actorUser?.display_name || actorUser?.username || "Alguien";

    // Obtener el título del juego
    let gameTitle = "un juego";
    if (gameId) {
      const { data: game } = await supabase
        .from("games")
        .select("title")
        .eq("igdb_id", gameId)
        .maybeSingle();
      if (game?.title) gameTitle = game.title;
    }

    // Determinar título y cuerpo de la notificación
    const prefKey = status === "playing" ? "friend_started_playing" : "friend_finished_game";
    const notifTitle = "Corpus";
    const notifBody = status === "playing"
      ? `${actorName} está jugando a ${gameTitle}`
      : `${actorName} ha terminado ${gameTitle}`;

    // Obtener todos los amigos aceptados del usuario
    const [asSenderRes, asReceiverRes] = await Promise.all([
      supabase
        .from("friendships")
        .select("addressee_id")
        .eq("requester_id", userId)
        .eq("status", "accepted"),
      supabase
        .from("friendships")
        .select("requester_id")
        .eq("addressee_id", userId)
        .eq("status", "accepted"),
    ]);

    const friendIds = new Set<string>([
      ...(asSenderRes.data ?? []).map((f: any) => f.addressee_id),
      ...(asReceiverRes.data ?? []).map((f: any) => f.requester_id),
    ]);

    if (friendIds.size === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no friends" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const friendIdsArr = Array.from(friendIds);

    // Filtrar amigos que tienen activada esta notificación
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select(`user_id, ${prefKey}`)
      .in("user_id", friendIdsArr);

    // Usuarios sin fila en notification_preferences: usamos el valor DEFAULT (true)
    const usersWithPrefOff = new Set(
      (prefs ?? [])
        .filter((p: any) => p[prefKey] === false)
        .map((p: any) => p.user_id)
    );

    const targetUserIds = friendIdsArr.filter((id) => !usersWithPrefOff.has(id));

    if (targetUserIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "all prefs disabled" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Recoger tokens FCM de los usuarios destino
    const { data: tokenRows } = await supabase
      .from("push_tokens")
      .select("token")
      .in("user_id", targetUserIds);

    const tokens = (tokenRows ?? []).map((r: any) => r.token);

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no tokens registered" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Invocar send-push-notification
    const sendRes = await fetch(`${SELF_URL}/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        tokens,
        title: notifTitle,
        body: notifBody,
        data: { type: "friend_activity", user_id: userId, game_id: String(gameId ?? "") },
      }),
    });

    const sendResult = await sendRes.json();
    console.log("[notify-friend-activity] Result:", sendResult);

    return new Response(JSON.stringify({ success: true, ...sendResult }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("[notify-friend-activity] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
