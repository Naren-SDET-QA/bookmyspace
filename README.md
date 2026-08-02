# BookMySpace

A production-ready platform for discovering and booking venues, events and
courses — built with Flutter, Supabase, and a fully managed backend.

> **Status:** Milestone 1 (foundation) complete. See [ROADMAP.md](docs/ROADMAP.md).

## Stack

| Layer      | Technology                                                          |
| ---------- | ------------------------------------------------------------------- |
| Mobile     | Flutter (latest stable), Dart, Material 3                           |
| State      | Riverpod, GoRouter                                                  |
| Networking | Dio, CachedNetworkImage                                             |
| Storage    | FlutterSecureStorage (tokens only)                                  |
| Backend    | Supabase (Postgres, Auth, Storage, Realtime, Edge Functions)        |
| Payments   | Razorpay (abstraction layer for future Stripe)                      |
| Notifications / Analytics | Firebase Messaging, Crashlytics, Analytics, Remote Config |

## Getting started

```bash
# 1. Install Flutter (https://docs.flutter.dev/get-started/install)
# 2. Clone and fetch dependencies
flutter pub get

# 3. Run formatting, analysis and tests
dart format lib test
flutter analyze
flutter test

# 4. Run the app (development environment)
flutter run --dart-define=APP_ENV=development
```

## Environments

Five environments are supported via `--dart-define=APP_ENV=...`:

| Env          | Purpose                    | `APP_ENV` value |
| ------------ | -------------------------- | --------------- |
| local        | Local Supabase (Docker)    | `local`         |
| development  | Dev team work              | `development`   |
| testing      | Automated tests            | `testing`       |
| staging      | Pre-production validation  | `staging`       |
| production   | Live users                 | `production`    |

All secrets are placeholders in code. Real values are injected at build time.
See [.env.example](.env.example).

## Repository layout

```
lib/
  app.dart                    # Root widget (router, theme, locale)
  main.dart                   # Entry point
  core/
    config/                   # Environment config + preferences
    constants/                # App-wide constants
    errors/                   # Typed exceptions
    localization/             # en + te localizations
    network/                  # Dio client with error mapping
    router/                   # GoRouter configuration
    theme/                    # Material 3 light/dark themes
    widgets/                  # Reusable widgets
  features/                   # Feature modules (clean architecture)
  shared/                     # Cross-cutting domain/data/infrastructure
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Database schema](supabase/migrations/README.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Security checklist](docs/SECURITY.md)

## License

Proprietary. © BookMySpace.
