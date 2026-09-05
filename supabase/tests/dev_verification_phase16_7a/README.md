# Phase 16.7A verification — run against your local Docker/Postgres

These three files replace the disposable cloud-sandbox test DB used earlier
in this session. Run them against your own local Supabase stack (Docker),
which already gives you the real `auth` schema, real roles
(`authenticated`/`anon`/`service_role`), and real PostGIS — none of the
sandbox's shims are needed here.

This does **not** touch STAGING or PROD. `supabase start` / `supabase db
reset` only ever operate on the local Docker Postgres container defined in
`supabase/config.toml` (local DB port 54322).

## 1. Start the local stack and apply all 91 migrations

From the repo root, in PowerShell (Docker Desktop must be running):

```powershell
supabase start
supabase db reset
```

`supabase db reset` recreates the local DB from scratch and applies every
file in `supabase/migrations/` **in filename order**, including the newest
one, `20260827190000_fix_owner_lookup_rls_recursion_dev.sql`. If this
command errors, note the migration filename it stopped on — that is the
first real blocker to report back.

## 2. Run the fixture, then the two test files, in this exact order

```powershell
$env:PGPASSWORD = "postgres"
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/00_fixture_setup.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/01_functional_tests.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/02_functional_tests_more.sql
```

(If `psql` isn't on PATH, it ships inside Docker Desktop's Supabase
containers too — `docker exec -it supabase_db_bookmyspace-grok psql -U postgres`
works as a drop-in for the `psql -h ... -p 54322 ...` prefix above, then
`\i <path>` each file from inside that shell.)

## 3. What to look for

Every test prints its own PASS/FAIL via `NOTICE` (or, for TESTS 3/5/11,
via a `select` whose row makes the expected result obvious — e.g. TEST 11's
three counts should read `1`, `0`, `1` in that order). A clean run has
**zero** lines starting with `FAILED` or `UNEXPECTED ERROR`, and `psql`
should exit 0 on all three files given `-v ON_ERROR_STOP=1`.

Covers: payment → pending_owner_approval (TEST 1/2, plus the schema/
constraint work already in the migration), approve → confirmed +
booking_orders (TEST 3), re-approve blocked (TEST 4), reject → refund-
eligible state (TEST 5), slot freed after reject (TEST 6), reject
idempotency at the RPC layer and the DB unique-constraint layer (TEST 7/8),
invalid transitions off a `cancelled` booking (TEST 9a/9b), RLS blocking a
non-owner from deciding someone else's booking (TEST 10), and RLS read
visibility for `booking_orders` as the real `authenticated` role — owner
and the booking's own customer see it, an unrelated customer does not
(TEST 11).

## 4. Optional — re-run the pre-existing suite too

```powershell
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f supabase/tests/regression_42803.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f supabase/tests/booking_concurrency.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f supabase/tests/payments_refunds.sql
```

`regression_42803.sql` is expected to pass cleanly. `booking_concurrency.sql`
and `payments_refunds.sql` predate the `20260824132847_secure_booking_rpc_
authorization.sql` auth-hardening migration and never set
`request.jwt.claim.sub` before calling `acquire_booking_hold` — they were
already broken before this phase's changes and are flagged as a known,
out-of-scope blocker rather than something this phase touched or fixed.

## 5. Clean up (optional)

```powershell
supabase stop
```

## 6. Flutter analyze + focused Flutter tests (also local-only)

Neither the cloud sandbox nor this session's device bridge has the Flutter
SDK, so this also needs to run on your machine, from the repo root:

```powershell
flutter analyze
flutter test test/features/venue_discovery/venue_discovery_test.dart
flutter test test/features/owner_bookings
flutter test test/features/booking
flutter test test/features/owner_venues/owner_listing_test.dart
```

Those four target the files this phase actually touched (venue discovery
staging UI, owner booking approve/reject flows, the booking screens that
lead into `pending_owner_approval`, and admin/owner listing screens) rather
than the full test suite. Run `flutter test` with no path if you want the
whole suite instead.

## 7. Update — TEST 11 grant fix (2026-08-28)

TESTS 1–10 passed on your local run. TEST 11 failed with `permission
denied for table booking_orders`: the `authenticated` role had the
correct RLS policies but no base `GRANT SELECT` on `booking_orders` /
`booking_approval_events` — RLS alone doesn't grant table access, so
every direct SELECT was rejected before RLS was even evaluated. Every
earlier test reached these tables only through the SECURITY DEFINER
`owner_decide_booking()` function, which bypasses grants, so this never
surfaced until TEST 11's direct SELECT.

