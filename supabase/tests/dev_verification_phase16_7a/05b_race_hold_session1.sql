-- Race A / session 1: customer a2 races for the same free slot as session 2.
select pg_sleep(1);
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
select public.acquire_booking_hold(
  '00000000-0000-0000-0000-0000000000c1'::uuid,
  '00000000-0000-0000-0000-0000000000d1'::uuid,
  '2026-10-05'::date,
  '00000000-0000-0000-0000-0000000000a2'::uuid,
  gen_random_uuid(),
  5000
) as session1_hold_result;
