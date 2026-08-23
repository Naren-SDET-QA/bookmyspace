# BookMySpace modular architecture (foundation)

Worktree: `C:\Users\windows\Desktop\googleAi\bookmyspace-grok`  
Phase: **foundation only** — no business-feature expansion, no schema/migration, no Android/production changes.

This document is the contract for an incremental plug-and-play layer. Existing screens, repositories, Razorpay, booking RPCs, and RLS stay authoritative. The registry decides **whether** a capability is exposed and **which plugin** may be resolved. It does not replace Supabase as the business-data source.

## Existing architecture

```
main.dart
  ErrorLogger.init()          // Firebase Crashlytics / Performance (best-effort)
  initSupabase()              // always, even if later features are unused
  BookMySpaceApp (Riverpod)
    createAppRouter()         // go_router, auth/role redirect
    feature screens watch *Providers which construct Supabase* repositories
```

Layering today:

| Layer | Pattern | Notes |
| --- | --- | --- |
| UI | `lib/features/*/presentation` | Riverpod `ConsumerWidget` / `ConsumerStatefulWidget` |
| State | `*Providers` | `Provider` / `FutureProvider` / `StateProvider` |
| Domain | models + repository interfaces | e.g. `VenueRepository`, `CheckoutService` |
| Infrastructure | `supabase_*_repository.dart` | PostgREST, RPCs, edge functions |
| Backend | Supabase Postgres + Edge Functions | bookings, payments, invoices, email_outbox |

Supabase is the only runtime business-data source. There is no Room/SQLite/Hive/Isar/Drift business cache in app code.

## Existing providers (representative)

| Area | Riverpod / service | Data |
| --- | --- | --- |
| Auth | `authRepositoryProvider`, `supabaseProvider` | Supabase Auth |
| Location | `searchAreaProvider`, `locationRepositoryProvider`, `GeocodingService` | `locations` master + device GPS |
| Venues / search | `venueRepositoryProvider`, `searchQueryProvider`, `searchResultsProvider` | `venues`, `search_venues` RPC |
| Categories | `categoryConfigurationsProvider` | `venue_categories.metadata` (no per-slug enums) |
| Booking | `bookingRepositoryProvider` | holds / confirm / cancel RPCs |
| Payments | `paymentRepositoryProvider`, `CheckoutService` | `create-payment-order`, webhook, Razorpay SDK |
| Events / courses / institutes | respective `*RepositoryProvider` | `events`, `courses`, `institutes` |
| Notifications | `notificationRepositoryProvider` | `notifications` table |
| Analytics | `analyticsEventRepositoryProvider` | `analytics_events` |
| AI / voice | local parsers + `speech_to_text` | no LLM required; aliases from category metadata |
| Email | `generate-invoice` edge function | `email_outbox` via **service_role only** |
| WhatsApp | none | not implemented |

`CheckoutService` is already a replaceable interface (`io` vs `web` factories, fakes in tests). `ExternalLocationProvider` already exists for geocoding candidates. Do **not** invent a new interface for every repository.

## Feature boundaries (as the app is used)

| Feature | UI / routes | Required runtime |
| --- | --- | --- |
| Location | location bar, picker, owner/admin location screens | `locations` + geocoding |
| Maps | `/map`, home chip | flutter_map + `searchResultsProvider` |
| Search | `/search` | venue search RPC |
| Booking | `/venues/:id/book`, `/bookings` | booking RPCs; **not** client-side inventory |
| Payments | `/bookings/:id/pay`, `/payments` | Razorpay + server order/webhook |
| Razorpay | checkout SDK | only when a payment UI opens |
| Function Hall / Hotels / PG / Institutes | home 4-section catalog | `CustomerSection` fallback + DB categories |
| Courses | `/courses` | `courses` |
| Events | `/events` | `events` |
| Registration | `/register`, `/register/:module` | module_registration tables |
| AI | `/assistant`, search intent parse | local; category alias index |
| Voice | home dialog, assistant mic, VoiceBookingSheet | `speech_to_text`, lazy on tap |
| Notifications | shell tab, `/notifications` | `notifications` |
| Email | invoice “queued” copy | server outbox; client never inserts |
| WhatsApp | — | no SDK today |
| Analytics | `/analytics`, `/my-analytics` | analytics tables |

