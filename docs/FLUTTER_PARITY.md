# BookMySpace Flutter parity report

Worktree: `C:\Users\windows\Desktop\googleAi\bookmyspace-grok`  
Branch: `grok-flutter-parity`  
Base: `d15e6a6 feat: complete BookMySpace platform integration`

Android zip reference (this pass): `C:\Users\windows\Downloads\BookMyspace_Andriod-main.zip` extracted to `C:\Users\windows\Desktop\googleAi\bookmyspace-android-ref\BookMyspace_Andriod-main`.

This is **not** a Kotlin-to-Dart conversion. Native Android remains untouched. Flutter stays online-first: Supabase is the business-data source of truth. Razorpay order creation, webhook verification, and refunds are unchanged.

The zip’s payment engine stores transactions in Room and seeds demo Cashfree/HMAC logs. Flutter does **not** copy that. Self-healing here is the existing `reconcile_stale_payments` RPC plus an admin health screen over live `payments` / `refunds` / `booking_holds`.

## Android feature inventory

| Area | Android surfaces | Notes |
| --- | --- | --- |
| Auth | Login, profile, settings, legal, role routing | Compose + repository roles |
| Customer | Home (4 sections), search, map, venue details, booking, payment, history, saved, notifications, support, reviews, favorites | Local Room used for map tiles / recent search cache only |
| Owner | Dashboard, create/edit listing, photos, calendar, optimizer, offline-style booking, QR check-in | In-memory repository + Room cache |
| Admin | App sections, listing field config, audit | Feature toggles in repository |
| Institutes | Institutes & classes, owner portal, faculty, plans | In-memory institute models |
| Events / courses | Events and courses screens | Present |
| Location | Hierarchy selector, map picker, GPS | Mix of master data + geocoding |
| Voice / AI | Easy voice booking, speech helper | On-device speech |
| Media | Image carousel | Images only |
| Payments | Razorpay helper | Client helper; not the authority |
| Multilingual | LanguageHelper en/te/hi + more | String map |

Android Room / hardcoded venue datasets were **not** copied.

## Flutter feature inventory (preserved)

Auth (OTP/OAuth, roles, profile), home 4-section catalog, search + AI intent, map, venue details, booking holds, Razorpay TEST checkout, invoices, refunds, reviews, favorites, notifications, support, owner registration/listings/offline bookings, location master, events, courses, rewards/wallet, module registration, analytics, responsive layout.

## Parity matrix

| Feature | Android | Flutter before | Flutter now |
| --- | --- | --- | --- |
| Login / signup / roles / profile / sign out | Yes | Yes | Preserved |
| Home 4 sections + category chips | Yes | Yes | Preserved |
| Dynamic category configuration | Hardcoded catalog | Hardcoded catalog | DB metadata + admin editor; catalog remains fallback |
| Search / AI / voice | Yes | Partial | Assistant screen + alias index |
| Map / GPS / location master | Yes | Yes | Preserved |
| Booking hold → pay → confirm | Yes | Yes (server RPCs) | Preserved Razorpay |
| Booking history / cancel / refund | Yes | Yes | Preserved |
| Reviews / favorites / saved route | Yes | Saved screen unwired | `/saved` routed |
| Notifications / support | Yes | Yes | Preserved |
| Owner listings create/edit/photos | Yes | Yes | Plus submit-for-review |
| Owner QR check-in | Yes | Digital pass only | Owner check-in via server RPC |
| Institute discovery / faculty / classes | Yes | Domain only | List, detail, owner portal |
| Demo sessions / delivery mode | Yes | Course mode enum | Demo flag + online/offline/hybrid |
| Admin listing approval | Partial | Audit only | Approve / reject / publish RPCs |
| Admin category / section config | App sections screen | No | Admin screens |
| Admin booking/payment/refund oversight | Limited | No | Read-only oversight |
| Theme customizer | Yes | Settings palette | Dedicated screen |
| Hindi | Yes | en/te only | hi + English fallback |
| Video media | No | Images | `media_kind` ready, images rendered |

## Completed in this worktree

