create table if not exists public.pricing_features (
  id uuid primary key default gen_random_uuid(), feature_key text not null,
  name text not null, description text not null default '',
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null default 'INR' check (char_length(currency) = 3),
  tax_bps integer not null default 0 check (tax_bps between 0 and 10000),
  pricing_model text not null check (pricing_model in ('one_time','pay_per_view','subscription','per_lead')),
  duration_days integer check (duration_days is null or duration_days > 0),
  is_active boolean not null default true, effective_from timestamptz not null default now(),
  effective_to timestamptz, version integer not null default 1 check (version > 0),
  created_by uuid references auth.users(id), created_at timestamptz not null default now(),
  unique (feature_key, version), check (effective_to is null or effective_to > effective_from)
);
create unique index if not exists pricing_features_one_active on public.pricing_features(feature_key) where is_active and effective_to is null;

create table if not exists public.business_plans (
  id uuid primary key default gen_random_uuid(), plan_key text not null unique,
  name text not null, description text not null default '', amount_minor bigint not null check (amount_minor >= 0),
  currency text not null default 'INR' check (char_length(currency) = 3), duration_days integer not null check (duration_days > 0),
  image_limit integer not null default 5 check (image_limit >= 0), lead_limit integer not null default 0 check (lead_limit >= 0),
  priority_rank integer not null default 0, is_active boolean not null default true,
  entitlements jsonb not null default '{}'::jsonb, created_by uuid references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.owner_plan_subscriptions (
  id uuid primary key default gen_random_uuid(), owner_user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.business_plans(id), price_version integer not null default 1,
  amount_minor bigint not null check (amount_minor >= 0), currency text not null,
  starts_at timestamptz not null default now(), expires_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','active','expired','cancelled')),
  payment_id uuid references public.payments(id), created_at timestamptz not null default now()
);
create unique index if not exists owner_one_active_plan on public.owner_plan_subscriptions(owner_user_id) where status = 'active';

create table if not exists public.contact_entitlements (
  id uuid primary key default gen_random_uuid(), customer_user_id uuid not null references auth.users(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade, field_key text not null check (field_key in ('phone','whatsapp','email')),
  pricing_feature_key text not null, price_version integer not null, amount_minor bigint not null check (amount_minor >= 0),
  currency text not null, payment_id uuid references public.payments(id), transaction_id uuid,
  granted_at timestamptz not null default now(),
  expires_at timestamptz, unique (customer_user_id, venue_id, field_key)
);
create index if not exists contact_entitlements_lookup on public.contact_entitlements(customer_user_id, venue_id, field_key);

create table if not exists public.business_payment_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references auth.users(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  owner_user_id uuid references auth.users(id),
  field_key text not null check (field_key in ('phone','whatsapp','email')),
  pricing_feature_key text not null,
  price_version integer not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  provider text not null default 'razorpay',
  provider_order_id text unique,
  provider_payment_id text unique,
  status text not null default 'pending' check (status in ('pending','captured','failed','refunded')),
  entitlement_expires_at timestamptz,
  reveal_limit integer check (reveal_limit is null or reveal_limit > 0),
  created_at timestamptz not null default now(),
  captured_at timestamptz,
  updated_at timestamptz not null default now()
);
create unique index if not exists business_payment_pending_key
  on public.business_payment_transactions(customer_user_id, venue_id, field_key)
  where status = 'pending';
alter table public.business_payment_transactions enable row level security;
create policy business_payment_customer_read on public.business_payment_transactions for select to authenticated
  using (customer_user_id = auth.uid());

create table if not exists public.contact_access_audit (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references auth.users(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  field_key text not null,
  entitlement_id uuid references public.contact_entitlements(id),
  accessed_at timestamptz not null default now()
);

alter table public.pricing_features enable row level security;
alter table public.business_plans enable row level security;
alter table public.owner_plan_subscriptions enable row level security;
alter table public.contact_entitlements enable row level security;
alter table public.contact_access_audit enable row level security;

create policy pricing_features_admin_read on public.pricing_features for select to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
create policy pricing_features_admin_write on public.pricing_features for all to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')) with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
create policy business_plans_admin_read on public.business_plans for select to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
create policy business_plans_admin_write on public.business_plans for all to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')) with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
create policy owner_plan_self_read on public.owner_plan_subscriptions for select to authenticated using (owner_user_id = auth.uid());
create policy owner_plan_admin_read on public.owner_plan_subscriptions for select to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
create policy contact_entitlement_self_read on public.contact_entitlements for select to authenticated using (customer_user_id = auth.uid());
create policy contact_access_audit_admin_read on public.contact_access_audit for select to authenticated using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

create or replace function public.get_contact_with_entitlement(p_venue_id uuid, p_field_key text)
returns table(field_key text, field_value text)
language plpgsql security definer set search_path = public
as $$
declare entitlement_id uuid;
begin
  if auth.uid() is null or p_field_key not in ('phone', 'whatsapp', 'email') then return; end if;
  select e.id into entitlement_id from public.contact_entitlements e
  left join public.payments p on p.id = e.payment_id
  left join public.business_payment_transactions bt on bt.id = e.transaction_id
  where e.customer_user_id = auth.uid() and e.venue_id = p_venue_id and e.field_key = p_field_key
    and (p.status = 'captured' or bt.status = 'captured')
    and (e.expires_at is null or e.expires_at > now());
  if entitlement_id is null then return; end if;
  insert into public.contact_access_audit(customer_user_id, venue_id, field_key, entitlement_id)
  values (auth.uid(), p_venue_id, p_field_key, entitlement_id);
  return query select p_field_key, case p_field_key
    when 'phone' then v.contact_whatsapp when 'whatsapp' then v.contact_whatsapp else null end
    from public.venues v where v.id = p_venue_id;
end;
$$;
revoke all on function public.get_contact_with_entitlement(uuid, text) from public;
grant execute on function public.get_contact_with_entitlement(uuid, text) to authenticated;
