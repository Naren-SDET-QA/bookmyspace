# BookMySpace — Architecture

## High-level

```
┌──────────────────────────────┐
│   Flutter App (Android/iOS)   │
│  Presentation (Riverpod)      │
│  Application (use-cases)      │
│  Domain (entities, repos)     │
│  Data (repositories)          │
│  Infrastructure (Supabase/API)│
└──────────────┬───────────────┘
               │ HTTPS
┌──────────────▼───────────────┐
│   Supabase (managed)          │
│  Postgres + RLS               │
│  Auth (OTP / OAuth)           │
│  Storage (images)             │
│  Realtime (notifications)     │
│  Edge Functions (payments)    │
└──────────────┬───────────────┘
               │
      ┌────────▼────────┐
      │  Razorpay /     │
      │  Stripe (later) │
      └─────────────────┘
```

## Layers (clean architecture)

1. **Presentation** — screens, widgets, Riverpod state. No business logic.
2. **Application** — use cases orchestrating repositories.
3. **Domain** — pure Dart entities + repository interfaces. No frameworks.
4. **Data** — repository implementations mapping DTOs to entities.
5. **Infrastructure** — Supabase client, Dio, storage, external APIs.

The **domain** never depends on Supabase. Swapping the backend only changes the
data/infrastructure layers.

## Security model

- Row Level Security enforced server-side on every table.
- JWT claims drive role checks (never trust client-only checks).
- Payment secrets live only in Edge Functions; the app never sees them.
- Tokens live only in FlutterSecureStorage.

## Scalability

- Stateless Edge Functions; connection pooling via Supabase.
- Cursor-based pagination on all list endpoints.
- CDN image delivery with thumbnails.
- Queue-based async processing (notifications, webhooks).

See [ROADMAP.md](ROADMAP.md) for milestone status.
