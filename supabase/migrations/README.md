# Supabase Migrations & Multi-Environment Strategy

SQL migrations represent the single source of truth for the database schema across DEV, STAGING, and PROD environments.

## Convention
Files follow `NNNN_name.sql` where `NNNN` is a 4-digit incrementing sequence number.

## Environment Architecture (DEV → STAGING → PROD)
- **DEV**: Isolated Supabase project used by Android, iOS, and Web developers. Contains test users & test venues (Function Hall, Hotel/Stay, PG/Co-Living).
- **STAGING/UAT**: Pre-production validation environment connected to staging builds.
- **PROD**: Protected live environment. Never modified directly or manually synced with data copies.

## Migration Promotion Rules
1. **Immutable Migrations**: Deployed migrations (`0001_` through `0018_`) are immutable. Never modify or delete previously applied migration files.
2. **Forward-Only**: All schema adjustments, RPC updates, or policy changes must be authored as NEW forward-only SQL migrations (`0019_`, `0020_`, etc.).
3. **Automated Deployment**:
   ```bash
   # Deploy to DEV
   supabase db push --linked --project-ref $DEV_PROJECT_REF

   # Deploy to STAGING
   supabase db push --linked --project-ref $STAGING_PROJECT_REF

   # Deploy to PROD (Protected Release Workflow)
   supabase db push --linked --project-ref $PROD_PROJECT_REF
   ```
4. **Zero Structural Resets**: Never execute `DROP DATABASE`, `TRUNCATE`, or `db reset` on shared STAGING or PROD instances.

## Local CLI Workflow
```bash
supabase start          # start local stack (requires Docker)
supabase migration new  # create a new forward-only migration
supabase db reset       # apply all migrations locally
```
