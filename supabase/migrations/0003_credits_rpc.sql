-- 0003_credits_rpc.sql — Atomic save-credit ledger RPCs (§7.2, §9.1, §9.4)
-- The server ledger is the ONLY source of truth for saves. Consume happens
-- at save time, atomically, guarded by an idempotency key per save attempt:
-- a retried consume never double-charges; a refunded key can never be
-- re-consumed (the credit was returned; a new save needs a new key).
-- Free tier: 10 full-res saves per UTC calendar month (§9.1).
-- Pro: fair-use cap 300 saves/month (§8.2 rule 5, §9.4); beyond the cap the
-- outcome is payment_required (never a silent charge or a faked allow).

create or replace function public.consume_save_credit(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_period text := to_char(now() at time zone 'utc', 'YYYY-MM');
  v_row public.credits_ledger%rowtype;
  v_existing_id bigint;
  v_refunded boolean;
  v_is_pro boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.installs (id) values (v_uid)
    on conflict (id) do nothing;
  insert into public.credits_ledger (install_id, period) values (v_uid, v_period)
    on conflict (install_id, period) do nothing;

  select * into v_row from public.credits_ledger
    where install_id = v_uid and period = v_period
    for update;

  v_is_pro := v_row.pro_status
    and (v_row.pro_until is null or v_row.pro_until > now());

  -- Idempotent replay: this key was already consumed.
  select id into v_existing_id from public.ledger_entries
    where install_id = v_uid and idempotency_key = p_idempotency_key
      and kind = 'consume'
    limit 1;

  if v_existing_id is not null then
    select exists (
      select 1 from public.ledger_entries
      where install_id = v_uid and idempotency_key = p_idempotency_key
        and kind = 'refund'
    ) into v_refunded;

    if v_refunded then
      -- The credit was already returned; do not re-consume this key.
      return jsonb_build_object(
        'allowed', false,
        'payment_required', true,
        'is_pro', v_is_pro,
        'saves_left', case when v_is_pro then null
          else greatest(10 - v_row.free_saves_used, 0) end
      );
    end if;

    return jsonb_build_object(
      'allowed', true,
      'payment_required', false,
      'is_pro', v_is_pro,
      'saves_left', case when v_is_pro then null
        else greatest(10 - v_row.free_saves_used, 0) end
    );
  end if;

  if v_is_pro then
    if v_row.fair_use_saves_used >= 300 then
      return jsonb_build_object(
        'allowed', false, 'payment_required', true,
        'is_pro', true, 'saves_left', null
      );
    end if;
    update public.credits_ledger
      set fair_use_saves_used = fair_use_saves_used + 1, updated_at = now()
      where install_id = v_uid and period = v_period;
    insert into public.ledger_entries
      (install_id, period, kind, counter_kind, idempotency_key)
      values (v_uid, v_period, 'consume', 'fair_use', p_idempotency_key);
    return jsonb_build_object(
      'allowed', true, 'payment_required', false,
      'is_pro', true, 'saves_left', null
    );
  end if;

  if v_row.free_saves_used < 10 then
    update public.credits_ledger
      set free_saves_used = free_saves_used + 1, updated_at = now()
      where install_id = v_uid and period = v_period;
    insert into public.ledger_entries
      (install_id, period, kind, counter_kind, idempotency_key)
      values (v_uid, v_period, 'consume', 'free', p_idempotency_key);
    return jsonb_build_object(
      'allowed', true, 'payment_required', false,
      'is_pro', false, 'saves_left', 10 - (v_row.free_saves_used + 1)
    );
  end if;

  return jsonb_build_object(
    'allowed', false, 'payment_required', true,
    'is_pro', false, 'saves_left', 0
  );
end;
$$;

create or replace function public.refund_save_credit(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_consume public.ledger_entries%rowtype;
  v_found boolean := false;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_consume from public.ledger_entries
    where install_id = v_uid and idempotency_key = p_idempotency_key
      and kind = 'consume'
    limit 1;
  v_found := found;

  if not v_found then
    return jsonb_build_object('ok', true, 'refunded', false);
  end if;

  if exists (
    select 1 from public.ledger_entries
    where install_id = v_uid and idempotency_key = p_idempotency_key
      and kind = 'refund'
  ) then
    return jsonb_build_object('ok', true, 'refunded', false);
  end if;

  -- Decrement whichever counter the consume incremented, in ITS period.
  if v_consume.counter_kind = 'fair_use' then
    update public.credits_ledger
      set fair_use_saves_used = greatest(fair_use_saves_used - 1, 0),
          updated_at = now()
      where install_id = v_uid and period = v_consume.period;
  else
    update public.credits_ledger
      set free_saves_used = greatest(free_saves_used - 1, 0),
          updated_at = now()
      where install_id = v_uid and period = v_consume.period;
  end if;

  insert into public.ledger_entries
    (install_id, period, kind, counter_kind, idempotency_key, job_id)
    values (v_uid, v_consume.period, 'refund', v_consume.counter_kind,
            p_idempotency_key, v_consume.job_id);

  return jsonb_build_object('ok', true, 'refunded', true);
end;
$$;

revoke all on function public.consume_save_credit(text) from public;
revoke all on function public.refund_save_credit(text) from public;
grant execute on function public.consume_save_credit(text) to authenticated;
grant execute on function public.refund_save_credit(text) to authenticated;
grant execute on function public.consume_save_credit(text) to service_role;
grant execute on function public.refund_save_credit(text) to service_role;
