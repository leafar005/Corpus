// supabase/functions/_shared/stash-client.ts

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

export const USER_AGENTS = [
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:1; iOS 26.5.2) Alamofire/5.4.4',
  'Stash/2.6.8 (Android; 33; Scale/2.75)',
  'Stash/2.6.8 (Android; 34; Scale/3.00)',
  'Stash/2.6.8 (io.stash.team.games.tracker.StashApp; build:2; iOS 27.0) Alamofire/5.4.4',
];

export function randomUserAgent(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

export function delay(ms: number): Promise<void> {
  return new Promise((res) => setTimeout(res, ms));
}

/** Retraso aleatorio entre 500ms y 2000ms, igual que en fetch-stash-reviews / fetch-stash-feed */
export function jitter(): Promise<void> {
  const ms = Math.floor(Math.random() * 1500) + 500;
  return delay(ms);
}

export function buildStashHeaders(token: string, userAgent: string): HeadersInit {
  return {
    'Host': 'api.stash.games',
    'Accept': '*/*',
    'Accept-Locale': 'es_ES',
    'Time-Zone': 'Europe/Madrid',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept-Language': 'es',
    'Content-Type': 'application/json',
    'User-Agent': userAgent,
    'X-Game-Status-Version': 'v2',
    'Authorization': `Bearer ${token}`,
  };
}

export function makeLogger(service: string) {
  return (level: 'INFO' | 'WARN' | 'ERROR', message: string, meta: Record<string, any> = {}) => {
    console.log(
      JSON.stringify({ timestamp: new Date().toISOString(), level, service, message, ...meta })
    );
  };
}
