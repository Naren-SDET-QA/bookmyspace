# BookMySpace — Roadmap

Implementation is split into small, verifiable milestones. Each milestone ends
with formatting, analysis, tests and a meaningful git commit.

| # | Milestone | Status |
| - | --------- | ------ |
| 1 | Foundation: themes, navigation, localization, environments, errors, widgets | ✅ Done |
| 2 | Supabase setup, migrations, auth, profiles, roles, RLS | ✅ Done |
| 3 | Home, search, maps, venue listings/details, images, favorites | ✅ Done |
| 4 | Availability calendar, slots, booking holds, atomic logic, concurrency tests | ✅ Done |
| 5 | Razorpay orders, verification, webhooks, reconciliation, refunds | ✅ Done |
| 6 | Events, institutes, courses, enrollment, tickets | ⏳ |
| 7 | Owner registration, venue management, requests, calendar, revenue, payouts | ⏳ |
| 8 | Notifications, analytics, crash reporting, support, audit, admin | ⏳ |
| 9 | Performance, accessibility, security, CI/CD, docs, store readiness | ⏳ |

## Milestone 1 — completed deliverable

- Flutter app scaffolded for Android / iOS / web.
- Material 3 themes (light + dark).
- GoRouter shell navigation (Home, Search, Bookings, Saved, Profile).
- English + Telugu localization with delegate + tests.
- Typed exception hierarchy + Dio client with error mapping.
- Reusable widgets: ErrorView, EmptyState, Skeleton, AppNetworkImage.
- Persistent preferences (theme, locale, onboarding) via FlutterSecureStorage.
- `flutter analyze` clean, all unit/widget tests pass, web release builds.

## Milestone 2 — completed deliverable

- Database schema `supabase/migrations/0001–0008` (users/roles/orgs, venues +
  PostGIS/FTS, availability + atomic booking holds + exclusion constraint,
  payments + webhook idempotency, RLS on every table, engagement/support/events,
  seed data, pg_cron scheduled jobs). All apply cleanly to Postgres 16.
- Concurrency tests (`supabase/tests/booking_concurrency.sql`) pass: sequential
  + concurrent double-booking rejection, hold idempotency, hold expiry.
- Edge Functions: `create-booking-hold`, `create-payment-order`,
  `razorpay-webhook` (HMAC + idempotent), `delete-account`.
- Auth layer: `AuthUser`/`AuthState`/`AuthRepository`, Supabase implementation
  (email + phone OTP, Google, Apple, sign-out, delete-account), Riverpod
  providers, `initSupabase()` in `main`.
- Auth gating in GoRouter: unauthenticated users are redirected to `/login`,
  signed-in users bypass onboarding/login. `AppRoutes.shell` now resolves to the
  home route.
- Functional login screen with OTP + social sign-in.
- Local dev stack: `supabase/config.toml` and `docker/docker-compose.local.yml`.
- `flutter analyze` clean; 24 unit/widget tests pass.

## Milestone 3 — completed deliverable

- Venue domain model (`Venue`, `VenueCategory`, `VenueImage`, facilities,
  operating hours, `VenueSearchQuery` + sort enums) with hand-written JSON
  mapping and `copyWith` hydration.
- `VenueRepository` + `SupabaseVenueRepository` (public reads via RLS,
  user-scoped favourites) using PostgREST `select`/`textSearch`/`filter` and
  the `nearby_venues` RPC.
- Migration `0009_nearby_venues_rpc.sql`: distance-sorted `nearby_venues(lat,
  lng, radius, limit)` RPC returning venue rows + category + gallery JSONB,
  security-invoker (RLS preserved). Verified against Postgres 16.
- Migration `0010_demo_content.sql`: gallery images (Unsplash), operating
  hours and a third demo venue (`The Work Nest`); test harness stub now seeds
  an `owner@demo.com` user so demo data is created locally.
- Riverpod venue providers: categories, popular, nearby, search query/results,
  favourites (ids, hydrated, toggle), venue details family.
- Home screen: category chips (from DB), popular + nearby venue grids with
  loading skeletons and retryable errors.
- Search screen: debounced full-text query, category chips, filter bottom sheet
  (sort, category, price range).
- Venue details: image gallery pager, rating/verified badges, about, pricing +
  capacity, amenities chips, operating hours, details rows, and an embedded
  OpenStreetMap (flutter_map) marker.
