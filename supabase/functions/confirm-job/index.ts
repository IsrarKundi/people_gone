// POST /confirm-job (§7.3 POST /jobs/{id}/confirm)
// Stage B trigger: records the keeper choice, flips the job to
// 'processing', mints the signed result-upload URL, and fires the worker
// /process call with a callback token (only its SHA-256 hash is stored).
// The worker PUTs the result JPEG to the signed URL, then calls
// /worker-callback, which completes the job. This function returns 202
// immediately — it never waits for processing to finish (§6.7).
// Idempotent: confirming a 'processing' or 'done' job returns its state.

import {
  handleOptions,
  json,
  resolveCaller,
  sha256Hex,
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

  if (job.status === "processing" || job.status === "done") {
    return json({ job_id: job.id, status: job.status });
  }
  if (job.status !== "awaiting_confirm") {
    return json({ error: "invalid_state", status: job.status }, 409);
  }

  const keepIds = (body.keep_ids as number[] | undefined) ?? job.keep_ids ?? [];
  const engine = (body.engine as string | undefined) ?? job.engine ?? "mat";
  // Contract v3 (Phase A): the user's belongings decisions — ambiguous
  // items to remove, attached items to detach/protect. They are kept
  // on the job's meta (jsonb) for observability and forwarded to the
  // worker as CSV form fields; the worker re-derives the items from
  // its own analysis, so these ids are the ONLY new trust surface.
  const removeItemIds = (body.remove_item_ids as number[] | undefined) ?? [];
  const detachedBelongingIds =
    (body.detached_belonging_ids as number[] | undefined) ?? [];

  // Callback token: raw value goes ONLY to the worker; we store its hash.
  const raw = new Uint8Array(32);
  crypto.getRandomValues(raw);
  const token = [...raw].map((b) => b.toString(16).padStart(2, "0")).join("");
  const tokenHash = await sha256Hex(token);

  const upd = await service.from("jobs").update({
    keep_ids: keepIds,
    engine,
    meta: {
      ...((job.meta as Record<string, unknown> | null) ?? {}),
      remove_item_ids: removeItemIds,
      detached_belonging_ids: detachedBelongingIds,
    },
    status: "processing",
    callback_token_hash: tokenHash,
    updated_at: new Date().toISOString(),
  }).eq("id", job.id);
  if (upd.error) return json({ error: "db_error" }, 500);

  const signed = await service.storage.from("results")
    .createSignedUploadUrl(bucketPath(job.result_path, "results"));
  const resultUploadUrl = signed.data?.signedUrl ?? null;

  const dl = await service.storage.from("uploads")
    .download(bucketPath(job.upload_path, "uploads"));
  if (dl.error || !dl.data) return json({ error: "upload_missing" }, 409);
  const bytes = new Uint8Array(await dl.data.arrayBuffer());

  const form = new FormData();
  form.append("file", new Blob([bytes], { type: "image/jpeg" }), "photo.jpg");
  form.append("engine", engine);
  if (keepIds.length > 0) form.append("keep", keepIds.join(","));
  if (removeItemIds.length > 0) {
    form.append("remove_items", removeItemIds.join(","));
  }
  if (detachedBelongingIds.length > 0) {
    form.append("detached_items", detachedBelongingIds.join(","));
  }
  form.append(
    "callback_url",
    `${Deno.env.get("SUPABASE_URL")}/functions/v1/worker-callback`,
  );
  form.append("callback_token", token);
  form.append("job_id", job.id);
  if (resultUploadUrl) form.append("result_upload_url", resultUploadUrl);

  const fire = fetch(`${workerBaseUrl()}/process`, {
    method: "POST",
    headers: { "X-Worker-Key": workerKey() },
    body: form,
  }).then(async (r) => {
    await r.text(); // drain; completion arrives via worker-callback
  }).catch(() => { /* worker failure surfaces as a stuck job + sweep */ });

  // EdgeRuntime.waitUntil keeps the fetch alive after we respond.
  const rt = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (rt && typeof rt.waitUntil === "function") {
    rt.waitUntil(fire);
  } else {
    await fire;
  }

  return json({ job_id: job.id, status: "processing" }, 202);
});
