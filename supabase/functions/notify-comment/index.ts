/**
 * notify-comment
 * ──────────────
 * Invocada por un Database Webhook en INSERT sobre `review_comments`.
 * Cubre dos casos:
 *
 *   1. Comentario nuevo en tu reseña → notifica al autor de la reseña
 *      (si el comentador no es el propio autor)
 *      Preferencia: `comment_on_review`
 *
 *   2. Reply (@mention) en un comentario tuyo → el contenido empieza por @username
 *      El sistema busca al usuario mencionado y le notifica.
 *      Preferencia: `reply_to_comment`
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SELF_URL = Deno.env.get("SUPABASE_URL")?.replace("supabase.co", "supabase.co/functions/v1") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function notifyUser(
  targetUserId: string,
  prefKey: string,
  title: string,
  body: string,
  data: Record<string, string>,
  supabase: ReturnType<typeof createClient>
) {
  // Comprobar preferencia (si no existe, el default es true)
  const { data: pref } = await supabase
    .from("notification_preferences")
    .select(prefKey)
    .eq("user_id", targetUserId)
    .maybeSingle();

  if (pref && pref[prefKey] === false) {
    console.log(`[notify-comment] User ${targetUserId} has ${prefKey} disabled`);
    return;
  }

  // Recoger tokens FCM del usuario
  const { data: tokenRows } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("user_id", targetUserId);

  const tokens = (tokenRows ?? []).map((r: any) => r.token);
  if (tokens.length === 0) {
    console.log(`[notify-comment] No tokens for user ${targetUserId}`);
    return;
  }

  // Enviar
  const sendRes = await fetch(`${SELF_URL}/send-push-notification`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ tokens, title, body, data }),
  });

  const result = await sendRes.json();
  console.log(`[notify-comment] Sent to ${targetUserId}:`, result);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const record = payload.record ?? payload;

    const commentId = record?.id as string | undefined;
    const commenterId = record?.user_id as string | undefined;
    const reviewId = record?.review_id as string | undefined;
    const content = record?.content as string | undefined;

    if (!commenterId || !reviewId) {
      return new Response(JSON.stringify({ skipped: "missing fields" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Obtener nombre del comentador
    const { data: commenterUser } = await supabase
      .from("users")
      .select("username, display_name")
      .eq("id", commenterId)
      .maybeSingle();
    const commenterName = commenterUser?.display_name || commenterUser?.username || "Alguien";

    // ─── Caso 1: Notificar al autor de la reseña ────────────────────────────
    const { data: review } = await supabase
      .from("reviews")
      .select("user_id, game_id")
      .eq("id", reviewId)
      .maybeSingle();

    if (review && review.user_id && review.user_id !== commenterId) {
      // Obtener título del juego para personalizar el mensaje
      let gameTitle = "un juego";
      if (review.game_id) {
        const { data: game } = await supabase
          .from("games")
          .select("title")
          .eq("igdb_id", review.game_id)
          .maybeSingle();
        if (game?.title) gameTitle = game.title;
      }

      await notifyUser(
        review.user_id,
        "comment_on_review",
        `${commenterName} comentó tu reseña de ${gameTitle}`,
        content ?? "",
        { type: "comment_on_review", review_id: reviewId, comment_id: commentId ?? "" },
        supabase
      );
    }

    // ─── Caso 2: Notificar al usuario mencionado con @username (reply) ──────
    if (content) {
      const mentionMatch = content.match(/^@(\w+)/);
      if (mentionMatch) {
        const mentionedUsername = mentionMatch[1];

        // Buscar el usuario mencionado
        const { data: mentionedUser } = await supabase
          .from("users")
          .select("id")
          .eq("username", mentionedUsername)
          .maybeSingle();

        if (
          mentionedUser?.id &&
          mentionedUser.id !== commenterId &&             // No auto-notificar
          mentionedUser.id !== review?.user_id            // No duplicar con Caso 1
        ) {
          // Eliminar el prefijo @usuario del texto visible en el cuerpo
          const replyBody = content.replace(/^@\w+\s*/, "").trim();
          await notifyUser(
            mentionedUser.id,
            "reply_to_comment",
            `${commenterName} respondió a tu comentario`,
            replyBody.length > 100 ? replyBody.slice(0, 97) + "..." : replyBody,
            { type: "reply_to_comment", review_id: reviewId, comment_id: commentId ?? "" },
            supabase
          );
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("[notify-comment] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
