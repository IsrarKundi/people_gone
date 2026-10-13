// Shared helpers for the PeopleGone gateway Edge Functions (§7.3).
// Security model: every caller-scoped function resolves the caller from
// the Authorization JWT via an anon-key client (so RLS + auth.uid() see
// the real user), and privileged writes go through a service-role client.
// No vendor key and no service-role key ever leaves the server (§7.3).

import { createClient, SupabaseClient, User } from "jsr:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/** Anon-key client carrying the caller's JWT, so auth.uid() resolves. */
export function callerClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      auth: { persistSession: false },
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
    },
  );
}

export interface Caller {
  user: User;
  caller: SupabaseClient;
  service: SupabaseClient;
}

/** Resolve the authenticated (anonymous-auth) caller, or null. */
export async function resolveCaller(req: Request): Promise<Caller | null> {
  const caller = callerClient(req);
  const { data, error } = await caller.auth.getUser();
  if (error || !data.user) return null;
  return { user: data.user, caller, service: serviceClient() };
}

export function workerBaseUrl(): string {
  return (Deno.env.get("WORKER_BASE_URL") ?? "").replace(/\/$/, "");
}

export function workerKey(): string {
  return Deno.env.get("WORKER_API_KEY") ?? "";
}

/** SHA-256 hex digest (callback token verification). */
export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Constant-time-ish string comparison for token hashes. */
export function hashEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Persons rows are stored as the worker's /detect persons array. */
export function removedIds(persons: unknown, keepIds: number[] | null): number[] {
  if (!Array.isArray(persons)) return [];
  const keep = new Set(keepIds ?? []);
  return persons
    .map((p) => (p as { id?: number }).id)
    .filter((id): id is number => typeof id === "number" && !keep.has(id));
}