Fix (additive, DEV-only, SELECT-only — no RLS policy changed, no
booking logic touched):
`supabase/migrations/20260828090000_grant_booking_approval_tables_select_dev.sql`

Apply it and re-run TEST 11:

```powershell
$env:PGPASSWORD = "postgres"
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/migrations/20260828090000_grant_booking_approval_tables_select_dev.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/02_functional_tests_more.sql
```

(Or `supabase db reset` to reapply the full chain from scratch, then
re-run all three test files per section 2, if you'd rather verify it
end-to-end rather than as a targeted patch.)

TEST 11 should now print three counts — `1`, `0`, `1` — with no
`permission denied` error.

## 8. Backend gaps pass (2026-08-28) — refund, concurrency, payment amount, webhook

Five things were asked to be verified. Here's what each needed and what
was added. Run `supabase db reset` first so the two new migrations below
are applied, then run the fixture + 01 + 02 again (section 2) before these.

**1–2. Rejection refund execution/persistence + idempotency on retry.**
Traced `owner-booking-manage/index.ts`'s `refundRejectedBooking()` in
full. Found one real gap: `refunds.payment_id` had an index but no
`UNIQUE` constraint, so its own `existingRefund` check (select, then
insert) was a check-then-act race with no database backstop — every
other idempotency guard in this codebase (`webhook_events`,
`booking_approval_events`, `payments`) is backed by a real constraint;
this one wasn't. In the current call graph the window is narrow —
`owner_decide_booking()`'s row lock + status check already stop a
concurrent second reject from ever reaching refund logic (TEST 7) — but
the fix closes it properly rather than relying on that alone:
`supabase/migrations/20260828110000_refunds_payment_id_unique_dev.sql`
adds `unique (payment_id)`. New test:
`supabase/tests/dev_verification_phase16_7a/03_refund_persistence_and_idempotency.sql`
exercises the exact insert/update sequence `refundRejectedBooking()`
performs (refund row → processed + provider_refund_id → payments.status
→ booking_approval_events.refund_id link) and then proves a second
refund insert for the same payment now hits `unique_violation`.

What this does **not** cover: the actual HTTP call to Razorpay
(`createRazorpayRefund`) can't be exercised without either live
Razorpay credentials (excluded — no real payment) or refactoring that
function out of the `Deno.serve()` module into an importable/mockable
form the way `create-payment-order/payment_order_policy.ts` already is
— which would be an application code restructure, out of scope for a
verify-only pass. Flagging this as a known, intentionally-unexecuted
edge rather than silently skipping it.

**3. Real concurrent approval/double-booking race.** TESTS 1–2 earlier
were sequential (one `DO` block after another), which proves the logic
but not real concurrency. New: two race pairs, actually run as two
simultaneous `psql` processes —
`supabase/tests/dev_verification_phase16_7a/06_run_concurrency_races.ps1`
runs both. Race A: two different customers call `acquire_booking_hold`
for the identical free slot/date at (as close to) the same instant.
Race B: two concurrent `owner_decide_booking('approve')` calls on the
same `pending_owner_approval` booking, simulating a retried/double-tap
owner action. `05d_race_check.sql` asserts the outcome: exactly one
active hold survives Race A, and exactly one `booking_orders` row /
`approved` event survives Race B — proving the `pg_advisory_xact_lock`
(hold path) and `select ... for update` + status check (approve path)
actually serialize concurrent writers, not just sequential ones.

Run it:
```powershell
.\supabase\tests\dev_verification_phase16_7a\06_run_concurrency_races.ps1
```

**4. Payment amount/token configuration verification.** Two findings:
- `create-payment-order/index.ts` always charges `booking.total_amount`
  read fresh from the DB (`amountDecision()` in the already-existing
  `payment_order_policy.ts`, with its own `payment_order_policy_test.ts`)
  — a client-supplied amount is only ever used as a mismatch check, never
  trusted. This is already covered by an existing test; run it with
  Deno if installed: `deno test supabase/functions/create-payment-order/`.
- `venues.booking_token_amount` and `booking_token_refund_policy`
  (added by `20260827122210_booking_owner_approval_token_flow.sql`) are
  **not read anywhere** in the payment or refund code — grepped the
  whole `supabase/` and `lib/` trees, zero hits outside their own
  column definition. The actual behavior is: the customer is always
  charged the full slot price up front, held pending owner approval, and
  fully refunded on reject — a simpler, already-consistent design, just
  not what those two column names suggest. Not treated as a bug and not
  changed (would be a business-logic decision, out of scope for
  verify-only) — flagging so it isn't mistaken for wired-up
  partial-token behavior it doesn't currently have.

