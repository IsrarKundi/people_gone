// POST /refund-credit (§7.2: a failed delivery refunds automatically)
// Calls the refund_save_credit RPC through an anon-key client carrying
// the caller's JWT. Idempotent: refunding an un-consumed or already
// refunded key returns {ok:true, refunded:false}.

import { callerClient, handleOptions, json } from "../_shared/gateway.ts";

Deno.serve(async (req) => {
  const pre = handleOptions(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch { /* handled below */ }
  const key = body.idempotency_key as string | undefined;
  if (!key) return json({ error: "idempotency_key_required" }, 400);

  const caller = callerClient(req);
  const { data: me } = await caller.auth.getUser();
  if (!me.user) return json({ error: "unauthorized" }, 401);

  const { data, error } = await caller.rpc("refund_save_credit", {
    p_idempotency_key: key,
  });
  if (error) return json({ error: "rpc_failed", detail: error.message }, 500);
  return json(data);
});
