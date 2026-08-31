/**
 * notify-friend-activity
 * ──────────────────────
 * Invocada por un Database Webhook en INSERT sobre la tabla `activity_feed`.
 * Notifica a los amigos cuando:
 *   - Un amigo empieza a jugar (action_type='status_change', metadata.status='playing')
 *   - Un amigo termina un juego (action_type='status_change', metadata.status='beaten')
 *   - Un amigo añade un juego a su wishlist (action_type='status_change', metadata.status='wishlist')
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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

    // Ignorar actividades de hace más de 1 hora (ej: importaciones masivas de Stash o Steam)
    const createdAt = record?.created_at;
    if (createdAt) {
      const eventTime = new Date(createdAt).getTime();
      const now = Date.now();
      if (now - eventTime > 60 * 60 * 1000) {
        return new Response(JSON.stringify({ skipped: "activity is too old (likely imported)" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const status = metadata?.status as string | undefined;
    if (status !== "playing" && status !== "beaten" && status !== "wishlist") {
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

    // Determinar clave de preferencia y texto de la notificación
    // Título = la acción directamente (el sistema ya muestra el nombre de la app arriba)
    const prefKey =
      status === "playing" ? "friend_started_playing" :
      status === "beaten"  ? "friend_finished_game" :
                             "friend_wishlisted_game";

    // Título = nombre del amigo (sin repetir 'Corpus'), Cuerpo = la acción del juego.
    // FCM en Android requiere que title y body no estén vacíos para mostrar la notificación en background.
    const notifTitle = actorName;
    const notifBody =
      status === "playing"  ? `está jugando a ${gameTitle}` :
      status === "beaten"   ? `ha terminado ${gameTitle}` :
                              `quiere jugar a ${gameTitle}`;

    // Obtener todos los amigos aceptados del usuario usando la vista simétrica v_friend_pairs.
    // La vista ya maneja ambas direcciones de la amistad en una sola query.
    const { data: friendPairs, error: friendsError } = await supabase
      .from("v_friend_pairs")
      .select("friend_id")
      .eq("user_id", userId);

    const friendIds = new Set<string>(
      (friendPairs ?? []).map((f: any) => f.friend_id as string)
    );

    if (friendsError) {
      console.warn("[notify-friend-activity] Error leyendo v_friend_pairs:", friendsError);
    }

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
        data: { type: "friend_activity", user_id: userId, game_id: String(gameId ?? ""), review_id: record?.review_id ?? "" },
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
