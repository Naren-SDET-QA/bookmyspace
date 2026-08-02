# BookMySpace — Roadmap

Implementation is split into small, verifiable milestones. Each milestone ends
with formatting, analysis, tests and a meaningful git commit.

| # | Milestone | Status |
| - | --------- | ------ |
| 1 | Foundation: themes, navigation, localization, environments, errors, widgets | ✅ Done |
| 2 | Supabase setup, migrations, auth, profiles, roles, RLS | ⏳ Next |
| 3 | Home, search, maps, venue listings/details, images, favorites | ⏳ |
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

## Design documents

- [Architecture](ARCHITECTURE.md)
- Database schema lives under `supabase/migrations/` (Milestone 2).
