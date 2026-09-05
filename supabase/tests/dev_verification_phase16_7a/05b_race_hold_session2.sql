-- Race A / session 2: customer a3 races for the same free slot as session 1.
select pg_sleep(1);
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
select public.acquire_booking_hold(
  '00000000-0000-0000-0000-0000000000c1'::uuid,
  '00000000-0000-0000-0000-0000000000d1'::uuid,
  '2026-10-05'::date,
  '00000000-0000-0000-0000-0000000000a3'::uuid,
  gen_random_uuid(),
  5000
) as session2_hold_result;
