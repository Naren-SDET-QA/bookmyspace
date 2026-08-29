-- Additive booking approval flow. Apply only after review in DEV.
alter type public.booking_status add value if not exists 'rejected';
alter type public.booking_status add value if not exists 'pending_owner_approval';

alter table public.venues
  add column if not exists booking_token_amount numeric(12,2),
  add column if not exists booking_token_refund_policy text not null default 'full_token_refund';

alter table public.venues
  add constraint venues_token_amount_valid check (booking_token_amount is null or booking_token_amount > 0),
  add constraint venues_token_refund_policy_valid check (booking_token_refund_policy in ('full_token_refund','no_refund','configured'));

create table if not exists public.booking_orders (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete restrict,
  order_ref text not null unique,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'INR',
  created_at timestamptz not null default now()
);

create table if not exists public.booking_approval_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  actor_id uuid not null references auth.users(id),
  action text not null check (action in ('approved','rejected')),
  refund_id uuid references public.refunds(id),
  created_at timestamptz not null default now(),
  unique (booking_id, action)
);

alter table public.booking_orders enable row level security;
alter table public.booking_approval_events enable row level security;

create policy booking_orders_customer_read on public.booking_orders for select to authenticated
using (exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid()));
create policy booking_orders_owner_read on public.booking_orders for select to authenticated
using (exists (select 1 from public.bookings b join public.venues v on v.id=b.venue_id join public.organizations o on o.id=v.org_id where b.id=booking_id and o.owner_user_id=auth.uid()));
create policy booking_orders_admin_read on public.booking_orders for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id=auth.uid() and r.role in ('administrator','super_administrator') and r.revoked_at is null));
create policy booking_approval_customer_read on public.booking_approval_events for select to authenticated
using (exists (select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()));
create policy booking_approval_owner_read on public.booking_approval_events for select to authenticated
using (exists (select 1 from public.bookings b join public.venues v on v.id=b.venue_id join public.organizations o on o.id=v.org_id where b.id=booking_id and o.owner_user_id=auth.uid()));
create policy booking_approval_admin_read on public.booking_approval_events for select to authenticated
using (exists (select 1 from public.user_roles r where r.user_id=auth.uid() and r.role in ('administrator','super_administrator') and r.revoked_at is null));

create or replace function public.owner_decide_booking(p_booking_id uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare b public.bookings; v public.venues; o public.organizations; order_row public.booking_orders; event_id uuid;
begin
  if auth.uid() is null or p_decision not in ('approve','reject') then
    raise exception 'unauthorized or invalid decision' using errcode='42501';
  end if;
  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'booking not found' using errcode='P0002'; end if;
  select * into v from public.venues where id=b.venue_id for update;
  select * into o from public.organizations where id=v.org_id;
  if o.owner_user_id is distinct from auth.uid() and not exists (select 1 from public.user_roles r where r.user_id=auth.uid() and r.role in ('administrator','super_administrator') and r.revoked_at is null) then
    raise exception 'not owner' using errcode='42501';
  end if;
  if b.status not in ('pending','pending_owner_approval') then raise exception 'invalid transition' using errcode='55000'; end if;
  if p_decision='reject' then
    update public.bookings set status='rejected', cancelled_at=now(), updated_at=now() where id=b.id;
    insert into public.booking_approval_events(booking_id,actor_id,action) values(b.id,auth.uid(),'rejected') returning id into event_id;
    return jsonb_build_object('status','rejected','booking_id',b.id);
  end if;
  if exists(select 1 from public.bookings x where x.id<>b.id and x.venue_id=b.venue_id and x.book_date=b.book_date and x.status in ('confirmed','completed') and x.start_time < b.end_time and x.end_time > b.start_time) then
    raise exception 'slot unavailable' using errcode='23P01';
  end if;
  update public.bookings set status='confirmed', confirmed_at=now(), updated_at=now() where id=b.id and status='pending';
  insert into public.booking_orders(booking_id,order_ref,amount,currency) values(b.id,'BMS-ORD-'||replace(gen_random_uuid()::text,'-',''),b.total_amount,b.currency) returning * into order_row;
  insert into public.booking_approval_events(booking_id,actor_id,action) values(b.id,auth.uid(),'approved') returning id into event_id;
  return jsonb_build_object('status','confirmed','booking_id',b.id,'order_id',order_row.id);
end $$;

revoke all on function public.owner_decide_booking(uuid,text) from public, anon;
grant execute on function public.owner_decide_booking(uuid,text) to authenticated, service_role;
