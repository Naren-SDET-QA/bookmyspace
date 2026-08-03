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
| 6 | Events, institutes, courses, enrollment, tickets | ✅ Done |
| 7 | Owner registration, venue management, requests, calendar, revenue, payouts | ✅ Done |
| 8 | Notifications, analytics, crash reporting, support, audit, admin | ✅ Done |
| 9 | Performance, accessibility, security, CI/CD, docs, store readiness | ✅ Done |
| 10 | Owner venue management, reviews/ratings, venue CRUD | ✅ Done |
| 11 | Firebase Crashlytics, Performance, app icons, splash screen | ⏳ |

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

## Milestone 6 — completed deliverable

- Migration `0012_events_enrollment.sql`: `event_registrations` table (unique
  `(event_id, user_id)`, `registered`/`cancelled`/`checked_in`) + RLS, and
  atomic, capacity-safe functions using the same advisory-lock pattern as
  booking holds: `register_for_event` (publishes nothing but validates
  published + future events and counts live registrations), 
  `cancel_event_registration`, `enroll_in_course` (idempotent, recounts
  `course_batches.enrolled_count`), and `drop_course_enrollment`. Seeds demo
  events (Hyderabad Music Night, AI Product Strategy Workshop), an institute
  (Nexus Learning), two courses and three batches.
- Migration `0013_events_courses_read.sql`: security-definer read models so
  client queries can see live capacity and their own state — `event_summaries`,
  `event_detail` (with `registered_count` + `user_registered`) and
  `my_enrolled_batches`.
- New SQL suite `supabase/tests/events_courses.sql` — 6/6 PASS on a fresh
  database: event registration, event capacity enforcement, cancel frees a
  seat, course batch capacity + `enrolled_count` tracking, drop frees a seat,
  and read-model counts/state. Concurrency 4/4 and payments/refunds 3/3 still
  pass; full 0001–0013 migration suite applies cleanly.
- Events domain (`Event`, `EventCategory`, `EventRegistration`) + courses
  domain (`Institute`, `Course`, `CourseBatch`, `CourseMode`) with hand-written
  JSON mapping; `EventRepository` + `CourseRepository` contracts.
- `SupabaseEventRepository` (read models + RPC registration/cancel) and
  `SupabaseCourseRepository` (course/batch reads with merged-in
  `my_enrolled_batches` for accurate `userEnrolled`); typed errors for
  sold-out/unavailable cases.
- Events screens: list (upcoming, view-all), detail with live seats, date/time
  and venue, plus a register/cancel bottom bar (registration via RPC,
  confirmation dialog for cancel).
- Courses screens: list (published, view-all), detail with mode/duration/
  instructor/fee and per-batch enroll/drop buttons with seat counts and
  full-batch disabled states.
- Home screen: dynamic "Upcoming events" and "Courses" horizontal sections
  (shown only when data exists) with view-all navigation.
- Router: `/events`, `/events/:id`, `/courses`, `/courses/:id`.
- Localization keys added in English + Telugu.
- Tests: domain + widget tests for events and courses (22 new tests);
  `flutter analyze` clean; 85 unit/widget tests pass; web release builds.

## Milestone 7 — completed deliverable

- Migration `0014_owner_registration.sql`: `owner_profiles` table
  (unique `user_id`, role `owner`), helper functions `get_owner_user_id()`,
  `register_owner()`, `delete_owner_account()`, and RLS policies. Seeds a
  demo owner (Naren, naren@test.com).
- New domain model `Owner` with hand-written JSON mapping;
  `OwnerRepository` contract and `SupabaseOwnerRepository` implementation.
- `OwnerRegistrationScreen` with email/name/password form, loading/error
  states, and `createOwnerProvider` family for async registration.
- `OwnerDashboardScreen` with navigation to notifications, analytics,
  support, and admin audit screens; displays owner profile card.
- Router: `/owner/register`, `/owner`.
- App shell bottom navigation updated to include owner dashboard entry.
- `flutter analyze` clean; owner test passes; all 86 tests pass.

## Milestone 8 — completed deliverable

