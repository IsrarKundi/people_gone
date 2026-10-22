// POST /create-job (§7.3 POST /jobs)
// Idempotent on (install, client_job_id): a retry returns the existing
// job's CURRENT state and never creates a second billable job (§6.7, §8.2).
// A fresh job gets a signed UPLOAD url for its private uploads/ path.

import {
  handleOptions,
  json,
  removedIds,
  resolveCaller,
} from "../_shared/gateway.ts";

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
  } catch { /* empty body handled below */ }
  const clientJobId = body.client_job_id as string | undefined;
  if (!clientJobId) return json({ error: "client_job_id_required" }, 400);

  // Upsert the installs row (identity = anonymous auth uid, §7.1).
  await service.from("installs").upsert(
    {
      id: user.id,
      platform: (body.platform as string) ?? null,
      app_version: (body.app_version as string) ?? null,
    },
    { onConflict: "id" },
  );

  const existing = await service
    .from("jobs")
    .select("*")
    .eq("install_id", user.id)
    .eq("client_job_id", clientJobId)
    .maybeSingle();
  if (existing.error) return json({ error: "db_error" }, 500);

  let job = existing.data;
  if (!job) {
    const inserted = await service
      .from("jobs")
      .insert({
        install_id: user.id,
        client_job_id: clientJobId,
        engine: (body.engine as string) ?? "auto",
        status: "created",
      })
      .select("*")
      .single();
    if (inserted.error || !inserted.data) {
      // Lost a create race: re-read the winner's row.
      const again = await service
        .from("jobs")
        .select("*")
        .eq("install_id", user.id)
        .eq("client_job_id", clientJobId)
        .maybeSingle();
      if (!again.data) return json({ error: "db_error" }, 500);
      job = again.data;
    } else {
      job = inserted.data;
      const uploadPath = `uploads/${user.id}/${job.id}.jpg`;
      const resultPath = `results/${user.id}/${job.id}.jpg`;
      const updated = await service
        .from("jobs")
        .update({ upload_path: uploadPath, result_path: resultPath })
        .eq("id", job.id)
        .select("*")
        .single();
      if (updated.data) job = updated.data;
    }
  }

  let uploadUrl: string | null = null;
  if (job.status === "created" && job.upload_path) {
    const signed = await service.storage.from("uploads")
      .createSignedUploadUrl(job.upload_path.replace(/^uploads\//, ""));
    if (signed.data) uploadUrl = signed.data.signedUrl;
  }

  return json({
    job_id: job.id,
    status: job.status,
    upload_url: uploadUrl,
    persons: job.persons ?? null,
    // Contract v3: belongings stored on the job by analyse-job (meta
    // jsonb) come back with the proposal on an idempotent retry.
    belongings:
      ((job.meta as Record<string, unknown> | null)?.belongings as unknown) ??
        null,
    // Phase B: distractions ride the same meta jsonb round-trip.
    distractions:
      ((job.meta as Record<string, unknown> | null)?.distractions as unknown) ??
        null,
    keeper_ids: job.keep_ids ?? null,
    removed_ids: job.persons ? removedIds(job.persons, job.keep_ids) : null,
    input_dimensions: job.input_dimensions ?? null,
  });
});
