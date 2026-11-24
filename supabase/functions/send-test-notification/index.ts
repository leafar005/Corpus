/**
 * send-test-notification
 * ──────────────────────
 * Edge Function dedicada para que el usuario autenticado pruebe sus propias
 * notificaciones push sin enviar título, cuerpo ni destinatarios arbitrarios
 * desde el cliente (Auditoría ARQ-05).
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeadersForRequest, handleCorsPreflight } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  const corsHeaders = corsHeadersForRequest(req);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const jwt = authHeader.replace("Bearer ", "");
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(jwt);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let requestedToken: string | undefined;
    try {
      const body = await req.json();
      if (body && typeof body.token === "string" && body.token.length > 0) {
        requestedToken = body.token;
      }
    } catch (_) {
      // Body opcional
    }

    let query = supabaseAdmin
      .from("push_tokens")
      .select("token")
      .eq("user_id", user.id);
    if (requestedToken) {
      query = query.eq("token", requestedToken);
    }

    const { data: ownedRows, error: dbError } = await query;
    if (dbError) {
      throw dbError;
    }

    const tokens = (ownedRows ?? []).map((r: any) => r.token);
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ error: "No owned push tokens found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const forwardRes = await fetch(
      `${SUPABASE_URL}/functions/v1/send-push-notification`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          tokens,
          title: "Corpus — Notificación de prueba",
          body: "Las notificaciones funcionan correctamente.",
          data: { type: "test" },
        }),
      }
    );

    const forwardBody = await forwardRes.text();
    return new Response(forwardBody, {
      status: forwardRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("[send-test-notification] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
