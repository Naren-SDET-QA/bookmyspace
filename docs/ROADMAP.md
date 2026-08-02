# BookMySpace — Roadmap

Implementation is split into small, verifiable milestones. Each milestone ends
with formatting, analysis, tests and a meaningful git commit.

| # | Milestone | Status |
| - | --------- | ------ |
| 1 | Foundation: themes, navigation, localization, environments, errors, widgets | ✅ Done |
| 2 | Supabase setup, migrations, auth, profiles, roles, RLS | ✅ Done |
| 3 | Home, search, maps, venue listings/details, images, favorites | ⏳ Next |
| 4 | Availability calendar, slots, booking holds, atomic logic, concurrency tests | ⏳ |
| 5 | Razorpay orders, verification, webhooks, reconciliation, refunds | ⏳ |
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

## Design documents

- [Architecture](ARCHITECTURE.md)
- Database schema lives under `supabase/migrations/` (Milestone 2).
