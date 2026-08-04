# Free-first production stack

BookMySpace can be developed and launched without a monthly infrastructure bill
while traffic is inside the providers' free quotas.

| Need | Free-first choice | Notes |
| --- | --- | --- |
| App | Flutter | Open source; Android, iOS and web from one codebase. |
| Database, auth, storage | Supabase Free | Postgres, authentication, storage and Edge Functions. Upgrade only after the free quota is exceeded. |
| Maps | OpenStreetMap + `flutter_map` + Nominatim + OSRM | No Google Maps/Places billing. Tiles/geocoding/routing are free public OSM services; set `USE_GOOGLE_PLACES=true` only for optional enrichment. |
| Fonts | Plus Jakarta Sans via Google Fonts | Open Font License. |
| Push/crash/analytics | Firebase Spark | No-cost quota for the services used here. |
| CI | GitHub Actions | Free allowance for public repositories and a monthly allowance for private repositories. |
| Web hosting | Cloudflare Pages or GitHub Pages | Both offer a usable free tier for the Flutter web build. |
| Android distribution | Direct APK/PWA | Free. Google Play's developer registration is not free. |
| iOS distribution | PWA | Free. Native App Store distribution requires Apple's paid developer membership. |

## Costs that cannot honestly be guaranteed as zero

- Online payment processors charge per successful transaction. Keep Razorpay
  disabled until merchant credentials are supplied; the rest of the app works
  without it.
- SMS OTP can incur message charges after provider quotas. Email magic links and
  OAuth are the preferred free-first sign-in methods.
- A custom domain, Google Play registration and Apple Developer membership are
  optional external costs.

## Production launch checklist

1. Create separate Supabase projects for staging and production and apply every
   migration in `supabase/migrations`.
2. Inject secrets with `--dart-define`; never commit real keys.
3. Configure OAuth redirect URLs, database backups, rate limits and alerting.
4. Run `flutter analyze`, `flutter test`, and release builds in CI.
5. Complete privacy, terms, support contact and account-deletion details with
   the business's real information.
6. Test booking concurrency, webhook idempotency, refunds and restore flows in
   staging before accepting real money.