## Current configuration (problems)

`lib/core/debug/feature_flags.dart` already lists some toggles (`functionHall`, `hotels`, `pg`, `events`, `courses`, `mapSearch`, …) but they are **debug-menu only**. They do not:

- hide home/navigation
- block routes
- skip repository/SDK init
- declare dependencies
- name a replaceable provider

Flags are therefore not a plugin system. Screens hard-code chips, routes, and `MainHomeSection.values`.

## Dependencies

Directed graph for the foundation (required unless marked optional):

```
location
  └── maps
  └── booking
        └── payments (optional for hold/offline; required to capture)
              └── razorpay (payment provider)

search
  └── voice (optional: ai)

availability is not a separate product feature. It is the booking
repository's slot RPC. Booking treats it as an always-on capability of
the booking module, not a new database.

institutes, courses, events, registration, notifications, email,
whatsapp, analytics, functionHall, hotels, pg: independent product
surfaces. Courses do not require institutes to be enabled (list is
already a separate table).
```

If a **required** dependency is disabled:

- the dependent feature is **not available**
- the app does not crash
- UI/route get a safe unavailable/hidden state
- plugins for the dependent feature are not initialized

If an **optional** dependency is disabled (e.g. payments while booking is on):

- booking remains available
- pay-now is hidden / payment route unavailable
- no Razorpay SDK init

## Proposed registry

Central types in `lib/core/modular/`:

```
FeatureId          // closed set of product capabilities
FeatureConfig      // enabled, config map, provider id, dependencies
FeatureRegistry    // FeatureRegistry.configure(...)
PluginKind         // payment | map | ai | notification | location
AppPlugin          // lazy initialize / initialized flag
ProviderRegistry   // factories, resolve(), replace()
MutationGuard      // blocks duplicate booking/payment retries
```

`FeatureConfig`:

```dart
FeatureConfig(
  enabled: true,
  provider: 'razorpay',          // optional plugin id
  config: const {},              // feature-local knobs only
  dependencies: [...],           // required FeatureIds
  optionalDependencies: [...],
)
```

Safe defaults: **every listed feature is enabled**, matching today’s product. Disabling is opt-out. Unknown future features are not in the enum until a module is added — categories from the database remain generic via `CategoryConfiguration`, not new enums.

Static configuration (single place):

```dart
FeatureRegistry.configure(
  FeatureId.maps,
  enabled: true,
  provider: 'flutter_map',
  config: {'tile': 'osm'},
);
```

Riverpod `featureRegistryProvider` exposes the same instance to UI so home/router do not copy maps of booleans.

## Provider registry

Only five plugin kinds (real replacement value):

| Kind | Default | Replace with |
| --- | --- | --- |
| `location` | `supabase` (+ existing geocoding) | another `ExternalLocationProvider` |
| `map` | `flutter_map` | another map SDK later |
| `payment` | `razorpay` | another `CheckoutService` |
| `ai` | `local_intent` | another parser/LLM later |
| `notification` | `supabase` | another inbox later |

Rules:

- `register(kind, factory)` stores a **factory**, not a live SDK
- `resolve(kind)` instantiates once, then `ensureInitialized()`
- disabled feature → callers must not resolve; `tryResolve` returns null
- `replace(kind, factory)` disposes previous instance if any
- no stream listeners in the registry itself
- no Supabase queries in the registry

Existing `CheckoutService` remains the payment plugin contract. Do not wrap `VenueRepository`.

## Lazy initialization strategy

