-- ============================================================
-- BookMySpace — Migration 0011: Slot availability RPC
--
-- Returns each active time slot of a venue for a given date with
-- an `is_available` flag and a `reason`:
--   * available / booked / held / blocked / closed / inactive
--
-- SECURITY: this is a `security definer` function so it can see
-- OTHER users' holds and bookings (RLS hides them from app users)
-- while still only returning aggregate availability — never other
-- users' personal data. Callers get no sensitive rows back.
-- ============================================================

create or replace function public.available_time_slots(
  p_venue_id uuid,
  p_book_date date
)
returns table (
  slot_id uuid,
  label text,
  start_time time,
  end_time time,
  price_amount numeric,
  is_available boolean,
  reason text
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select
    s.id,
    s.label,
    s.start_time,
    s.end_time,
    s.price_amount,
    (
      s.is_active
      and not exists (
        select 1 from public.venue_blocked_dates b
        where b.venue_id = s.venue_id and b.blocked_date = p_book_date
      )
      and exists (
        select 1 from public.venue_operating_hours oh
        where oh.venue_id = s.venue_id
          and oh.day_of_week = ((extract(dow from p_book_date)::int + 6) % 7)::smallint
          and not oh.is_closed
      )
      and not exists (
        select 1 from public.booking_holds h
        where h.venue_id = s.venue_id
          and h.book_date = p_book_date
          and h.status = 'active'
          and exists (
            select 1 from public.time_slots hs
            where hs.id = h.slot_id
              and hs.start_time < s.end_time
              and hs.end_time > s.start_time
          )
      )
      and not exists (
        select 1 from public.bookings b
        where b.venue_id = s.venue_id
          and b.book_date = p_book_date
          and b.status in ('held', 'pending', 'confirmed', 'completed')
          and b.start_time < s.end_time
          and b.end_time > s.start_time
      )
    ) as is_available,
    case
      when not s.is_active then 'inactive'
      when exists (
        select 1 from public.venue_blocked_dates b
        where b.venue_id = s.venue_id and b.blocked_date = p_book_date
      ) then 'blocked'
      when not exists (
        select 1 from public.venue_operating_hours oh
        where oh.venue_id = s.venue_id
          and oh.day_of_week = ((extract(dow from p_book_date)::int + 6) % 7)::smallint
          and not oh.is_closed
      ) then 'closed'
      when exists (
        select 1 from public.booking_holds h
        where h.venue_id = s.venue_id
          and h.book_date = p_book_date
          and h.status = 'active'
          and exists (
            select 1 from public.time_slots hs
            where hs.id = h.slot_id
              and hs.start_time < s.end_time
              and hs.end_time > s.start_time
          )
      ) then 'held'
      when exists (
        select 1 from public.bookings b
        where b.venue_id = s.venue_id
          and b.book_date = p_book_date
          and b.status in ('held', 'pending', 'confirmed', 'completed')
          and b.start_time < s.end_time
          and b.end_time > s.start_time
      ) then 'booked'
      else 'available'
    end as reason
  from public.time_slots s
  where s.venue_id = p_venue_id
  order by s.start_time;
$$;
