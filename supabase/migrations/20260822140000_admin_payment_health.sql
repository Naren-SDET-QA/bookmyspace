-- Admin-only payment health + stale-payment reconcile.
-- Does not change Razorpay order creation, webhooks, or refunds.
-- Does not persist business data on the client.

create or replace function public.admin_payment_health_summary()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_payments jsonb;
  v_refunds jsonb;
  v_holds integer;
begin
  if not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  select coalesce(jsonb_object_agg(status, cnt), '{}'::jsonb)
  into v_payments
  from (
    select status::text as status, count(*)::int as cnt
    from public.payments
    group by status
  ) s;

  select coalesce(jsonb_object_agg(status, cnt), '{}'::jsonb)
  into v_refunds
  from (
    select status as status, count(*)::int as cnt
    from public.refunds
    group by status
  ) r;

  select count(*)::int into v_holds
  from public.booking_holds
  where status = 'active'
    and expires_at > now();

  return jsonb_build_object(
    'payments', v_payments,
    'refunds', v_refunds,
    'active_holds', v_holds,
    'generated_at', now()
  );
end;
$$;

create or replace function public.admin_reconcile_stale_payments(
  p_stale_after_minutes integer default 30
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  if p_stale_after_minutes < 5 then
    raise exception 'stale_window_too_short';
  end if;

  v_count := public.reconcile_stale_payments(p_stale_after_minutes);

  begin
    insert into public.audit_logs (actor_id, action, entity_type, details)
    values (
      auth.uid(),
      'payments.reconcile_stale',
      'payment',
      jsonb_build_object('marked_failed', v_count, 'minutes', p_stale_after_minutes)
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return v_count;
end;
$$;

grant execute on function public.admin_payment_health_summary() to authenticated;
grant execute on function public.admin_reconcile_stale_payments(integer) to authenticated;
