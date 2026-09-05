# BookMySpace — iOS & Web Migration Plan

Goal: every feature that exists today (the native Android reference app's
inventory in `docs/FLUTTER_PARITY.md`, everything already built in the
Flutter app, and the large backlog of features currently sitting
uncommitted in this working tree) runs correctly on Android, iOS, and Web
from the one Flutter codebase.

**Framing up front, because it changes the shape of this plan:** this is
*not* a Kotlin-to-Swift-to-JS port. The app is already Flutter, and Flutter
compiles the same Dart source to all three targets. Most of the app already
works on all three platforms today, for free, because it was built that way
from Milestone 1 — `docs/ROADMAP.md` and `docs/FLUTTER_PARITY.md` both
confirm `flutter build web` and `flutter build apk` are green, and every
screen/provider/repository in `lib/` is plain Dart with no platform
branching except the two files noted below. The work that's left is:
closing a short list of *confirmed* platform-specific gaps, standing up
iOS build verification (which does not exist at all today), and then
working through the large backlog of features that were built against
Android/CI only and have never been checked on iOS or Web at all.

Every gap below was verified by reading the actual file and line in this
checkout — none of this is inferred from the Android reference repo alone.

## Current state — what's already cross-platform

- Every customer and owner feature in the "Flutter feature inventory
  (preserved)" table in `docs/FLUTTER_PARITY.md` — auth, home, search, map,
  venue details, booking holds, Razorpay checkout, invoices, refunds,
  reviews, favorites, notifications, support, owner registration/listings/
  offline bookings, location master, events, courses, rewards/wallet,
  module registration, analytics, responsive layout — is plain Dart over
  Supabase and Riverpod. No platform-specific code.
- Payments already has a real platform split, and it's the pattern the rest
  of this plan reuses: `lib/features/payments/presentation/
  checkout_service_factory.dart` conditionally exports
  `checkout_service_factory_io.dart` (native `razorpay_flutter`, used by
  Android + iOS) or `checkout_service_factory_web.dart`
  (`RazorpayWebCheckoutService`, `dart:js_interop` against Razorpay's
  Checkout.js) based on `dart.library.html`. The web adapter injects its
  own `<script src="https://checkout.razorpay.com/v1/checkout.js">` at
  runtime (`_loadScript()` in `razorpay_web_checkout_service.dart`) — no
  static `<script>` tag is needed in `web/index.html`, which is why there
  isn't one. This already works; verified by reading the implementation in
  full.
- iOS project scaffolding exists and is mostly correct: `ios/Runner/
  Info.plist` already declares `NSMicrophoneUsageDescription`,
  `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`,
  `NSPhotoLibraryAddUsageDescription`, and
  `NSLocationWhenInUseUsageDescription`. `IPHONEOS_DEPLOYMENT_TARGET` is
  13.0 across all three build configs in `Runner.xcodeproj/project.pbxproj`
  — modern enough for every plugin in `pubspec.yaml`.
- Web PWA scaffolding exists: `web/manifest.json` has standard + maskable
  192/512 icons, standalone display, theme color; `web/index.html` has the
  iOS web-app meta tags and favicon wired.
- Maps use `flutter_map` + OpenStreetMap tiles (`latlong2`, no Google Maps
  SDK) — no platform-specific API key or native map view needed on any of
  the three targets.

## Confirmed gaps (verified in this checkout, ranked by how hard they block "all devices work")

**1. There is no iOS build verification anywhere.** `.github/workflows/
ci.yml` has `analyze`, `test`, `build-android` (APK), `build-web`, and
`sql-tests` jobs — zero `build-ios` job, zero macOS runner, zero
`flutter build ios`. `docs/FLUTTER_PARITY.md`'s own "Missing / partial"
list confirms this: *"Browser/device E2E against a live Supabase project
— DEV-NOT-VERIFIED"* and no iOS entry in the test/build results table at
all. Concretely: nobody — not CI, not a prior session — has ever confirmed
this app compiles for iOS. That has to be fixed first, because every other
item on this list is unverifiable without it.

