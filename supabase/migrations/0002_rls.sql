-- 0002_rls.sql — Row Level Security (§7.2/§7.3 security rules)
-- RLS enabled on ALL tables. Clients may SELECT only their own rows.
-- There are deliberately NO client INSERT/UPDATE/DELETE policies:
-- every write happens through the service role or SECURITY DEFINER RPCs.

alter table public.installs enable row level security;
alter table public.credits_ledger enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.jobs enable row level security;
alter table public.reports enable row level security;
alter table public.consent_records enable row level security;

drop policy if exists installs_select_own on public.installs;
create policy installs_select_own on public.installs
  for select using (auth.uid() = id);

drop policy if exists credits_ledger_select_own on public.credits_ledger;
create policy credits_ledger_select_own on public.credits_ledger
  for select using (auth.uid() = install_id);

drop policy if exists ledger_entries_select_own on public.ledger_entries;
create policy ledger_entries_select_own on public.ledger_entries
  for select using (auth.uid() = install_id);

drop policy if exists jobs_select_own on public.jobs;
create policy jobs_select_own on public.jobs
  for select using (auth.uid() = install_id);

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select using (auth.uid() = install_id);

drop policy if exists consent_records_select_own on public.consent_records;
create policy consent_records_select_own on public.consent_records
  for select using (auth.uid() = install_id);
