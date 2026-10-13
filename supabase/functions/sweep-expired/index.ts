// POST /sweep-expired (deployed with --no-verify-jwt)
// External-scheduler entry point for the §7.4 retention sweep. Guarded
// by the service-role key itself: the caller must present it as a Bearer
// token. The in-database pg_cron schedule (migration 0005) runs the same
// RPC hourly; this function exists for manual/external invocation and
// returns the RPC's counts verbatim (counts only, never file names).

import {
  handleOptions,
  json,
  serviceClient,
} from "../_shared/gateway.ts";

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`;
  if (req.headers.get("Authorization") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const service = serviceClient();
  const { data, error } = await service.rpc("sweep_expired");
  if (error) return json({ error: "rpc_failed", detail: error.message }, 500);
  return json(data);
});