**2. Firebase is not actually configured on any platform, not just iOS/Web.**
`lib/core/firebase/firebase_init.dart` initializes with literal placeholder
values (`'YOUR_API_KEY'`, `'YOUR_APP_ID'`, etc.) on web, and calls
`Firebase.initializeApp()` with no options elsewhere — which requires a
native config file that doesn't exist. Confirmed: no
`ios/**/GoogleService-Info.plist`, no `android/**/google-services.json`, no
generated `lib/firebase_options.dart` anywhere in the repo. `Milestone 11`
in `docs/ROADMAP.md` ("Firebase Crashlytics, Performance, app icons,
splash screen") is marked `⏳` for a reason — it was never actually wired
up on *any* platform, so this isn't an iOS/Web-specific gap, it's a
whole-app gap that happens to block iOS/Web equally with Android.

**3. iOS is missing one required permission string for voice search.**
`speech_to_text` (used by the Easy Voice Booking / assistant screen) needs
*two* Info.plist keys on iOS: `NSMicrophoneUsageDescription` (present) and
`NSSpeechRecognitionUsageDescription` (**absent** — confirmed by grep
against the full key list in `ios/Runner/Info.plist`). Without it, iOS
denies the speech-recognition permission request outright and voice search
silently fails on iOS only.

**4. An uncommitted feature has a hard `flutter build web` blocker.**
`lib/features/venues/infrastructure/supabase_media_repository.dart` (part
of the new, not-yet-committed media-manager feature — `media_item.dart`,
`media_repository.dart`, `media_resilience.dart`,
`owner_venues/presentation/screens/media_manager_screen.dart`) has an
unconditional `import 'dart:io';` at the top of the file. `dart:io` does
not exist for the web compile target — any file that imports it
unconditionally makes `flutter build web` fail to compile the moment
anything reachable from `main.dart` imports that file. It already is
reachable: `SupabaseMediaRepository` is referenced from
`lib/features/venues/presentation/venue_providers.dart`, and the media
manager screen is routed at `/owner/venues/:id/media` in
`lib/core/router/app_router.dart`. This hasn't broken CI yet only because
none of this is committed — the moment it lands on a branch CI builds,
`build-web` goes red. Same fix pattern as payments: split into an
`_io.dart` variant (keeps `dart:io File` for native platforms) and a
`_web.dart` variant (uses bytes/`Uint8List` upload instead of `File`),
conditionally exported like `checkout_service_factory.dart` already does.

**5. Camera-based QR check-in is explicitly incomplete, not just
Android-only.** Already documented in `docs/FLUTTER_PARITY.md`: *"Live
camera QR decode ... BLOCKED on adding a camera plugin + web fallback;
server check-in already works."* This needs a plugin decision (`mobile_scanner`
is the common cross-platform choice — native camera on Android/iOS, `getUserMedia`
on web) plus a web fallback UX, since browser camera access has different
permission semantics than mobile.

**6. `ios/Podfile` has no iOS 14+ permission-usage macros.** The `post_install`
hook only calls `flutter_additional_ios_build_settings(target)` — it
doesn't set the `PERMISSION_*=1` preprocessor defines that
`permission_handler`-family plugins use to strip unused permission
declarations from the compiled binary. Not a functional blocker (the app
will run), but Apple App Store review increasingly flags binaries that
reference permission APIs without a matching, minimal Info.plist
declaration set — worth closing before a real App Store submission, not
before a dev build.

**7. Several plugins in `pubspec.yaml` have materially different — or
weaker — web support than mobile, and none of this has been checked:**
`speech_to_text` on web depends on the browser's Web Speech API, which is
Chrome/Edge-only (no Safari/Firefox support) — voice search needs an
explicit "not supported in this browser" path on web, not a silent
failure. `model_viewer_plus` (3D model viewer, schema-ready per
`FLUTTER_PARITY.md` but not yet rendering real content) uses `<model-viewer>`
web component under the hood on web and native `SceneKit`/`Filament` on
mobile — behavior and performance diverge and need their own check once 3D
media actually ships. `video_player` needs the `video_player_web` platform
package (transitively pulled in, not separately pinned in `pubspec.yaml` —
worth confirming the resolved version supports the codecs actually used).
`geolocator` on web requires HTTPS (or `localhost`) and a browser
permission prompt with different UX than a native OS prompt — the app's
own location-permission-denied handling needs a web-specific copy path,
not just the mobile one.

**8. The large uncommitted feature backlog has zero platform-parity
evidence.** Beyond the media manager above, the working tree currently has
these entire feature areas uncommitted and therefore never build-checked
on any platform in CI: AI chat/observability (`lib/features/ai/`), admin
observability (`lib/features/admin/domain/observability*.dart` +
screens), promotions (`lib/features/promotions/`), venue discovery
(`lib/features/venue_discovery/`), hotel room inventory (`lib/features/
venues/domain/room_inventory*.dart`), tenant configuration, and generic
integrations (`supabase/functions/integration-executor/`, etc.). A quick
scan of those directories for `dart:io`/`Platform.is`/camera/sqflite/
permission_handler usage came back clean except for the media-manager file
above — but "no obvious platform-specific import" is not the same as
"verified to build and run on iOS and Web," and none of it has actually
been compiled for those targets yet.

