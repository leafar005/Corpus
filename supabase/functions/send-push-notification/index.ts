/**
 * send-push-notification
 * ──────────────────────
 * Función genérica para enviar notificaciones push via FCM HTTP v1 API.
 * Se invoca desde otras Edge Functions (notify-friend-activity, notify-comment, etc.)
 *
 * Body esperado:
 * {
 *   tokens: string[],          // FCM tokens destino
 *   title: string,             // Título de la notificación
 *   body: string,              // Cuerpo del mensaje
 *   data?: Record<string, string>  // Datos extra opcionales (para deep link, etc.)
 * }
 *
 * Responde con:
 * {
 *   sent: number,              // Notificaciones enviadas con éxito
 *   failed: number,            // Fallos
 *   invalid_tokens: string[]   // Tokens inválidos para limpiar de la BD
 * }
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── FCM OAuth2 token (con caché en memoria) ────────────────────────────────

let _fcmAccessToken = "";
let _fcmTokenExpiry = 0;

async function getFcmAccessToken(): Promise<string> {
  if (_fcmAccessToken && Date.now() < _fcmTokenExpiry) return _fcmAccessToken;

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

  // Construir JWT para solicitar el access token a Google OAuth2
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const now = Math.floor(Date.now() / 1000);
  const claimset = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const signingInput = `${header}.${claimset}`;

  // Importar la clave privada RSA
  const privateKey = serviceAccount.private_key;
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const jwt = `${signingInput}.${signatureB64}`;

  // Intercambiar JWT por access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`Failed to get FCM access token: ${err}`);
  }

  const tokenData = await tokenRes.json();
  _fcmAccessToken = tokenData.access_token;
  _fcmTokenExpiry = Date.now() + (tokenData.expires_in - 60) * 1000;
  return _fcmAccessToken;
}

// ─── Enviar batch de notificaciones ─────────────────────────────────────────

async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ sent: number; failed: number; invalidTokens: string[] }> {
  if (tokens.length === 0) return { sent: 0, failed: 0, invalidTokens: [] };

  const accessToken = await getFcmAccessToken();
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

  let sent = 0;
  let failed = 0;
  const invalidTokens: string[] = [];

  // FCM HTTP v1 no soporta multicast directamente, enviamos en paralelo (máx 500/s)
  const CHUNK_SIZE = 100;
  for (let i = 0; i < tokens.length; i += CHUNK_SIZE) {
    const chunk = tokens.slice(i, i + CHUNK_SIZE);
    const promises = chunk.map(async (token) => {
      try {
        const message: any = {
          message: {
            token,
            notification: { title, body },
            android: {
              notification: {
                channel_id: "corpus_default",
                icon: "launcher_icon",
                color: "#7E57C2",
                default_vibrate_timings: true,
              },
              priority: "high",
            },
            // Bloque webpush: necesario para tokens web (Chrome, Safari PWA iOS 16.4+).
            // Sin este bloque, Safari puede ignorar la notificación o no entregarla al SW.
            webpush: {
              headers: {
                Urgency: "high",
              },
              notification: {
                title,
                body,
                icon: "/icons/Icon-192.png",
                badge: "/icons/Icon-192.png",
              },
            },
          },
        };

        if (data) {
          message.message.data = data;
        }

        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(message),
        });

        if (res.ok) {
          sent++;
        } else {
          const errBody = await res.json().catch(() => ({}));
          const errCode = errBody?.error?.details?.[0]?.errorCode ?? "";
          // Tokens inválidos o no registrados → marcarlos para eliminar
          if (
            errCode === "UNREGISTERED" ||
            errCode === "INVALID_ARGUMENT" ||
            res.status === 400 ||
            res.status === 404
          ) {
            invalidTokens.push(token);
          }
          failed++;
          console.error(`[FCM] Failed for token ${token.slice(0, 20)}...: ${JSON.stringify(errBody)}`);
        }
      } catch (e) {
        failed++;
        console.error(`[FCM] Exception for token:`, e);
      }
    });

    await Promise.all(promises);
  }

  // Limpiar tokens inválidos de la BD
  if (invalidTokens.length > 0) {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    await supabase
      .from("push_tokens")
      .delete()
      .in("token", invalidTokens);
    console.log(`[FCM] Cleaned ${invalidTokens.length} invalid tokens`);
  }

  return { sent, failed, invalidTokens };
}

// ─── Handler principal ───────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { tokens, title, body, data } = await req.json();

    if (!Array.isArray(tokens) || !title || !body) {
      return new Response(
        JSON.stringify({ error: "tokens[], title and body are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = await sendToTokens(tokens, title, body, data);

    return new Response(JSON.stringify({ success: true, ...result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("[send-push-notification] Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
