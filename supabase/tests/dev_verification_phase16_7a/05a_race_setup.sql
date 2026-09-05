-- One-time setup for both concurrency races. Run once, before launching
-- the two race pairs (05b_* and 05c_*).
--
-- FIX (2026-08-28): this file only ever touched booking_holds/bookings —
-- it never created the base fixture rows (auth.users a1/a2/a3,
-- owner_profiles, organizations b1, venue_categories, venues c1,
-- time_slots d1) that Race A/B's inserts reference. It relied entirely on
-- 00_fixture_setup.sql having already been run in the same database. Run
-- standalone against a freshly-reset DB, the insert into public.bookings
-- below hit a foreign-key violation on user_id (a2 not in auth.users),
-- and because the caller invoked this with ON_ERROR_STOP=0, that failure
-- was swallowed — the race sessions then ran against a booking (f7) that
-- was never created, producing the "invalid slot/booking not found"
-- errors from both sides rather than a real race outcome.
--
-- Fix, scoped to this fixture/setup file only (no application code
-- touched): 06_run_concurrency_races.ps1 now runs 00_fixture_setup.sql
-- immediately before this file, both under ON_ERROR_STOP=1, so a missing
-- base fixture aborts the whole race suite instead of continuing into an
-- invalid race. The assertion block at the end of this file is a second,
-- independent check: it explicitly verifies every row Race A/B's session
-- scripts reference actually exists before printing "race setup
-- complete", and raises (aborting under ON_ERROR_STOP=1) if anything is
-- missing — so a silent gap here can never again reach the race scripts.
set client_min_messages to warning;

-- Race A target: a slot/date nobody has touched yet, so two customers can
-- genuinely race for it.
delete from public.booking_holds where venue_id = '00000000-0000-0000-0000-0000000000c1' and book_date = '2026-10-05';
delete from public.bookings where venue_id = '00000000-0000-0000-0000-0000000000c1' and book_date = '2026-10-05';

-- Race B target: a booking already sitting in pending_owner_approval,
-- so two "approve" requests can race for the same decision.
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000f7','BMS-RACEB','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-10-12','18:00','22:00','pending_owner_approval', 5000, 5000)
on conflict (id) do update set status = 'pending_owner_approval', confirmed_at = null, cancelled_at = null;
delete from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000f7';
delete from public.booking_approval_events where booking_id = '00000000-0000-0000-0000-0000000000f7';

-- Hard assertion: every row both race pairs reference must exist now, or
-- abort loudly rather than let an invalid race run silently.
do $$
declare v_missing text[] := array[]::text[];
begin
  if not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a1') then v_missing := v_missing || 'user a1 (owner)'; end if;
  if not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a2') then v_missing := v_missing || 'user a2 (customer1)'; end if;
  if not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a3') then v_missing := v_missing || 'user a3 (customer2)'; end if;
  if not exists (select 1 from public.venues where id = '00000000-0000-0000-0000-0000000000c1') then v_missing := v_missing || 'venue c1'; end if;
  if not exists (select 1 from public.time_slots where id = '00000000-0000-0000-0000-0000000000d1') then v_missing := v_missing || 'time_slot d1'; end if;
  if not exists (select 1 from public.bookings where id = '00000000-0000-0000-0000-0000000000f7' and status = 'pending_owner_approval') then v_missing := v_missing || 'booking f7 (pending_owner_approval)'; end if;
  if array_length(v_missing, 1) > 0 then
    raise exception 'race setup incomplete — missing: %. Run 00_fixture_setup.sql before this file.', array_to_string(v_missing, ', ');
  end if;
end $$;

select 'race setup complete — all referenced users, venue, slot, and booking confirmed present' as status;