## Phased plan

### Phase A — Stand up iOS build verification (prerequisite for everything else)
Add a `build-ios` job to `.github/workflows/ci.yml` on a `macos-latest`
runner: `flutter build ios --release --no-codesign` (no signing needed
just to prove it compiles and links). Add a companion `flutter build web
--release` smoke step that also runs `flutter analyze` with web as the
target platform if that's meaningful, though `analyze` is already
platform-agnostic. This is cheap, additive, and is the only way any of the
other phases get real verification instead of a claim.

### Phase B — Fix the two confirmed compile/runtime blockers
1. Add `NSSpeechRecognitionUsageDescription` to `ios/Runner/Info.plist`
   (one line, matches the existing permission-string pattern already
   there).
2. Split `supabase_media_repository.dart` into `_io.dart`/`_web.dart`
   variants behind a conditional export, exactly like
   `checkout_service_factory.dart`. The web variant uploads bytes
   (`Uint8List`, already what `image_picker`/`file_picker` hand back on
   web) directly to Supabase Storage instead of wrapping a `dart:io File`.

### Phase C — Real Firebase configuration (needs your Firebase project — I can't do this from here)
Run `flutterfire configure` against your actual Firebase project once you
have one (or the existing one, if `bookmyspace` already has a Firebase
project you haven't shared credentials for). That single command generates
`lib/firebase_options.dart`, drops `google-services.json` into `android/app/`,
and drops `GoogleService-Info.plist` into `ios/Runner/` — replacing the
placeholder values in `firebase_init.dart` with real per-platform config.
This is the one phase that's blocked on you, not on code I can write here.

### Phase D — iOS App Store hygiene
Add the `PERMISSION_*` preprocessor defines to `ios/Podfile`'s
`post_install` block, scoped to only the permissions the app actually asks
for (location, camera, photo library, microphone, speech). Not required
for a dev build; required before a real TestFlight/App Store submission.

### Phase E — Web-specific behavior audit
For each plugin flagged in gap 7: add an explicit unsupported-browser path
for `speech_to_text` on web (feature-detect, don't just let it fail
silently), confirm `geolocator`'s web permission-denied copy is written
for a browser prompt rather than an OS settings deep-link, and defer
`model_viewer_plus` real-content testing until 3D media actually ships
(it's schema-ready only right now per `FLUTTER_PARITY.md`, so there's
nothing to test yet).

### Phase F — Camera QR check-in, properly cross-platform this time
Add `mobile_scanner` (or equivalent), wire the existing server-side
check-in RPC (already working, per `FLUTTER_PARITY.md`) to a real camera
feed on Android/iOS and `getUserMedia` on web, with the existing
manual-booking-id path kept as the fallback everywhere it doesn't have
camera permission.

### Phase G — Merge and platform-verify the uncommitted backlog, feature by feature
Once Phase A's CI job exists, bring each of the eight-plus uncommitted
feature areas (AI, admin observability, promotions, venue discovery, hotel
rooms, tenant configuration, integrations, plus the already-staged
pay-at-venue/promo-codes/owner-approval work from earlier in this session)
onto a branch one at a time and let CI actually prove each one builds for
Android, iOS, and Web before merging — rather than assuming "no
`dart:io` found" is equivalent to "verified."

### Phase H — Device/browser QA matrix and store readiness
Real iOS simulator + at least one physical device pass; Safari desktop +
Safari iOS + Chrome + Firefox web pass (this is explicitly
DEV-NOT-VERIFIED today per `FLUTTER_PARITY.md`, not a formality). Then
App Store Connect signing/provisioning + privacy nutrition label
declarations for every permission actually used (location, camera,
microphone, speech, photo library), and a web hosting/deployment target
(custom domain, HTTPS — required for `geolocator` — and cache headers for
the Flutter web build output).

## What I can't do from this sandbox

I have no `flutter`/`dart` toolchain and no Xcode anywhere in this session
(verified repeatedly earlier this engagement), so I can't run any of
Phases A, C, G, or H's build/test steps myself — those need to run on your
machine or in CI. What I *can* do from here: write the Phase B code fixes,
add the Phase A CI job YAML, add the Phase D Podfile/Info.plist changes,
and scaffold Phase F's camera integration — all as normal code changes,
same as the payment work earlier in this session, each one small and
independently verifiable once you or CI can actually run `flutter build`.

Say which phase to start on and I'll implement it under the same
DEV-only, minimum-necessary-change, no-commit-without-asking rules that
have applied all session.
