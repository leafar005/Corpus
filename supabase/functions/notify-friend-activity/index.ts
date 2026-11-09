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
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SELF_URL = Deno.env.get("SUPABASE_URL")?.replace("supabase.co", "supabase.co/functions/v1") ?? "";

// Constantes alineadas con ActivityRepository en el cliente (kGroupableFeedStatuses y kFeedGroupGap)
const GROUPABLE_FEED_STATUSES = new Set([
  "wishlist",
  "playing",
  "to_play",
  "beaten",
  "completed",
]);
const FEED_GROUP_GAP_MS = 60 * 60 * 1000; // 60 minutos

function hasAdditionalReviewInfo(review: any, partnerIds?: any): boolean {
  if (Array.isArray(partnerIds) && partnerIds.length > 0) return true;
  if (!review) return false;
  if (typeof review.rating === "number" && review.rating > 0) return true;
  if (typeof review.comment === "string" && review.comment.trim().length > 0) {
    return true;
  }
  if (Array.isArray(review.image_urls) && review.image_urls.length > 0) {
    return true;
  }
  if (Array.isArray(review.partner_ids) && review.partner_ids.length > 0) {
    return true;
  }
  if (typeof review.play_time_hours === "number" && review.play_time_hours > 0) {
    return true;
  }
  if (review.is_replay === true) return true;
  return false;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

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

    // Verificar en BD que la entrada de activity_feed existe realmente (evita spoofing)
    if (record?.id) {
      const { data: verifiedFeed } = await supabase
        .from("activity_feed")
        .select("id, user_id, game_id, action_type, metadata, created_at")
        .eq("id", record.id)
        .maybeSingle();

      if (
        !verifiedFeed ||
        verifiedFeed.user_id !== userId ||
        verifiedFeed.action_type !== "status_change"
      ) {
        return new Response(JSON.stringify({ skipped: "activity not found in db" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // Evitar enviar múltiples notificaciones push cuando el usuario añade varios
    // juegos seguidos con el mismo estado sin información adicional dentro de la
    // ventana de agrupación (60 min, mismo criterio que el feed del cliente).
    if (GROUPABLE_FEED_STATUSES.has(status)) {
      let currentReview: any = null;
      const reviewId = record?.review_id ?? metadata?.review_id;
      if (reviewId) {
        const { data: rev } = await supabase
          .from("reviews")
          .select("id, rating, comment, image_urls, partner_ids, play_time_hours, is_replay")
          .eq("id", reviewId)
          .maybeSingle();
        currentReview = rev;
      }

      let currentPartnerIds: any = null;
      if (gameId != null) {
        const { data: ug } = await supabase
          .from("user_games")
          .select("partner_ids")
          .eq("user_id", userId)
          .eq("game_id", gameId)
          .maybeSingle();
        currentPartnerIds = ug?.partner_ids;
      }

      if (!hasAdditionalReviewInfo(currentReview, currentPartnerIds)) {
        const refTimeMs = createdAt ? new Date(createdAt).getTime() : Date.now();
        const windowStartIso = new Date(refTimeMs - FEED_GROUP_GAP_MS).toISOString();

        let recentQuery = supabase
          .from("activity_feed")
          .select("id, game_id, review_id, metadata, created_at")
          .eq("user_id", userId)
          .eq("action_type", "status_change")
          .eq("metadata->>status", status)
          .gte("created_at", windowStartIso)
          .order("created_at", { ascending: false })
          .limit(20);

        if (record?.id) {
          recentQuery = recentQuery.neq("id", record.id);
        }

        const { data: recentCandidates } = await recentQuery;
        const candidates = recentCandidates ?? [];

        if (candidates.length > 0) {
          const candidateReviewIds = Array.from(
            new Set(
              candidates
                .map((c: any) => c.review_id ?? c.metadata?.review_id)
                .filter((id: any) => typeof id === "string" && id.length > 0)
            )
          );

          const reviewsMap = new Map<string, any>();
          if (candidateReviewIds.length > 0) {
            const { data: candReviews } = await supabase
              .from("reviews")
              .select("id, rating, comment, image_urls, partner_ids, play_time_hours, is_replay")
              .in("id", candidateReviewIds);
            for (const r of candReviews ?? []) {
              reviewsMap.set(r.id, r);
            }
          }

          const hasPriorGroupableInWindow = candidates.some((c: any) => {
            const cRevId = c.review_id ?? c.metadata?.review_id;
            const cRev = cRevId ? reviewsMap.get(cRevId) : null;
            return !hasAdditionalReviewInfo(cRev, c.metadata?.partner_ids);
          });

          if (hasPriorGroupableInWindow) {
            return new Response(
              JSON.stringify({
                skipped: "grouped with recent status_change within 60m window",
              }),
              { headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }
        }
      }
    }

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

    if (!sendRes.ok) {
      console.error(`[notify-friend-activity] send-push-notification falló: HTTP ${sendRes.status}`);
      return new Response(JSON.stringify({ sent: 0, reason: "push failed" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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
