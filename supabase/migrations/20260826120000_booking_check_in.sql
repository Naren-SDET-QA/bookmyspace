-- Dedicated booking check-in slice. This intentionally does not replay the
-- broad Flutter parity foundation migration.
create table if not exists public.booking_check_ins (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  checked_in_by uuid not null references auth.users(id),
  method text not null default 'code'
    check (method in ('qr', 'code', 'manual')),
  created_at timestamptz not null default now()
);

create unique index if not exists booking_check_ins_one_per_booking
  on public.booking_check_ins (booking_id);

alter table public.booking_check_ins enable row level security;

drop policy if exists booking_check_ins_owner_read on public.booking_check_ins;
create policy booking_check_ins_owner_read
  on public.booking_check_ins for select
  using (
    public.has_role(auth.uid(), 'administrator'::public.user_role)
    or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
    or exists (
      select 1
      from public.bookings b
      join public.venues v on v.id = b.venue_id
      join public.organizations o on o.id = v.org_id
      where b.id = booking_id
        and (o.owner_user_id = auth.uid() or b.user_id = auth.uid())
    )
  );

create or replace function public.check_in_booking(
  p_code text,
  p_method text default 'code'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking public.bookings;
  v_existing uuid;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if p_method not in ('qr', 'code', 'manual') then
    raise exception 'invalid_check_in_method';
  end if;

  select b.* into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where (b.id::text = p_code or b.id::text like p_code || '%')
    and (
      o.owner_user_id = auth.uid()
      or public.has_role(auth.uid(), 'administrator'::public.user_role)
      or public.has_role(auth.uid(), 'super_administrator'::public.user_role)
    )
  order by b.created_at desc
  limit 1;

  if v_booking is null then
    raise exception 'booking_not_found_or_not_owner';
  end if;

  if v_booking.status not in ('confirmed'::public.booking_status, 'completed'::public.booking_status) then
    raise exception 'booking_not_eligible_for_check_in';
  end if;

  select id into v_existing
  from public.booking_check_ins
  where booking_id = v_booking.id;

  if v_existing is not null then
    return jsonb_build_object(
      'ok', true,
      'already_checked_in', true,
      'booking_id', v_booking.id,
      'check_in_id', v_existing
    );
  end if;

  insert into public.booking_check_ins (booking_id, checked_in_by, method)
  values (v_booking.id, auth.uid(), p_method)
  returning id into v_id;

  begin
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'booking.check_in',
      'booking',
      v_booking.id,
      jsonb_build_object('method', p_method)
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'already_checked_in', false,
    'booking_id', v_booking.id,
    'check_in_id', v_id
  );
end;
$$;

revoke all on function public.check_in_booking(text, text) from public, anon;
grant execute on function public.check_in_booking(text, text) to authenticated;