- Saved screen: hydrated favourite venues with empty state.
- Reusable widgets: `VenueCard`, `RatingBadge`, `VerifiedBadge`,
  `FavoriteButton`, INR currency + distance formatters.
- New dependencies: `geolocator`, `flutter_map`, `latlong2`.
- `flutter analyze` clean; 38 unit/widget tests pass; web release builds.

## Milestone 4 — completed deliverable

- Migration `0011_available_time_slots_rpc.sql`: security-definer
  `available_time_slots(venue_id, date)` RPC returning every active slot with
  `is_available` and a `reason` (`available` / `booked` / `held` / `blocked` /
  `closed` / `inactive`). Security definer lets it see other users' holds and
  bookings (which RLS hides) while exposing only aggregate availability.
  Verified on Postgres 16 (all reason paths) and against the full 0001–0011
  migration suite.
- Booking domain models: `TimeSlot`, `SlotAvailability`, `Booking`,
  `BookingStatus`, `BookingHold` (hand-written JSON mapping).
- `BookingRepository` + `SupabaseBookingRepository`: availability via RPC,
  atomic hold acquisition through the `create-booking-hold` Edge Function
  (server validates amount + advisory-locks the slot), pending-booking insert
  (RLS-safe), my-bookings list, and user cancellation (guarded to `pending`).
  Maps `slot_unavailable` / exclusion-violation to a typed
  `BookingConflictException`.
- Booking flow screen: 14-day date strip, slot list with availability reasons,
  disabled/taken slots, a confirmation dialog with base + GST + total, and a
  confirm action that acquires the hold then creates the pending booking.
- My Bookings screen (replaces the placeholder tab): booking cards with status
  badges, date/time chips, booking reference, amount, and cancel for pending
  bookings; pull-to-refresh, retryable error and empty states.
- Router wiring: `/venues/:id/book` booking flow (venue passed via `extra`,
  falls back to details on deep-link), `/bookings` tab now shows the real
  screen; venue details "Book now" button navigates instead of showing a
  SnackBar.
- Localization keys added in English + Telugu.
- `flutter analyze` clean; 49 unit/widget tests pass; web release builds;
  concurrency suite still 4/4 on a fresh database.

## Milestone 5 — completed deliverable

- `create-payment-order` and `razorpay-webhook` Edge Functions (order
  creation with server-side amount validation; HMAC-verified, idempotent
  webhook that confirms bookings on `payment.captured` and records failures)
  were already scaffolded in M2 — wired into the app in this milestone.
- New `create-refund` Edge Function: validates the booking belongs to the
  user and is `confirmed`, finds the captured payment, calls the Razorpay
  refunds API, writes a `refunds` row, and moves booking + payment to
  `refunded`. Guards against invalid amounts and duplicate refunds.
- Payment domain: `Payment`, `PaymentOrder`, `Refund`, `PaymentStatus`
  (hand-written JSON mapping), `PaymentRepository` interface, and a
  `CheckoutService` abstraction.
- `SupabasePaymentRepository`: order creation + refunds via Edge Functions,
  booking-status verification (webhook-driven confirmation), and the user's
  payments list. Maps `booking_not_found` / `not_refundable` /
  `already_refunded` etc. to typed exceptions.
- Checkout service abstraction with a real Razorpay implementation
  (`razorpay_flutter`, refuses placeholder keys with a
  `ConfigurationException`) and a fake for tests/web.
- Payment flow screen: booking summary, creates the order, opens checkout,
  then polls the booking status until the webhook confirms it (paid /
  pending / failed / cancelled states).
- Booking flow now navigates to payment after creating the pending booking.
- My Bookings: confirmed bookings offer a "Request refund" action with a
  confirmation dialog; refunds invalidate the list and show a snackbar.
- Router: `/bookings/:id/pay` payment flow (booking passed via `extra`,
  falls back to the bookings tab on deep link).
- New dependency: `razorpay_flutter`.
- Localization keys added in English + Telugu.
- New SQL test suite `supabase/tests/payments_refunds.sql` (confirmed-booking
  refund, pending-booking rejection, duplicate-refund guard) — 3/3 PASS on a
  fresh database; concurrency suite still 4/4; full 0001–0011 migration
  suite applies cleanly.
- `flutter analyze` clean; 62 unit/widget tests pass; web release builds.

## Design documents

- [Architecture](ARCHITECTURE.md)
- Database schema lives under `supabase/migrations/` (Milestone 2).
