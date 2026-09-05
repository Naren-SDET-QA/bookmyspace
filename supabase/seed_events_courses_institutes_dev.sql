-- BookMySpace DEV-only events, institutes, and courses fixture seed.
--
-- Creates ten deterministic records for each of events, institutes, and
-- courses. Does not create Auth users, roles, or schema objects. Reuses an
-- existing owner organisation and an existing venue.
--
-- Run only against the DEV project ref zykxneztahxbjduagutv.
-- No DELETE/TRUNCATE/DROP. Re-running is safe.

begin;

do $$
declare
  v_org uuid;
  v_venue uuid;
  v_institute uuid;
  v_i integer;
  v_event uuid;
  v_course uuid;
  v_categories public.event_category[] := array[
    'meeting','conference','workshop','sports','entertainment',
    'cultural','exhibition','community','workshop','conference'
  ]::public.event_category[];
  v_modes public.course_mode[] := array[
    'offline','online','hybrid','offline','online',
    'hybrid','offline','online','hybrid','offline'
  ]::public.course_mode[];
begin
  if current_database() <> 'postgres' then
    raise exception 'REFUSED: expected Supabase postgres database';
  end if;
  if to_regclass('public.events') is null
     or to_regclass('public.institutes') is null
     or to_regclass('public.courses') is null
     or to_regclass('public.course_batches') is null then
    raise exception 'REFUSED: events/courses schema is incomplete';
  end if;

  select o.id into v_org
  from public.organizations o
  where o.is_active
  order by o.id
  limit 1;
  if v_org is null then
    raise exception 'REFUSED: an existing organisation is required';
  end if;

  select v.id into v_venue
  from public.venues v
  where v.org_id = v_org and v.is_active and v.deleted_at is null
  order by v.id
  limit 1;

  for v_i in 1..10 loop
    v_event := md5('bms-dev-generic:event:' || v_i::text)::uuid;
    insert into public.events (
      id, org_id, venue_id, category, title, description,
      starts_at, ends_at, capacity, ticket_price, is_free, cover_image, status
    ) values (
      v_event, v_org, v_venue, v_categories[v_i],
      'DEV Event ' || lpad(v_i::text, 2, '0'),
      'Deterministic BookMySpace DEV sample event.',
      now() + (v_i || ' days')::interval,
      now() + (v_i || ' days')::interval + interval '3 hours',
      40 + (v_i * 10),
      case when v_i % 3 = 0 then 0 else 199 + (v_i * 50) end,
      v_i % 3 = 0,
      'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&auto=format&fit=crop&q=80',
      'published'
    )
    on conflict (id) do update set
      title = excluded.title,
      description = excluded.description,
      starts_at = excluded.starts_at,
      ends_at = excluded.ends_at,
      capacity = excluded.capacity,
      ticket_price = excluded.ticket_price,
      is_free = excluded.is_free,
      status = 'published';
  end loop;

  for v_i in 1..10 loop
    v_institute := md5('bms-dev-generic:institute:' || v_i::text)::uuid;
    insert into public.institutes (
      id, org_id, name, description, is_verified
    ) values (
      v_institute, v_org,
      'DEV Institute ' || lpad(v_i::text, 2, '0'),
      'Deterministic BookMySpace DEV sample institute.',
      true
    )
    on conflict (id) do update set
      name = excluded.name,
      description = excluded.description,
      is_verified = true;
  end loop;

  for v_i in 1..10 loop
    v_institute := md5('bms-dev-generic:institute:' || v_i::text)::uuid;
    v_course := md5('bms-dev-generic:course:' || v_i::text)::uuid;
    insert into public.courses (
      id, institute_id, title, description, mode, venue_id,
      duration_weeks, fee_amount, instructor_name, cover_image, status
    ) values (
      v_course, v_institute,
      'DEV Course ' || lpad(v_i::text, 2, '0'),
      'Deterministic BookMySpace DEV sample course.',
      v_modes[v_i],
      v_venue,
      4 + v_i,
      1999 + (v_i * 500),
      'DEV Instructor ' || v_i,
      'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=1200&auto=format&fit=crop&q=80',
      'published'
    )
    on conflict (id) do update set
      title = excluded.title,
      description = excluded.description,
      mode = excluded.mode,
      duration_weeks = excluded.duration_weeks,
      fee_amount = excluded.fee_amount,
      status = 'published';

    insert into public.course_batches (
      id, course_id, label, starts_on, capacity, is_active
    ) values (
      md5('bms-dev-generic:course-batch:' || v_i::text)::uuid,
      v_course,
      'DEV Batch A',
      (current_date + (v_i || ' weeks')::interval)::date,
      20 + v_i,
      true
    )
    on conflict (id) do update set
      label = excluded.label,
      starts_on = excluded.starts_on,
      capacity = excluded.capacity,
      is_active = true;
  end loop;
end $$;

commit;
