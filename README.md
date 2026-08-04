# BookMySpace

A production-ready platform for discovering and booking venues, events and
courses — built with Flutter, Supabase, and a fully managed backend.

> **Status:** Feature-complete production candidate. Environment credentials,
> store accounts and final staging acceptance are required before launch.

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

# 4. Copy env template and fill in your credentials (never commit .env)
cp .env.example .env   # Windows: copy .env.example .env

# 5. Run the app (loads dart-defines from .env)
.\scripts\flutter_run.ps1          # Windows
# ./scripts/flutter_run.sh         # macOS/Linux

# Or pass defines manually:
flutter run --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=<project-url> \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key> \
  --dart-define=RAZORPAY_KEY_ID=<rzp_test_key_id>
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

Supabase configuration has no runtime fallback. The app fails clearly when
`SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing. Values are injected at build time.
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
- [Free-first production stack](docs/FREE_PRODUCTION_STACK.md)

## License

Proprietary. © BookMySpace.