**5. Payment webhook: captured → pending_owner_approval, never
confirmed.** Read `razorpay-webhook/index.ts` in full — the only booking
status write in the `payment.captured` branch is
`update bookings set status='pending_owner_approval' where id=... and
status='pending'` (the fix from section 7's earlier phase); there is no
`status: 'confirmed'` write anywhere in the file. New test:
`supabase/tests/dev_verification_phase16_7a/04_webhook_status_never_confirmed.sql`
runs that exact statement against a fresh `pending` booking, confirms it
transitions once, confirms a simulated redelivery is a 0-row no-op (not
a second transition or an error), and confirms the booking only ever
reaches `confirmed` through the owner's explicit approve call.

Run everything for this section:
```powershell
$env:PGPASSWORD = "postgres"
supabase db reset
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/00_fixture_setup.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/01_functional_tests.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/02_functional_tests_more.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/03_refund_persistence_and_idempotency.sql
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/04_webhook_status_never_confirmed.sql
.\supabase\tests\dev_verification_phase16_7a\06_run_concurrency_races.ps1
```

Look for `NOTICE: TEST R1/R2/R3/R4 PASSED`, `NOTICE: TEST W1/W2/W3
PASSED`, and `NOTICE: TEST C1/C2 PASSED` with no `FAILED` lines.

## 9. Fix — race suite ran against an incomplete fixture (2026-08-28)

`05a_race_setup.sql` only ever touched `booking_holds`/`bookings` — it
never created the base fixture rows (`auth.users` a1/a2/a3, venue c1,
time_slot d1) that both races reference, and always assumed
`00_fixture_setup.sql` had already been run in the same database. Run
against a freshly-reset local DB, that assumption didn't hold: the
insert into `bookings` failed on a foreign-key violation (user a2 not in
`auth.users`), and because the setup step was invoked with
`ON_ERROR_STOP=0`, the failure was silently swallowed — the race
sessions then ran against a booking that was never created, producing
"invalid slot"/"booking not found" from both sides instead of a real
race result.

Fixed, fixture/setup only, no application code touched:
- `06_run_concurrency_races.ps1` now runs `00_fixture_setup.sql`
  immediately before `05a_race_setup.sql`, every setup step under
  `-v ON_ERROR_STOP=1`, with the script explicitly checking psql's exit
  code after each and aborting with a clear message if either fails —
  it will no longer continue into an invalid race.
- `05a_race_setup.sql` ends with an assertion block that explicitly
  checks users a1/a2/a3, venue c1, time_slot d1, and booking f7 all
  exist, and `raise exception`s (naming exactly what's missing) if not.

Rerun on a clean local DB:
```powershell
$env:PGPASSWORD = "postgres"
supabase db reset
.\supabase\tests\dev_verification_phase16_7a\06_run_concurrency_races.ps1
```
No manual fixture step needed first — the script now does it. Expect:
`race setup complete — all referenced users, venue, slot, and booking
confirmed present`, then both races, then `TEST C1 PASSED` (exactly 1
surviving hold) and `TEST C2 PASSED` (exactly 1 `booking_orders` row,
status confirmed, 1 approved event).

## 10. Phase 16.8 -- token payment audit + fix (2026-08-28)

Audit requested before E2E: is a venue's booking token actually
configured, does payment charge only that token, is there any hardcoded
amount, is the amount persisted/verified, can payment exceed the token,
and does existing Razorpay verification/idempotency still hold.

**Finding: incomplete, as suspected in section 8 item 4.**
`venues.booking_token_amount` (added by `20260827122210_booking_owner_
approval_token_flow.sql`) was never read by any function -- grepped the
whole `supabase/` and `lib/` trees, zero hits outside the column's own
definition. `create-payment-order/index.ts` always charged
`booking.total_amount` (the full slot price), regardless of any token
configuration. There is also currently no owner-facing UI or RPC to set
`booking_token_amount` at all -- it can only be set directly in the
database. That absence is a real product gap, but building UI for it is
out of scope here ("do not redesign UI") -- flagging it plainly rather
than silently building around it.

**Fix, scoped to the one place the online charge amount is decided:**
- `supabase/functions/create-payment-order/payment_order_policy.ts`:
  added `resolveChargeAmount(totalAmount, tokenAmount)` -- a pure
  function (same established pattern as `amountDecision`/
  `bookingDecision`, with its own `Deno.test` coverage). Returns the
  configured token when one is set, clamped to never exceed the full
  price; the full price otherwise. No hardcoded amount anywhere --
  every number comes from the DB (`bookings.total_amount`,
  `venues.booking_token_amount`).
- `supabase/functions/create-payment-order/index.ts`: now selects
  `venues(...booking_token_amount)` alongside the existing booking
  lookup, computes `chargeAmount = resolveChargeAmount(...)` once, and
  uses it everywhere the old code used `booking.total_amount`: the
  client-amount mismatch check, the `payments` row's `amount`, the
  actual Razorpay order amount, and the JSON response. A venue with no
  token configured (every venue today, since there's no config surface
  yet) is charged in full -- byte-for-byte the same behavior as before
  this fix, so nothing that already passed regresses.
- Nothing else touched: `create-booking-hold` (hold validation, a
  separate concern from the actual charge), `owner_decide_booking`,
  `booking_orders`, refund logic, and the webhook's amount-match check
  are all unchanged. The refund path already refunds
  `Number(payment.amount)` (what was actually captured) rather than
  `total_amount` -- so once the charge is correctly scoped to the
  token, refunds are automatically correct too, with zero refund-code
  changes (verified in TEST T6 below).

**Verified for real, not just by inspection:** installed Deno in the
sandbox this was built in and ran the actual test suite against the
real edited files (not a re-typed copy) --
`deno test payment_order_policy_test.ts`: **7 passed, 0 failed**
(all 6 pre-existing tests plus the new `resolveChargeAmount` test, so
nothing regressed). `deno lint index.ts` also came back clean.
`deno check` (full type-check against `npm:@supabase/supabase-js`)
couldn't run -- `registry.npmjs.org` isn't on this sandbox's egress
allowlist -- so that one specific check is unexecuted; deno lint +
the manual read confirm the syntax and edit points are correct.

New SQL test:
`supabase/tests/dev_verification_phase16_7a/07_token_payment_configuration.sql`
-- T1 documents the "unconfigured by default" audit finding, T2 mirrors
`resolveChargeAmount`'s three branches in SQL, T3/T4 prove the webhook's
amount-match check correctly accepts a legitimate token capture and
rejects a mismatched/overcharged one, T5 is the unconfigured-venue
regression check, T6 proves reject-refund automatically refunds only
the token.

Run it (after `supabase db reset` + `00_fixture_setup.sql`, same as
section 8):
```powershell
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/dev_verification_phase16_7a/07_token_payment_configuration.sql
```
Also, if Deno is installed locally:
```powershell
deno test supabase/functions/create-payment-order/
```
Look for `NOTICE: TEST T1 CONFIRMED`, `T2a/T2b/T2c PASSED`, `T3/T4/T5/T6
PASSED`, and (from Deno) `7 passed | 0 failed`.

**Not covered, and can't be from here:** the actual Razorpay HTTP call
in `create-payment-order` (real network + real credentials, excluded by
"no real payment"), and a live `supabase functions serve` invocation of
the Edge Function end-to-end. The SQL test above exercises the same
amount-resolution and persistence logic the Edge Function runs, and the
Deno test exercises the exact pure function the Edge Function calls --
between the two, the decision logic and its DB-layer consequences are
verified; only the outbound Razorpay HTTP call itself is not.


## 11. Phase 16.9 -- real local E2E booking flow (REST/RPC-driven)

**Scope note up front:** there is no Appium configuration and no Flutter
`integration_test` suite anywhere in this repository (`pubspec.yaml`'s
`dev_dependencies` only lists `flutter_test`), and neither environment
available to build this script can run Android/Appium/Flutter/Docker.
`scripts/phase16_9_booking_e2e_local.ps1` therefore does not drive the
Flutter UI, gestures, navigation, or the Android app's real Razorpay
Checkout SDK screen. It drives the exact backend chain the app calls --
same Supabase Auth signups, same `create-booking-hold` /
`create-payment-order` / `razorpay-webhook` / `owner-booking-manage`
Edge Functions, same RPCs, same RLS -- following the established
REST/HttpWebRequest pattern already used by
`scripts/phase71c4d_authenticated_local_e2e.ps1` in this repo, rather
than inventing a parallel harness or faking persistence for the flow
under test.

### Real defect found and fixed during this audit

Tracing the actual call sequence customer -> hold -> booking -> payment
found a real, verified break in the booking-to-payment handoff:
`SupabaseBookingRepository.createBooking()` (the Flutter client) was
inserting the new `bookings` row directly at
`status: 'pending_owner_approval'`. But:

- `create-payment-order`'s `bookingDecision()` only authorizes a charge
  when `booking.status === 'pending'` -- any other status returns
  `403 not_authorized`.
- The Razorpay webhook's own state transition
  (`.eq('status', 'pending')` -> `pending_owner_approval`) only fires
  from `'pending'`.

Net effect: every real booking would have hit `403 not_authorized` the
moment the customer tried to pay -- the booking-to-payment flow was
completely broken, not merely a gap. Fixed with a one-line change (plus
an explanatory comment) in
`lib/features/booking/infrastructure/supabase_booking_repository.dart`:
the client now inserts the booking at `status: 'pending'`, matching
what `create-payment-order` and the webhook were already built to
expect. `BookingStatus.pending` already has full first-class support
everywhere else in the app (badge label, cancel eligibility, invoice
text), so nothing else needed to change. No RLS, no RPC, no booking
logic was touched -- this is strictly the one insert statement.

### Prerequisite: Razorpay TEST-mode credentials

`create-payment-order` calls the real Razorpay TEST-mode Orders API
(`api.razorpay.com/v1/orders`) using `RAZORPAY_KEY_ID` /
`RAZORPAY_KEY_SECRET` from the local Edge Function environment. The
`.env.dev.example` placeholders (`rzp_test_dev_key_id` /
`rzp_test_dev_secret`) are not real credentials, so with them unchanged
Razorpay will reject the order request and the script will report
`PAYMENT_ORDER_CREATED_CHARGES_CONFIGURED_TOKEN: FAIL
(razorpay_test_credentials_not_configured)` and mark every downstream
step (webhook, owner approve, confirmed persistence) `BLOCKED` rather
than fail silently -- the reject-path checks (owner reject / cannot
re-decide / slot freed) still run because they only require a
`pending` booking, no payment. To exercise the full happy path: sign up
for a free Razorpay TEST-mode account, copy its Key Id / Key Secret and
Webhook Secret into your local `.env.dev`, then restart
`supabase functions serve` (or `supabase start`) so the Edge Function
picks them up. Razorpay test mode never moves real money -- this stays
inside "no real payment."

### What it covers

Happy path: customer signup/login, real venue discovery (RLS +
`available_time_slots`), slot hold (+ idempotent retry), booking
creation at `pending`, payment-order creation (also regression-checks
Phase 16.8 -- the charge must equal the venue's configured token, not
the full price), payment-order retry idempotency, a correctly
HMAC-signed simulated `payment.captured` webhook delivery (not a real
payment -- the standard way to test a webhook receiver without driving
Checkout.js), webhook redelivery no-op, owner viewing the pending
booking, owner approve -> confirmed with `booking_orders` created
exactly once, re-approve blocked, and the customer re-fetching the
booking in a later call to prove the confirmed state persisted (not
just returned by the mutating call).

Negative paths: unavailable slot for a second customer, duplicate
booking blocked by the exclusion constraint, cross-user authorization
blocked on both payment-order creation and owner approval, owner
reject, a rejected booking cannot be re-decided (invalid transition),
and the slot is freed again after rejection.

### Run it

```powershell
$env:PHASE169_SUPABASE_URL = 'http://127.0.0.1:54321'
$env:PHASE169_SUPABASE_ANON_KEY = '<local anon key from `supabase status`>'
$env:PHASE169_SUPABASE_SERVICE_ROLE_KEY = '<local service_role key from `supabase status`>'
# Optional -- only needed if your local .env.dev overrides the RAZORPAY_WEBHOOK_SECRET example value:
# $env:PHASE169_RAZORPAY_WEBHOOK_SECRET = '<your local webhook secret>'
.\scripts\phase16_9_booking_e2e_local.ps1
```

Validated for real before handoff: parsed with the actual
`[System.Management.Automation.Language.Parser]::ParseFile()` AST
parser and `[scriptblock]::Create()` (both clean, `NO SYNTAX ERRORS` /
`OK`), and confirmed pure-ASCII byte-for-byte against the validated
copy (same fix class as the section 9 `06_run_concurrency_races.ps1`
ParserError). The HTTP flow itself (signups, RLS reads, Edge Function
calls, webhook HMAC delivery, owner decisions) has not been executed
from here -- this environment has no `flutter`/`docker`/`supabase` CLI
and was explicitly told to stop using the disposable cloud Postgres;
please run it against your local Docker Supabase and report the exact
PASS/FAIL/BLOCKED summary it prints.
