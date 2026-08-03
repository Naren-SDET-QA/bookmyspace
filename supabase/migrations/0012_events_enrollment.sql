-- ============================================================
-- BookMySpace — Migration 0012: Event Registrations, Atomic
-- Enrollment, and Demo Events/Courses Content
--
-- Adds the missing event ticketing table plus atomic, capacity-safe
-- functions for registering for an event and enrolling in a course
-- batch (the same advisory-lock pattern as booking holds). Also seeds
-- demo events, institutes, courses and batches for local development.
-- ============================================================

-- ------------------------------------------------------------
-- EVENT REGISTRATIONS (event tickets)
-- ------------------------------------------------------------
create table public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  status text not null default 'registered'
    check (status in ('registered', 'cancelled', 'checked_in')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index idx_event_regs_event on public.event_registrations(event_id, status);
create index idx_event_regs_user on public.event_registrations(user_id);

create trigger trg_event_registrations_updated_at
  before update on public.event_registrations
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- REGISTER FOR AN EVENT (atomic, capacity-safe)
-- ------------------------------------------------------------
create or replace function public.register_for_event(
  p_event_id uuid,
  p_user_id uuid,
  p_quantity integer default 1
)
returns uuid
language plpgsql
as $$
declare
  v_capacity integer;
  v_ticket_price numeric(12,2);
  v_registration_id uuid;
  v_lock_key bigint;
begin
  -- Only published, not-yet-finished events can be registered for.
  select capacity, ticket_price into v_capacity, v_ticket_price
  from public.events
  where id = p_event_id and status = 'published' and ends_at > now();
  if not found then
    raise exception 'event not available' using errcode = 'P0001';
  end if;

  if p_quantity < 1 or p_quantity > 50 then
    raise exception 'invalid quantity' using errcode = '22023';
  end if;

  -- Serialize concurrent registrations for the same event.
  v_lock_key := hashtextextended('event:' || p_event_id::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- Capacity check counts live (non-cancelled) registrations.
  if (select coalesce(sum(quantity), 0)
      from public.event_registrations
      where event_id = p_event_id and status = 'registered')
     + p_quantity > v_capacity then
    raise exception 'event full' using errcode = 'P0001';
  end if;

  insert into public.event_registrations (
    event_id, user_id, quantity, total_amount, status
  ) values (
    p_event_id, p_user_id, p_quantity,
    round(coalesce(v_ticket_price, 0) * p_quantity, 2),
    'registered'
  )
  on conflict (event_id, user_id) do update
    set quantity = excluded.quantity,
        total_amount = excluded.total_amount,
        status = 'registered',
        updated_at = now()
  returning id into v_registration_id;

  return v_registration_id;
end $$;

-- ------------------------------------------------------------
-- CANCEL EVENT REGISTRATION (frees a seat)
-- ------------------------------------------------------------
create or replace function public.cancel_event_registration(
  p_registration_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
as $$
begin
  update public.event_registrations
  set status = 'cancelled', updated_at = now()
  where id = p_registration_id
    and user_id = p_user_id
    and status = 'registered';
  if not found then
    raise exception 'registration not cancellable' using errcode = 'P0001';
  end if;
end $$;

-- ------------------------------------------------------------
-- ENROLL IN A COURSE BATCH (atomic, capacity-safe)
-- ------------------------------------------------------------
create or replace function public.enroll_in_course(
  p_batch_id uuid,
  p_user_id uuid
)
returns uuid
language plpgsql
as $$
declare
  v_capacity integer;
  v_enrollment_id uuid;
  v_lock_key bigint;
begin
  -- Only active batches of published courses can be enrolled in.
  select b.capacity into v_capacity
  from public.course_batches b
  join public.courses c on c.id = b.course_id
  where b.id = p_batch_id and b.is_active and c.status = 'published';
  if not found then
    raise exception 'batch not available' using errcode = 'P0001';
  end if;

  v_lock_key := hashtextextended('batch:' || p_batch_id::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  if (select enrolled_count from public.course_batches where id = p_batch_id)
     >= v_capacity then
    raise exception 'batch full' using errcode = 'P0001';
  end if;

  insert into public.course_enrollments (batch_id, user_id, status)
  values (p_batch_id, p_user_id, 'enrolled')
  on conflict (batch_id, user_id) do nothing
  returning id into v_enrollment_id;

  -- Count seats even when the user was already enrolled (idempotent).
  update public.course_batches
  set enrolled_count = (
    select count(*) from public.course_enrollments
    where batch_id = p_batch_id and status = 'enrolled'
  )
  where id = p_batch_id;

  if v_enrollment_id is null then
    select id into v_enrollment_id
    from public.course_enrollments
    where batch_id = p_batch_id and user_id = p_user_id;
  end if;

  return v_enrollment_id;
end $$;

-- ------------------------------------------------------------
-- DROP COURSE ENROLLMENT (frees a seat)
-- ------------------------------------------------------------
create or replace function public.drop_course_enrollment(
  p_batch_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
as $$
begin
  update public.course_enrollments
  set status = 'dropped'
  where batch_id = p_batch_id and user_id = p_user_id and status = 'enrolled';
  if not found then
    raise exception 'enrollment not found' using errcode = 'P0001';
  end if;

  update public.course_batches
  set enrolled_count = (
    select count(*) from public.course_enrollments
    where batch_id = p_batch_id and status = 'enrolled'
  )
  where id = p_batch_id;
end $$;

-- ------------------------------------------------------------
-- RLS for event registrations (own rows only)
-- ------------------------------------------------------------
alter table public.event_registrations enable row level security;

create policy "event_registrations_own"
  on public.event_registrations
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "event_registrations_org_read"
  on public.event_registrations
  for select
  using (
    exists (
      select 1 from public.events e
      join public.organizations o on o.id = e.org_id
      where e.id = event_id and o.owner_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- DEMO CONTENT: events, institutes, courses, batches
-- ------------------------------------------------------------
do $$
declare
  v_org uuid;
  v_sunrise uuid;
  v_boardroom uuid;
  v_inst1 uuid;
  v_course1 uuid;
  v_course2 uuid;
  v_event1 uuid;
  v_event2 uuid;
begin
  select id into v_org from public.organizations where name = 'Demo Venues';
  if v_org is null then
    return;
  end if;

  select id into v_sunrise from public.venues where slug = 'sunrise-function-hall';
  select id into v_boardroom from public.venues where slug = 'the-boardroom';

  -- Events
  insert into public.events (
    org_id, venue_id, category, title, description, starts_at, ends_at,
    capacity, ticket_price, is_free, cover_image, status
  )
  select v_org, v_sunrise, 'cultural',
    'Hyderabad Music Night',
    'An evening of live classical and fusion music under the stars.',
    now() + interval '14 days', now() + interval '14 days' + interval '4 hours',
    200, 499, false,
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
    'published'
  where not exists (select 1 from public.events where title = 'Hyderabad Music Night');

  insert into public.events (
    org_id, venue_id, category, title, description, starts_at, ends_at,
    capacity, ticket_price, is_free, cover_image, status
  )
  select v_org, v_boardroom, 'workshop',
    'AI Product Strategy Workshop',
    'A hands-on workshop for founders on shipping AI features end to end.',
    now() + interval '21 days', now() + interval '21 days' + interval '6 hours',
    60, 0, true,
    'https://images.unsplash.com/photo-1531482615713-2afd69097998',
    'published'
  where not exists (select 1 from public.events where title = 'AI Product Strategy Workshop');

  -- Institute + courses
  insert into public.institutes (org_id, name, description, is_verified)
  select v_org, 'Nexus Learning Institute',
    'Focused, mentor-led courses in technology and design.', true
  where not exists (select 1 from public.institutes where name = 'Nexus Learning Institute');

  select id into v_inst1 from public.institutes where name = 'Nexus Learning Institute';

  insert into public.courses (
    institute_id, title, description, mode, venue_id, duration_weeks,
    fee_amount, instructor_name, cover_image, status
  )
  select v_inst1, 'Flutter App Development Bootcamp',
    'Build and ship production Flutter apps in 8 weeks with a mentor.',
    'offline', v_sunrise, 8, 29999, 'Anand Kumar',
    'https://images.unsplash.com/photo-1555066931-4365d14bab8c',
    'published'
  where v_inst1 is not null
    and not exists (select 1 from public.courses where title = 'Flutter App Development Bootcamp');

  select id into v_course1 from public.courses where title = 'Flutter App Development Bootcamp';

  insert into public.courses (
    institute_id, title, description, mode, duration_weeks,
    fee_amount, instructor_name, cover_image, status
  )
  select v_inst1, 'UI/UX Design Essentials',
    'Design thinking, wireframing and Figma for product designers.',
    'online', 4, 7999, 'Priya Sharma',
    'https://images.unsplash.com/photo-1561070791-2526d30994b5',
    'published'
  where v_inst1 is not null
    and not exists (select 1 from public.courses where title = 'UI/UX Design Essentials');

  select id into v_course2 from public.courses where title = 'UI/UX Design Essentials';

  -- Course batches (next few Mondays, ~1 week apart)
  insert into public.course_batches (course_id, label, starts_on, capacity)
  select v_course1, 'Weekday Batch A',
    (date_trunc('week', current_date) + interval '1 week' + interval '1 day')::date,
    25
  where v_course1 is not null
    and not exists (select 1 from public.course_batches where course_id = v_course1);

  insert into public.course_batches (course_id, label, starts_on, capacity)
  select v_course1, 'Weekend Batch B',
    (date_trunc('week', current_date) + interval '2 weeks' + interval '6 days')::date,
    20
  where v_course1 is not null
    and not exists (
      select 1 from public.course_batches where course_id = v_course1 and label = 'Weekend Batch B'
    );

  insert into public.course_batches (course_id, label, starts_on, capacity)
  select v_course2, 'Online Cohort 1',
    (date_trunc('week', current_date) + interval '1 week' + interval '3 days')::date,
    40
  where v_course2 is not null
    and not exists (
      select 1 from public.course_batches where course_id = v_course2
    );
end $$;
