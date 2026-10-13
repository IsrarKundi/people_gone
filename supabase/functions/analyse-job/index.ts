// POST /analyse-job (§7.3 POST /jobs/{id}/analyse)
// Stage A: downloads the user's upload and asks the worker to /detect
// (persons + keeper proposal, no inpainting). On worker failure the job
// stays in 'created' with error set, so the user can simply retry (§6.7).

import {
  handleOptions,
  json,
  resolveCaller,
  workerBaseUrl,
  workerKey,
} from "../_shared/gateway.ts";

function bucketPath(full: string, bucket: string): string {
  return full.startsWith(`${bucket}/`) ? full.slice(bucket.length + 1) : full;
}

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const auth = await resolveCaller(req);
  if (!auth) return json({ error: "unauthorized" }, 401);
  const { user, service } = auth;

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch { /* handled below */ }
  const jobId = body.job_id as string | undefined;
  if (!jobId) return json({ error: "job_id_required" }, 400);

  const found = await service
    .from("jobs")
    .select("*")
    .eq("id", jobId)
    .eq("install_id", user.id)
    .maybeSingle();
  if (found.error) return json({ error: "db_error" }, 500);
  if (!found.data) return json({ error: "not_found" }, 404);
  const job = found.data;
  if (job.status !== "created") {
    return json({ error: "invalid_state", status: job.status }, 409);
  }

  const dl = await service.storage.from("uploads")
    .download(bucketPath(job.upload_path, "uploads"));
  if (dl.error || !dl.data) return json({ error: "upload_missing" }, 409);
  const bytes = new Uint8Array(await dl.data.arrayBuffer());

  const form = new FormData();
  form.append("file", new Blob([bytes], { type: "image/jpeg" }), "photo.jpg");

  let detect: Record<string, unknown> | null = null;
  try {
    const res = await fetch(`${workerBaseUrl()}/detect`, {
      method: "POST",
      headers: { "X-Worker-Key": workerKey() },
      body: form,
    });
    if (res.ok) detect = (await res.json()) as Record<string, unknown>;
    else await res.text(); // drain
  } catch { /* detect stays null */ }

  if (!detect || detect.ok !== true) {
    await service.from("jobs")
      .update({ error: "worker_failed", updated_at: new Date().toISOString() })
      .eq("id", job.id);
    return json({ error: "worker_failed" }, 502);
  }

  const keeperIds = (detect.keeper_ids as number[]) ?? [];
  const persons = detect.persons ?? null;
  const inputDimensions = detect.input_dimensions ?? null;

  const upd = await service.from("jobs").update({
    persons,
    keep_ids: keeperIds,
    people_count: (detect.persons_detected as number) ?? null,
    input_dimensions: inputDimensions,
    status: "awaiting_confirm",
    error: null,
    updated_at: new Date().toISOString(),
  }).eq("id", job.id);
  if (upd.error) return json({ error: "db_error" }, 500);

  return json({
    ok: true,
    persons_detected: detect.persons_detected ?? null,
    keeper_ids: keeperIds,
    removed_ids: detect.removed_ids ?? [],
    persons,
    input_dimensions: inputDimensions,
  });
});
