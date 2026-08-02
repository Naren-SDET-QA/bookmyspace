-- ============================================================
-- BookMySpace — Migration 0006: Engagement, Notifications,
-- Events, Courses, Support, Coupons, Audit
-- ============================================================

-- ------------------------------------------------------------
-- REVIEWS
-- ------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  venue_id uuid not null references public.venues(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  title text,
  body text,
  owner_reply text,
  owner_replied_at timestamptz,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_id)
);

create index idx_reviews_venue on public.reviews(venue_id);
create index idx_reviews_user on public.reviews(user_id);

-- ------------------------------------------------------------
-- FAVORITES
-- ------------------------------------------------------------
create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, venue_id)
);

-- ------------------------------------------------------------
-- COUPONS
-- ------------------------------------------------------------
create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  description text,
  discount_type text not null check (discount_type in ('percentage', 'fixed')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  max_discount_amount numeric(12,2),
  min_booking_amount numeric(12,2) default 0,
  max_uses integer,
  max_uses_per_user integer default 1,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.booking_coupons (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  coupon_id uuid not null references public.coupons(id),
  discount_amount numeric(12,2) not null check (discount_amount >= 0)
);

-- ------------------------------------------------------------
-- NOTIFICATIONS
-- ------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null,
  token text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create index idx_notifications_user on public.notifications(user_id, created_at desc);
create index idx_notifications_unread on public.notifications(user_id) where is_read = false;
create index idx_device_tokens_user on public.device_tokens(user_id) where is_active;

-- ------------------------------------------------------------
-- AUDIT LOGS
-- ------------------------------------------------------------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  action text not null,
  entity_type text,
  entity_id uuid,
  details jsonb,
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index idx_audit_user on public.audit_logs(user_id, created_at desc);
create index idx_audit_entity on public.audit_logs(entity_type, entity_id);

-- ------------------------------------------------------------
-- SUPPORT
-- ------------------------------------------------------------
create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  category text,
  description text,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  assigned_to uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id),
  message text not null,
  created_at timestamptz not null default now()
);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  opened_by uuid not null references auth.users(id),
  reason text not null,
  status text not null default 'open' check (status in ('open', 'investigating', 'resolved', 'rejected')),
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_tickets_user on public.support_tickets(user_id, created_at desc);
create index idx_disputes_booking on public.disputes(booking_id);

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------
create type public.event_category as enum (
  'meeting', 'conference', 'workshop', 'sports', 'entertainment',
  'cultural', 'exhibition', 'community'
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  venue_id uuid references public.venues(id) on delete set null,
  category public.event_category not null,
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  capacity integer check (capacity > 0),
  ticket_price numeric(12,2) default 0 check (ticket_price >= 0),
  is_free boolean not null default false,
  cover_image text,
  status text not null default 'draft' check (status in ('draft', 'published', 'cancelled', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_events_starts on public.events(starts_at);
create index idx_events_org on public.events(org_id);

-- ------------------------------------------------------------
-- INSTITUTES & COURSES
-- ------------------------------------------------------------
create table public.institutes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  logo_image text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create type public.course_mode as enum ('online', 'offline', 'hybrid');

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references public.institutes(id) on delete cascade,
  title text not null,
  description text,
  mode public.course_mode not null default 'offline',
  venue_id uuid references public.venues(id) on delete set null,
  duration_weeks integer not null check (duration_weeks > 0),
  fee_amount numeric(12,2) not null check (fee_amount >= 0),
  instructor_name text,
  cover_image text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.course_batches (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  label text not null,
  starts_on date not null,
  capacity integer not null check (capacity > 0),
  enrolled_count integer not null default 0 check (enrolled_count >= 0),
  timetable jsonb,
  is_active boolean not null default true,
  unique (course_id, label, starts_on)
);

create table public.course_enrollments (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.course_batches(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  status text not null default 'enrolled' check (status in ('enrolled', 'dropped', 'completed')),
  created_at timestamptz not null default now(),
  unique (batch_id, user_id)
);

create index idx_courses_institute on public.courses(institute_id);
create index idx_batches_course on public.course_batches(course_id) where is_active;

-- ------------------------------------------------------------
-- COMMISSIONS (platform share of each booking)
-- ------------------------------------------------------------
create table public.platform_commissions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  org_id uuid not null references public.organizations(id),
  commission_rate numeric(5,2) not null,
  commission_amount numeric(12,2) not null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- RLS for engagement tables
-- ------------------------------------------------------------
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.coupons enable row level security;
alter table public.booking_coupons enable row level security;
alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;
alter table public.audit_logs enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
alter table public.disputes enable row level security;
alter table public.events enable row level security;
alter table public.institutes enable row level security;
alter table public.courses enable row level security;
alter table public.course_batches enable row level security;
alter table public.course_enrollments enable row level security;
alter table public.platform_commissions enable row level security;

create policy "reviews_public_read" on public.reviews for select using (true);
create policy "reviews_insert_own" on public.reviews for insert with check (auth.uid() = user_id);
create policy "reviews_update_own" on public.reviews for update using (auth.uid() = user_id);

create policy "favorites_own" on public.favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "coupons_public_read" on public.coupons for select using (is_active and (ends_at is null or ends_at > now()));
create policy "coupons_admin_write" on public.coupons for all using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);

create policy "notifications_own" on public.notifications for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "device_tokens_own" on public.device_tokens for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Audit logs: insert allowed for all authenticated; read only for admins.
create policy "audit_insert_any_auth" on public.audit_logs for insert with check (auth.uid() is not null);
create policy "audit_read_admin" on public.audit_logs for select using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);

create policy "tickets_own_or_support" on public.support_tickets for all using (
  auth.uid() = user_id
  or public.has_role(auth.uid(), 'support_agent')
  or public.has_role(auth.uid(), 'administrator')
) with check (auth.uid() = user_id);

create policy "messages_own_or_support" on public.support_ticket_messages for all using (
  auth.uid() = sender_id
  or public.has_role(auth.uid(), 'support_agent')
) with check (auth.uid() = sender_id);

create policy "disputes_own" on public.disputes for all using (auth.uid() = opened_by) with check (auth.uid() = opened_by);

create policy "events_public_read" on public.events for select using (status = 'published');
create policy "events_org_write" on public.events for all using (
  exists (select 1 from public.organizations o where o.id = org_id and o.owner_user_id = auth.uid())
) with check (
  exists (select 1 from public.organizations o where o.id = org_id and o.owner_user_id = auth.uid())
);

create policy "institutes_public_read" on public.institutes for select using (true);
create policy "institutes_org_write" on public.institutes for all using (
  exists (select 1 from public.organizations o where o.id = org_id and o.owner_user_id = auth.uid())
) with check (
  exists (select 1 from public.organizations o where o.id = org_id and o.owner_user_id = auth.uid())
);

create policy "courses_public_read" on public.courses for select using (status = 'published');
create policy "courses_org_write" on public.courses for all using (
  exists (select 1 from public.institutes i
    join public.organizations o on o.id = i.org_id
    where i.id = institute_id and o.owner_user_id = auth.uid())
) with check (
  exists (select 1 from public.institutes i
    join public.organizations o on o.id = i.org_id
    where i.id = institute_id and o.owner_user_id = auth.uid())
);

create policy "batches_public_read" on public.course_batches for select using (is_active);
create policy "enrollments_own" on public.course_enrollments for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "commissions_admin_read" on public.platform_commissions for select using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);
