// POST /touchup (FR-09 / S5 brush touch-up)
// Authenticated proxy to the worker's /touchup: forwards the multipart
// body (file, mask_png, engine?) untouched and returns the worker's JSON
// and status verbatim. A touch-up never consumes a save (§9.1).

import {
  handleOptions,
  json,
  resolveCaller,
  workerBaseUrl,
  workerKey,
} from "../_shared/gateway.ts";

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const auth = await resolveCaller(req);
  if (!auth) return json({ error: "unauthorized" }, 401);

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return json({ error: "multipart_required" }, 400);
  }

  const res = await fetch(`${workerBaseUrl()}/touchup`, {
    method: "POST",
    headers: { "X-Worker-Key": workerKey() },
    body: form,
  });
  const text = await res.text();
  return new Response(text, {
    status: res.status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": res.headers.get("Content-Type") ?? "application/json",
    },
  });
});
