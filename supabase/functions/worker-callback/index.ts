// POST /worker-callback (deployed with --no-verify-jwt)
// The worker calls this AFTER it has PUT the result JPEG to the signed
// result_upload_url. Auth is the per-job callback token: its SHA-256 hex
// must equal jobs.callback_token_hash. Anything else is a 401.

import {
  handleOptions,
  hashEquals,
  json,
  serviceClient,
  sha256Hex,
} from "../_shared/gateway.ts";

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch { /* handled below */ }
  const jobId = body.job_id as string | undefined;
  const token = body.token as string | undefined;
  const meta = (body.meta as Record<string, unknown> | undefined) ?? {};
  if (!jobId || !token) return json({ error: "bad_request" }, 400);

  const service = serviceClient();
  const found = await service
    .from("jobs")
    .select("id, callback_token_hash")
    .eq("id", jobId)
    .maybeSingle();
  if (!found.data) return json({ error: "not_found" }, 404);

  const presented = await sha256Hex(token);
  const stored = (found.data.callback_token_hash as string) ?? "";
  if (!stored || !hashEquals(presented, stored)) {
    return json({ error: "unauthorized" }, 401);
  }

  const removed = meta.removed_ids as unknown[] | undefined;
  const upd = await service.from("jobs").update({
    status: "done",
    people_count: (meta.persons_detected as number) ?? null,
    removed_count: Array.isArray(removed) ? removed.length : null,
    ghost_check_fired: (meta.ghost_check_fired as boolean) ?? null,
    processor: (meta.engine_used as string) ?? null,
    gpu_seconds: (meta.total_gpu_seconds as number) ??
      (meta.total_seconds as number) ?? null,
    cost_estimate_usd: (meta.cost_estimate_usd as number) ?? null,
    meta,
    error: null,
    updated_at: new Date().toISOString(),
  }).eq("id", jobId);
  if (upd.error) return json({ error: "db_error" }, 500);

  return json({ ok: true });
});
