// GET /job-status?job_id= (§7.3 GET /jobs/{id})
// Own jobs only — another install's job is indistinguishable from missing.

import { handleOptions, json, resolveCaller } from "../_shared/gateway.ts";

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  const auth = await resolveCaller(req);
  if (!auth) return json({ error: "unauthorized" }, 401);
  const { user, service } = auth;

  const jobId = new URL(req.url).searchParams.get("job_id");
  if (!jobId) return json({ error: "job_id_required" }, 400);

  const found = await service
    .from("jobs")
    .select("id, status, error, meta")
    .eq("id", jobId)
    .eq("install_id", user.id)
    .maybeSingle();
  if (found.error) return json({ error: "db_error" }, 500);
  if (!found.data) return json({ error: "not_found" }, 404);

  return json({
    job_id: found.data.id,
    status: found.data.status,
    error: found.data.error ?? null,
    meta: found.data.status === "done" ? (found.data.meta ?? null) : null,
  });
});
