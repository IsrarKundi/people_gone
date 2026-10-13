-- 0005_pg_cron.sql — Hourly retention sweep schedule (§7.4)
-- Attempted 2026-10-14 via the Management API. Result recorded in
-- supabase/E2E_EVIDENCE.md. If pg_cron is unavailable on this project the
-- sweep still runs via the sweep-expired Edge Function (invoked by an
-- external scheduler); this file is the in-database schedule attempt.

create extension if not exists pg_cron;

select cron.schedule(
  'peoplegone-sweep-hourly',
  '15 * * * *',
  $$select public.sweep_expired();$$
);
