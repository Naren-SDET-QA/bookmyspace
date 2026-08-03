-- ============================================================
-- BookMySpace — Migration 0013: Events & Courses Read Models
--
-- Client queries cannot aggregate registrations across users
-- (RLS only exposes your own rows), so expose security-definer
-- read functions that compute live `registered_count` and the
-- current user's registration/enrollment state in one call.
-- ============================================================

-- ------------------------------------------------------------
-- EVENTS LIST (published, upcoming, soonest first)
-- ------------------------------------------------------------
create or replace function public.event_summaries(p_user_id uuid default null)
returns table (
  id uuid,
  org_id uuid,
  venue_id uuid,
  category public.event_category,
  title text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  capacity integer,
  ticket_price numeric,
  is_free boolean,
  cover_image text,
  status text,
  venue_name text,
  registered_count bigint,
  user_registered boolean
)
language sql
security definer
stable
set search_path = public
as $$
  select
    e.id, e.org_id, e.venue_id, e.category, e.title, e.description,
    e.starts_at, e.ends_at, e.capacity, e.ticket_price, e.is_free,
    e.cover_image, e.status,
    v.name as venue_name,
    coalesce((
      select sum(r.quantity)
      from public.event_registrations r
      where r.event_id = e.id and r.status = 'registered'
    ), 0) as registered_count,
    case
      when p_user_id is null then false
      else exists (
        select 1 from public.event_registrations r
        where r.event_id = e.id and r.user_id = p_user_id
          and r.status = 'registered'
      )
    end as user_registered
  from public.events e
  left join public.venues v on v.id = e.venue_id
  where e.status = 'published' and e.ends_at > now()
  order by e.starts_at asc;
$$;

-- ------------------------------------------------------------
-- EVENT DETAIL (single published event + live counts)
-- ------------------------------------------------------------
create or replace function public.event_detail(
  p_event_id uuid,
  p_user_id uuid default null
)
returns table (
  id uuid,
  org_id uuid,
  venue_id uuid,
  category public.event_category,
  title text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  capacity integer,
  ticket_price numeric,
  is_free boolean,
  cover_image text,
  status text,
  venue_name text,
  registered_count bigint,
  user_registered boolean
)
language sql
security definer
stable
set search_path = public
as $$
  select
    e.id, e.org_id, e.venue_id, e.category, e.title, e.description,
    e.starts_at, e.ends_at, e.capacity, e.ticket_price, e.is_free,
    e.cover_image, e.status,
    v.name as venue_name,
    coalesce((
      select sum(r.quantity)
      from public.event_registrations r
      where r.event_id = e.id and r.status = 'registered'
    ), 0) as registered_count,
    case
      when p_user_id is null then false
      else exists (
        select 1 from public.event_registrations r
        where r.event_id = e.id and r.user_id = p_user_id
          and r.status = 'registered'
      )
    end as user_registered
  from public.events e
  left join public.venues v on v.id = e.venue_id
  where e.id = p_event_id and e.status = 'published';
$$;

-- ------------------------------------------------------------
-- MY COURSE ENROLLMENTS (batch ids I'm actively enrolled in)
-- ------------------------------------------------------------
create or replace function public.my_enrolled_batches(p_user_id uuid)
returns table (batch_id uuid)
language sql
security definer
stable
set search_path = public
as $$
  select e.batch_id
  from public.course_enrollments e
  where e.user_id = p_user_id and e.status = 'enrolled';
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant execute on function public.event_summaries(uuid) to anon;
    grant execute on function public.event_detail(uuid, uuid) to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.event_summaries(uuid) to authenticated;
    grant execute on function public.event_detail(uuid, uuid) to authenticated;
    grant execute on function public.my_enrolled_batches(uuid) to authenticated;
  end if;
end $$;
