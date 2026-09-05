-- Generic display promotions. Pricing/coupon application remains authoritative
-- in the existing booking/payment path; this table does not replace coupons.
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 160),
  short_description text,
  description text,
  banner_media_id uuid references public.venue_images(id) on delete set null,
  active boolean not null default false,
  start_at timestamptz,
  end_at timestamptz,
  priority integer not null default 0,
  sort_order integer not null default 0,
  cta_text text,
  cta_action text,
  offer_type text not null default 'promotional_text'
    check (offer_type in ('percentage_discount','fixed_discount','special_price','promotional_text')),
  discount_type text
    check (discount_type is null or discount_type in ('percentage','fixed')),
  discount_value numeric(12,2)
    check (discount_value is null or discount_value >= 0),
  accent_color text,
  background_color text,
  text_color text,
  badge text,
  icon text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_at is null or start_at is null or end_at > start_at),
  check (offer_type = 'promotional_text' or discount_value is not null)
);

create table if not exists public.promotion_categories (
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  category_id uuid not null references public.venue_categories(id) on delete cascade,
  primary key (promotion_id, category_id)
);

create table if not exists public.promotion_venues (
  promotion_id uuid not null references public.promotions(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  primary key (promotion_id, venue_id)
);

create index if not exists promotions_active_window_idx
  on public.promotions(active, start_at, end_at, priority desc, sort_order);
create index if not exists promotion_categories_category_idx
  on public.promotion_categories(category_id, promotion_id);
create index if not exists promotion_venues_venue_idx
  on public.promotion_venues(venue_id, promotion_id);

alter table public.promotions enable row level security;
alter table public.promotion_categories enable row level security;
alter table public.promotion_venues enable row level security;

drop policy if exists promotions_public_read on public.promotions;
create policy promotions_public_read on public.promotions for select using (
  active
  and (start_at is null or start_at <= now())
  and (end_at is null or end_at > now())
  and (
    (not exists (select 1 from public.promotion_categories pc where pc.promotion_id = promotions.id)
     and not exists (select 1 from public.promotion_venues pv where pv.promotion_id = promotions.id))
    or exists (
      select 1 from public.promotion_categories pc
      join public.venue_categories c on c.id = pc.category_id
      where pc.promotion_id = promotions.id
        and coalesce((c.metadata->>'active')::boolean, false)
        and coalesce((c.metadata->>'offers_enabled')::boolean, false)
    )
    or exists (
      select 1 from public.promotion_venues pv
      join public.venues v on v.id = pv.venue_id
      join public.venue_categories c on c.id = v.category_id
      where pv.promotion_id = promotions.id
        and v.is_active
        and coalesce((c.metadata->>'active')::boolean, false)
        and coalesce((c.metadata->>'offers_enabled')::boolean, false)
    )
  )
);

drop policy if exists promotion_categories_public_read on public.promotion_categories;
create policy promotion_categories_public_read on public.promotion_categories for select using (
  exists (select 1 from public.promotions p where p.id = promotion_categories.promotion_id)
);
drop policy if exists promotion_venues_public_read on public.promotion_venues;
create policy promotion_venues_public_read on public.promotion_venues for select using (
  exists (select 1 from public.promotions p where p.id = promotion_venues.promotion_id)
);

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='promotions' and policyname='promotions_admin_write') then
    create policy promotions_admin_write on public.promotions for all to authenticated
      using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
      with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
    create policy promotion_categories_admin_write on public.promotion_categories for all to authenticated
      using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
      with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
    create policy promotion_venues_admin_write on public.promotion_venues for all to authenticated
      using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
      with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
  end if;
end $$;