- Migration `0015_notifications_analytics_support_audit.sql`: tables for
  `notifications`, `analytics_events`, `crash_reports`, `support_tickets`
  (with `ticket_status`/`ticket_priority` enums), and `audit_logs`; RLS
  policies, `admin` role, `mark_ticket_resolved()` function, and demo data.
- Notifications screen with list, unread count badge, mark-read on tap,
  skeleton loading, and `markNotificationReadProvider`/`markAllNotificationsReadProvider`.
- Analytics screen with event list, skeleton loading, and `recentAnalyticsEventsProvider`.
- Support tickets screen with create-ticket dialog (subject, description,
  category, priority), ticket list with status badges, and
  `createTicketProvider`/`updateTicketProvider` family providers.
- Admin audit log screen with `recentAuditLogsProvider` and `AuditLogEntry` model.
- Owner dashboard with quick-action buttons for all M8 features.
- Localization keys added in English + Telugu for all M8 features.
- Router: `/notifications`, `/analytics`, `/support`, `/admin/audit`.
- `flutter analyze` clean; all 86 tests pass.

## Milestone 9 — completed deliverable

- GitHub Actions CI workflow (`.github/workflows/ci.yml`): analyze, test
  with coverage, build Android APK + web, and SQL migration tests against
  Postgres 16. Concurrency-safe with auto-cancel on push.
- Input validation utility (`lib/core/validators/app_validators.dart`):
  centralized validators for email, phone, name, OTP, password, required
  fields, descriptions, and subjects with consistent error messages.
- Accessibility widgets (`lib/core/widgets/accessibility.dart`):
  `MinTouchTarget` (enforces WCAG 44x44 minimum), `AccessibleInkWell`
  (touch-target + semantics), and `AccessibleIconButton` (tooltip + min size).
- Retry and rate-limiting utilities (`lib/core/network/retry.dart`):
  exponential-backoff `withRetry` wrapper and `RateLimiter` with configurable
  window and request limits.
- Legal screens: `PrivacyPolicyScreen` and `TermsOfServiceScreen` with
  structured policy content and English localization.
- Settings screen wired to legal pages (`/privacy`, `/terms`).
- 28 new tests (validators, retry, accessibility, rate limiter);
  `flutter analyze` clean; 114 total tests pass.

## Milestone 10 — completed deliverable

- Migration `0016_reviews_venue_management.sql`: `reviews` table with
  rating, title, body, verification flag; unique per user/venue; RLS for
  author-only write. Trigger to auto-update venue `avg_rating` and
  `rating_count`. Helper RPCs: `get_owner_venues`, `create_owner_venue`,
  `update_owner_venue`, `delete_owner_venue`. Seeds 3 demo reviews.
- Owner venue management: `OwnerVenuesScreen` (list with status badges,
  ratings, prices), `CreateVenueScreen` (form with category dropdown, city/
  state, capacity, pricing). RPC-backed Supabase implementation with
  ownership checks.
- Reviews system: `VenueReviewsSection` widget showing review list with
  star ratings, verified badges, and date. Dialog to submit new review
  with 5-star rating picker. `ReviewRepository` + `SupabaseReviewRepository`.
- New routes: `/owner/venues`, `/owner/venues/create`. Owner dashboard
  quick action for venue management.
- Localization keys added in English + Telugu for owner venues, create
  venue, and reviews.
- `flutter analyze` clean; 114 tests pass.

## Milestone 11 — completed deliverable

- Firebase integration (`firebase_core`, `firebase_crashlytics`,
  `firebase_performance`, `firebase_analytics`): initialization service,
  Crashlytics error reporting with custom context, Performance monitoring
  with custom traces and HTTP metrics, ErrorLogger unified wrapper.
- Crashlytics: auto-record Flutter errors, PlatformDispatcher errors,
  custom exception context, user ID association, custom keys and logs.
- Performance: screen view traces, HTTP request traces, custom metrics,
  user attributes for segmentation.
- App icons: `flutter_launcher_icons` config for Android/iOS/Web,
  adaptive icon support, placeholder SVG assets and generation guide.
- Splash screen: `flutter_native_splash` config, brand color background,
  centered icon, fullscreen support across platforms.
- `flutter analyze` clean; all 114 tests pass.

## Design documents

- [Architecture](ARCHITECTURE.md)
- Database schema lives under `supabase/migrations/` (Milestone 2).
