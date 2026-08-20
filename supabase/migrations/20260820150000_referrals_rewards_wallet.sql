-- M2: referral attribution, reward rules and server-authoritative wallet ledger.
create table public.referral_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  referral_code text not null unique check (referral_code = upper(referral_code)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reward_configs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  referrer_amount numeric(12,2) not null default 0 check (referrer_amount >= 0),
  referee_amount numeric(12,2) not null default 0 check (referee_amount >= 0),
  currency text not null default 'INR',
  is_active boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index reward_configs_one_active on public.reward_configs (is_active)
where is_active;

create table public.referral_attributions (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referred_user_id uuid not null unique references auth.users(id) on delete cascade,
  referral_code text not null references public.referral_profiles(referral_code),
  status text not null default 'pending' check (status in ('pending','qualified','rewarded','rejected')),
  created_at timestamptz not null default now(),
  qualified_at timestamptz,
  rewarded_at timestamptz,
  rejected_reason text,
  check (referrer_user_id <> referred_user_id)
);

create table public.referral_rewards (
  id uuid primary key default gen_random_uuid(),
  attribution_id uuid not null references public.referral_attributions(id) on delete cascade,
  beneficiary_user_id uuid not null references auth.users(id) on delete cascade,
  reward_type text not null check (reward_type in ('referrer','referred')),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'INR',
  status text not null default 'pending' check (status in ('pending','posted','reversed')),
  created_at timestamptz not null default now(),
  posted_at timestamptz,
  unique (attribution_id, beneficiary_user_id, reward_type)
);

create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  direction text not null check (direction in ('credit','debit')),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'INR',
  status text not null default 'posted' check (status in ('pending','posted','reversed')),
  source_type text not null,
  source_id uuid,
  description text not null,
  created_at timestamptz not null default now(),
  unique (user_id, source_type, source_id, direction)
);

create index referral_attributions_referrer_idx on public.referral_attributions(referrer_user_id, created_at desc);
create index referral_rewards_beneficiary_idx on public.referral_rewards(beneficiary_user_id, created_at desc);
create index wallet_ledger_user_idx on public.wallet_ledger(user_id, created_at desc);

alter table public.referral_profiles enable row level security;
alter table public.reward_configs enable row level security;
alter table public.referral_attributions enable row level security;
alter table public.referral_rewards enable row level security;
alter table public.wallet_ledger enable row level security;

create policy referral_profiles_own_read on public.referral_profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy reward_configs_admin_read on public.reward_configs for select to authenticated using (public.has_role((select auth.uid()), 'administrator') or public.has_role((select auth.uid()), 'super_administrator'));
create policy reward_configs_admin_write on public.reward_configs for all to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or public.has_role((select auth.uid()), 'super_administrator'));
create policy referral_attributions_own_read on public.referral_attributions for select to authenticated
  using ((select auth.uid()) = referrer_user_id or (select auth.uid()) = referred_user_id);
create policy referral_rewards_own_read on public.referral_rewards for select to authenticated using ((select auth.uid()) = beneficiary_user_id);
create policy wallet_ledger_own_read on public.wallet_ledger for select to authenticated using ((select auth.uid()) = user_id);

create or replace function public.ensure_referral_profile()
returns public.referral_profiles
language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_code text; v_row public.referral_profiles;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select * into v_row from public.referral_profiles where user_id = v_user;
  if found then return v_row; end if;
  loop
    v_code := 'BMS-' || upper(substr(md5(v_user::text || clock_timestamp()::text || random()::text), 1, 8));
    begin
      insert into public.referral_profiles(user_id, referral_code) values (v_user, v_code) returning * into v_row;
      return v_row;
    exception when unique_violation then
      select * into v_row from public.referral_profiles where user_id = v_user;
      if found then return v_row; end if;
    end;
  end loop;
end $$;

create or replace function public.claim_referral(p_referral_code text)
returns public.referral_attributions
language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_profile public.referral_profiles; v_row public.referral_attributions;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select * into v_profile from public.referral_profiles where referral_code = upper(trim(p_referral_code));
  if not found then raise exception 'referral_code_not_found'; end if;
  if v_profile.user_id = v_user then raise exception 'self_referral_not_allowed'; end if;
  insert into public.referral_attributions(referrer_user_id, referred_user_id, referral_code)
  values (v_profile.user_id, v_user, v_profile.referral_code)
  on conflict (referred_user_id) do nothing;
  select * into v_row from public.referral_attributions where referred_user_id = v_user;
  return v_row;
end $$;

create or replace function public.post_referral_reward(p_attribution_id uuid)
returns integer
language plpgsql security definer set search_path = public
as $$
declare v_count integer := 0; v_attr public.referral_attributions; v_config public.reward_configs; v_reward public.referral_rewards;
begin
  if not (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')) then raise exception 'admin_required'; end if;
  select * into v_attr from public.referral_attributions where id = p_attribution_id for update;
  if not found then raise exception 'attribution_not_found'; end if;
  select * into v_config from public.reward_configs where is_active order by created_at desc limit 1;
  if not found then raise exception 'active_reward_config_not_found'; end if;
  if v_config.referrer_amount > 0 then
    insert into public.referral_rewards(attribution_id, beneficiary_user_id, reward_type, amount, currency, status, posted_at)
    values (v_attr.id, v_attr.referrer_user_id, 'referrer', v_config.referrer_amount, v_config.currency, 'posted', now()) on conflict do nothing returning * into v_reward;
    if found then insert into public.wallet_ledger(user_id,direction,amount,currency,status,source_type,source_id,description) values (v_attr.referrer_user_id,'credit',v_config.referrer_amount,v_config.currency,'posted','referral_reward',v_reward.id,'Referral reward') on conflict do nothing; v_count := v_count + 1; end if;
  end if;
  if v_config.referee_amount > 0 then
    insert into public.referral_rewards(attribution_id, beneficiary_user_id, reward_type, amount, currency, status, posted_at)
    values (v_attr.id, v_attr.referred_user_id, 'referred', v_config.referee_amount, v_config.currency, 'posted', now()) on conflict do nothing returning * into v_reward;
    if found then insert into public.wallet_ledger(user_id,direction,amount,currency,status,source_type,source_id,description) values (v_attr.referred_user_id,'credit',v_config.referee_amount,v_config.currency,'posted','referral_reward',v_reward.id,'Welcome referral reward') on conflict do nothing; v_count := v_count + 1; end if;
  end if;
  update public.referral_attributions set status = 'rewarded', rewarded_at = coalesce(rewarded_at, now()) where id = v_attr.id;
  return v_count;
end $$;

revoke all on function public.ensure_referral_profile() from public;
revoke all on function public.claim_referral(text) from public;
revoke all on function public.post_referral_reward(uuid) from public;
grant execute on function public.ensure_referral_profile() to authenticated;
grant execute on function public.claim_referral(text) to authenticated;
grant execute on function public.post_referral_reward(uuid) to authenticated;
