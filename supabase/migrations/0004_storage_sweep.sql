-- 0004_storage_sweep.sql — Private buckets + 24h retention sweep (§7.2, §7.4)
-- Buckets are PRIVATE (public = false). There are deliberately NO
-- storage.objects client policies: files move only via signed URLs minted
-- by Edge Functions (upload / result download) and service-role access.
-- Retention is code, not manual cleanup (§7.4): photos auto-delete 24h
-- after upload; jobs past expiry are marked expired in the same run.

insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', false), ('results', 'results', false)
on conflict (id) do nothing;

create or replace function public.sweep_expired()
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_objects int := 0;
  v_jobs int := 0;
begin
  -- Supabase guards storage tables with a protect_delete trigger; the
  -- sanctioned bypass for a deliberate, code-driven sweep is the
  -- transaction-local storage.allow_delete_query flag (verified against
  -- the live protect_delete() definition, 2026-10-14).
  perform set_config('storage.allow_delete_query', 'true', true);

  delete from storage.objects
    where bucket_id in ('uploads', 'results')
      and created_at < now() - interval '24 hours';
  get diagnostics v_objects = row_count;

  update public.jobs
    set status = 'expired', updated_at = now()
    where expires_at < now()
      and status in ('created', 'awaiting_confirm', 'processing');
  get diagnostics v_jobs = row_count;

  -- Counts only are returned/logged — never file names or URLs (§7.4).
  return jsonb_build_object(
    'objects_deleted', v_objects,
    'jobs_expired', v_jobs
  );
end;
$$;

revoke all on function public.sweep_expired() from public;
grant execute on function public.sweep_expired() to service_role;
