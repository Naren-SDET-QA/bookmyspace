-- Race B / session 1: two concurrent "approve" requests for the SAME
-- pending_owner_approval booking (simulating a retried/double-fired
-- owner-app tap). Exactly one must win.
select pg_sleep(1);
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select public.owner_decide_booking('00000000-0000-0000-0000-0000000000f7'::uuid, 'approve') as session1_decide_result;
