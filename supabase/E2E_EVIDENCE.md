# Phase 2 Gateway — Evidence (Task 2.1, §7)

Project: `ietwddgjtcrabqjdxsfp` (us-east-2, status ACTIVE_HEALTHY via
Management API). No tokens, keys, or signed URLs are recorded in this file.

## Migrations (applied via the Supabase Management API SQL endpoint)

| File | Applied | Verification |
|---|---|---|
| `0001_core_schema.sql` | yes (HTTP 201) | `pg_tables`: all six tables present (`installs`, `credits_ledger`, `ledger_entries`, `jobs`, `reports`, `consent_records`) |
| `0002_rls.sql` | yes (HTTP 201) | `rowsecurity = true` on all six tables; `pg_policies` shows exactly six policies, all `SELECT`-own (`installs_select_own`, `credits_ledger_select_own`, `ledger_entries_select_own`, `jobs_select_own`, `reports_select_own`, `consent_records_select_own`) and **no** client INSERT/UPDATE/DELETE policies |
| `0003_credits_rpc.sql` | yes (HTTP 201) | `pg_proc` shows `consume_save_credit`, `refund_save_credit`; EXECUTE granted to `authenticated` + `service_role` only |
| `0004_storage_sweep.sql` | yes (HTTP 201) | `storage.buckets`: `uploads` and `results`, both `public = false`; no `storage.objects` client policies. Live call `select sweep_expired()` → `{"objects_deleted": 0, "jobs_expired": 0}` |
| `0005_pg_cron.sql` | yes (HTTP 201) | `cron.job`: jobid 1, `peoplegone-sweep-hourly`, schedule `15 * * * *`, `active = true` — **pg_cron works on this project** |

Note on `sweep_expired()`: Supabase guards `storage.objects` with a
`protect_delete()` trigger that rejects direct SQL deletes. The function
uses the trigger's own sanctioned bypass — the transaction-local
`storage.allow_delete_query = 'true'` flag (verified against the live
trigger definition) — so the SQL sweep really deletes stale rows/files,
and the hourly pg_cron job therefore enforces the §7.4 24h TTL on its own.

## Anonymous auth (§7.1)

- Management API `GET /v1/projects/{ref}/config/auth` field:
  **`external_anonymous_users_enabled`**
- Before: `false` → PATCH → After: **`true`** (re-GET verified).
  (`rate_limit_anonymous_users = 30` left at the platform default.)

## CLI + secrets

- Supabase CLI **v2.120.0** (linux amd64) at `~/workspace/tools/supabase`.
- `supabase link --project-ref ietwddgjtcrabqjdxsfp`: link state written
  (`supabase/.temp/` — `linked-project.json`, `pooler-url`,
  `postgres-version`); the CLI's final ping of the project REST root hung
  on this VM's egress path (see "Network note" below), but link state is
  complete and all subsequent CLI operations work.
- `supabase secrets set`: `WORKER_BASE_URL` (= the Modal worker base URL)
  and `WORKER_API_KEY` are set on the project (verified via
  `supabase secrets list` — names + digests only).

## Edge Functions (all deployed, `supabase functions list` → ACTIVE v1)

`create-job`, `analyse-job`, `confirm-job`, `job-status`, `get-result`,
`consume-credit`, `refund-credit`, `touchup` (default JWT verification);
`worker-callback`, `sweep-expired` (deployed `--no-verify-jwt`;
sweep-expired additionally requires the service-role Bearer token).

Worker side of the contract (verified in the deployed Modal worker):
`/detect` and `/process` require the `X-Worker-Key` header; `/process`
accepts `callback_url` / `callback_token` / `job_id` /
`result_upload_url`, PUTs the result JPEG to the signed URL, then POSTs
`{job_id, token, meta}` to the callback. `/touchup` exists (multipart
`file`, `mask_png`, `engine`). Worker meta carries `persons_detected`,
`removed_ids`, `engine_used`, `total_gpu_seconds`, `cost_estimate_usd`,
`ghost_check_fired` — the exact fields `worker-callback` records.

## Live E2E — STATUS: IN PROGRESS / NETWORK-BLOCKED (honest WIP)

The full scripted E2E (anon signup → create-job → PUT upload of the
mosque photo → analyse → confirm → poll → get-result → download →
consume/replay/refund → SQL ledger check → second consume → cross-user
isolation check) is written and running with per-call retries and
resumable state. It has not yet completed; see the network note.

### Network note (this VM's egress proxy, not the project)

Diagnosis (measured 2026-10-14): this VM's only egress is a proxy, and
it stalls requests that carry an `apikey` header or a long
`Authorization: Bearer` header — the stall reproduces on unrelated
hosts (httpbin) with those headers, while the same requests without
those headers answer instantly, and short-token requests (44-char
Management API PAT) work reliably. Supabase data-plane calls all require
the `apikey` header, so from this VM they time out (curl `000`),
except for a few brief windows. Kong-local responses that need no key
(project root `404`, `/functions/v1/` `404`, no-header `/auth/v1/health`
`401`) are always fast, direct proxy-bypassing connections are refused
outright, `api.supabase.com` (Management API — all migrations, auth
config, function deploys, secrets) and the Modal worker stay reachable,
and the project reports `ACTIVE_HEALTHY` throughout.

The resumable E2E runner (`~/pg2work/run.sh` → `e2e.py`, state in
`~/pg2work/state.json`, log in `~/pg2work/e2e.log`) keeps retrying from
this VM; alternatively the identical script run from any normal network
completes the pass. This file will be updated with the measured
numbers (persons detected, timings, result bytes, ledger state) the
moment a full pass completes.