- Additive migration `20260822120000_flutter_parity_foundation.sql`
- Additive migration `20260822140000_admin_payment_health.sql`
- Category configuration domain, repository, admin UI, AI alias matching
- Listing lifecycle: draft → pending_approval → approved/rejected → published
- Admin dashboard, listings, categories, app sections, oversight
- Institutes customer + owner flows on `institutes` / `courses` / `institute_faculty` / `institute_media`
- QR check-in RPC (owner/admin; confirmed bookings only)
- Assistant screen, theme customizer, saved route, Hindi
- Tests for configuration, listing status, institutes, check-in, localization
- Zip Android mapping: payment health (server reconcile), unified registration launcher, listing-fields admin UI
- Events/courses/institutes discovery search + filters
- Map geo seed + section chips
- Multilingual AI/voice (EN/TE/HI)
- Invoice `email_queued` status from generate-invoice (service-role outbox only)
- Owner listing validation against category listing-field metadata

## Missing / partial

- Live camera QR decode (manual booking-id check-in is implemented; camera is optional) — **BLOCKED** on adding a camera plugin + web fallback; server check-in already works
- Owner surge/optimizer charts (Android in-memory occupancy %) — Flutter weekly calendar uses live owner bookings instead
- Full Hindi dictionary (core keys translated; others fall back to English)
- Applying `app_customer_sections` visibility onto the first home grid (kept 4 sections so existing home tests remain the customer contract)
- Video/3D players (schema ready only)
- Complete India PIN/city dataset (location master already refuses fabricated geography)
- Browser/device E2E against a live Supabase project — **DEV-NOT-VERIFIED** (no session credentials in this run)
- Production migration apply (additive SQL is in-repo only)
- Client-direct `email_outbox` insert — **BLOCKED** (RLS: authenticated has no insert; `generate-invoice` already enqueues mail with service role)

## Checkpoint (this pass)

Customer discovery and assistant increment, still online-only over Supabase:

- Events list search + category/price filters over `upcomingEventsProvider` (no new event store)
- Courses list search + mode/demo/paid filters over `publishedCoursesProvider`
- Institutes list search + verified-only filter
- Map entry seeds the current search area and section chips so home → map is not empty
- Unified registration launcher localized; still routes into existing module forms
- Invoice screen shows whether `generate-invoice` queued `email_outbox` (`email_queued`). Client still cannot insert outbox rows
- `generate-invoice` also enqueues mail when the PDF already exists (idempotent upsert)
- AI search + booking-intent parsers accept Telugu/Hindi hall/hotel/PG/book/guest/price/date aliases (no per-slug switches)
- Voice uses `te_IN` / `hi_IN` / `en_IN`; home voice no longer requires a selected section; VoiceBookingSheet can listen
- Owner listing save validates known keys from admin listing-field metadata

Not copied from Android Room: payment transaction entities, seeded Cashfree logs, hardcoded KYC, fabricated refunds.

## Database / migration changes

Additive only:

- `venue_categories.metadata`
- `app_customer_sections`
- `venues.listing_status`, `listing_rejection_reason`
- `venue_images.media_kind`
- institute contact/geo columns, `institute_faculty`, `institute_media`
- `courses.is_demo`, `seats`, `schedule_notes`
- `booking_check_ins`
- admin read policies + security-definer RPCs
- configurable `temple` and `exhibition_hall` **category rows** (no fake venues/bookings/PINs)

Android source, Razorpay edge functions, JWT, and production secrets were not modified.

## Test / build results

| Gate | Result |
| --- | --- |
| `flutter test` | Pass (273 tests) |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Pass (infos/warnings only; 0 errors) |
| `git diff --check` | Pass |
| `flutter build web` | Pass (`build\web`) |
| `flutter build apk` | Pass earlier this session (`app-release.apk`, 63.6MB); not re-run this increment |
| Browser / integration | **DEV-NOT-VERIFIED** (no live credentials) |

## Known issues

- Home still uses the four built-in sections as the customer first screen.
- Check-in camera is a placeholder; server check-in by booking id is real.
- Analyzer still reports pre-existing infos/warnings (directives, deprecated APIs).
- `sqflite` appears as a **transitive** plugin dependency; the app does not persist business data locally.

## Files changed (high level)

Flutter: category configuration, admin moderation, institutes, check-in, assistant, theme, router, localization, venue media/listing fields, tests.  
SQL: `supabase/migrations/20260822120000_flutter_parity_foundation.sql`.  
Android: none.