| Work | When |
| --- | --- |
| `FeatureRegistry.defaults()` | process start, pure memory, no I/O |
| Supabase client | `main()` — auth still requires it (out of scope to delay) |
| Razorpay SDK | first `CheckoutService.openCheckout` (already true) |
| Speech | first mic tap (already true) |
| flutter_map tiles | first `/map` build (already true) |
| Feature plugins | first `ProviderRegistry.resolve` |
| Feature repositories | first Riverpod watch of a **shown** screen |

Disabled maps: no `/map` route exposure, no map plugin resolve, home chip hidden. Disabled PG: home section hidden; other sections unchanged. Unknown DB category slugs still render through `CategoryConfiguration`.

## Self-healing strategy

Reuse `withRetry` (`lib/core/network/retry.dart`) for **idempotent reads and plugin init only**.

| Event | Action |
| --- | --- |
| Plugin init throws | bounded exponential backoff (`maxRetries` 3), then mark unavailable |
| Stale plugin (`initialized` but subsequent use fails as disposed) | dispose + factory() once |
| Transient network on GET/search | existing `withRetry` / dio retry |
| Feature misconfiguration (unknown provider id) | fall back to default factory or `NoopPlugin`; disable that capability |
| Optional plugin missing (WhatsApp) | capability off; app continues |
| Booking/payment **mutation** | **never** auto-retried by this layer |

`MutationGuard` records an operation key (`booking:create:{idempotency}`, `payment:order:{bookingId}`). Self-healing must refuse a second begin for the same key. Server RPCs remain the authority against duplicates.

No infinite loops. No fabricated rows. No RLS bypass.

## Migration plan (incremental, this phase = step 1)

1. **Foundation (this change)**  
   Registry + plugin host + mutation guard + tests. Wire **only**:
   - home section/chip visibility
   - router redirect for a small set of feature routes  
   Defaults keep current UX so existing tests stay green.

2. **Later, per module (not this change)**  
   Payment screen asks `tryResolve(PluginKind.payment)`  
   Map screen asks maps plugin  
   Debug menu writes `FeatureRegistry.configure` instead of a parallel flag map  

3. **Do not**  
   Rewrite catalogs into `HotelCategory` enums  
   Split the app into package plugins yet  
   Delay `initSupabase()` (auth depends on it)  
   Add tables or apply migrations

## Risks

| Risk | Mitigation |
| --- | --- |
| Hiding a default-on section breaks home tests | Defaults match the 4-section contract |
| Router redirect fights auth redirect | Feature check runs **after** auth/role gating |
| Global singleton leaks across tests | `FeatureRegistry.reset()` in test setUp/tearDown |
| Wrapping every repository | Only five plugin kinds |
| Self-healing double-charge | `MutationGuard` + no retry on checkout/create-order |
| Feature flags vs registry drift | Debug flags remain unused for product paths; registry is source of truth |
| Tree-shaking | Keep plugin factories in existing conditional exports (`checkout_service_factory*.dart`); do not eagerly import SDKs in `main.dart` |

## Foundation delivered (this change)

Implemented in `lib/core/modular/` with tests in `test/core/modular/`.

Wired into:

- `FeatureRegistry.configure` / `apply` as the single product toggle
- Home 4-section grid + Events/Courses/Map chips
- `resolveAppRedirect` for mapped feature routes

Wired in this checkpoint:

- Shell `NavigationBar` destinations from `visibleShellDestinations`
- Real `CheckoutService` / OSM map config / `speech_to_text` factories in `registerDefaultPlugins`
- Lazy construct: checkout on first pay, map plugin on map tiles, speech on mic tap

Still later:

- Debug menu writing the registry instead of `feature_flags.dart`
- Delaying `initSupabase()` (blocked: auth depends on it)

Defaults keep every feature **on**, so existing UX and tests stay unchanged.

## Out of scope (this phase)

Android, production, JWT, RLS, booking/payment backends, Razorpay backend, location master data, DEV data, migrations, new tables, new customer features, camera QR, WhatsApp SDK.
