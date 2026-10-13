// GET /get-result?job_id= (§7.3 GET /jobs/{id} when done)
// Returns a 1-hour signed download URL for the result, only once the job
// is done and only for its owner. The server copy still dies on the
// §7.4 24h clock (expires_at is returned so the app can say so honestly).

import { handleOptions, json, resolveCaller } from "../_shared/gateway.ts";

function bucketPath(full: string, bucket: string): string {
  return full.startsWith(`${bucket}/`) ? full.slice(bucket.length + 1) : full;
}

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
    .select("id, status, result_path, expires_at")
    .eq("id", jobId)
    .eq("install_id", user.id)
    .maybeSingle();
  if (found.error) return json({ error: "db_error" }, 500);
  if (!found.data) return json({ error: "not_found" }, 404);
  if (found.data.status !== "done") {
    return json({ error: "not_ready" }, 409);
  }

  const signed = await service.storage.from("results")
    .createSignedUrl(bucketPath(found.data.result_path, "results"), 3600);
  if (signed.error || !signed.data) return json({ error: "db_error" }, 500);

  return json({
    download_url: signed.data.signedUrl,
    expires_at: found.data.expires_at,
  });
});
