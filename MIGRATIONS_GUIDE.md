# BookMySpace — Supabase Migrations & Promotion Guide

This document establishes the official database migration policy, migration creation guidelines, and promotion workflow across **DEV**, **STAGING**, and **PROD** environments for BookMySpace (supporting Android, iOS, and Web platforms).

---

## 1. Architectural Principles & Environment Separation

1. **Git as Single Source of Truth**: All database schema definitions, RLS policies, custom types, triggers, and RPC functions live in repository SQL migration files under `/supabase/migrations`.
2. **Environment Isolation**:
   - **DEV**: Dedicated Supabase project populated strictly with test data (Function Hall, Hotel/Stay, PG/Co-Living) and test users. Uses **Razorpay TEST mode**.
   - **STAGING / UAT**: Isolated staging project for end-to-end integration testing and client validation prior to release.
   - **PROD**: Protected live environment containing real user bookings and live payment channels (**Razorpay LIVE mode**).
3. **Cross-Platform Parity**: Android, iOS, and Web applications run against the same database schema per environment, configured via environment flags (`APP_ENV=development|staging|production`) without code rewrites.

---

## 2. Forward-Only Migration Policy

To prevent database drift, corruption, or data loss across environments, all database changes MUST strictly adhere to the following rules:

* **Immutable History**: Once a migration file (`NNNN_description.sql`) has been applied to any shared environment or committed to main, it is **IMMUTABLE**. Never edit, modify, or delete existing migration files (e.g., `0001_` through `0018_`).
* **Forward-Only Changes**: Any schema modification, bug fix, column addition, or RPC function update must be authored as a **NEW forward-only migration** with an incremented sequence number (e.g., `0019_`, `0020_`).
* **Non-Destructive Execution**: `DROP TABLE`, `TRUNCATE`, and `supabase db reset` commands are strictly forbidden on shared DEV, STAGING, or PROD databases.
* **Idempotent SQL**: Write migrations defensively using idempotent constructs:
  - `CREATE OR REPLACE FUNCTION ...`
  - `CREATE TABLE IF NOT EXISTS ...`
  - `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...`
  - `DO $$ BEGIN IF NOT EXISTS (...) THEN ALTER TABLE ... END IF; END $$;`

---

## 3. Creating New SQL Migrations

### Step 1: Create a New Migration File
Using the Supabase CLI locally:
```bash
# Generate a new migration file with a 4-digit sequence prefix
supabase migration new <descriptive_name>
```
*Manual creation*: Add a file in `/supabase/migrations/` following `NNNN_descriptive_name.sql` (e.g., `0019_add_venue_cancellation_policy.sql`).

### Step 2: Write Safe SQL
Ensure all statements are wrapped safely and include necessary Row Level Security (RLS) policies:
```sql
-- Example: 0019_add_venue_cancellation_policy.sql

-- 1. Add cancellation policy column defensively
ALTER TABLE public.venues 
ADD COLUMN IF NOT EXISTS cancellation_policy text DEFAULT 'Flexible: Full refund up to 24h prior.';

-- 2. Create or update RPC function
CREATE OR REPLACE FUNCTION public.get_venue_cancellation_policy(p_venue_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN (SELECT cancellation_policy FROM public.venues WHERE id = p_venue_id);
END;
$$;
```

### Step 3: Test Locally
```bash
# Apply migrations to local Docker container
supabase start
supabase db reset
```

---

## 4. Migration Promotion Workflow (DEV → STAGING → PROD)

```
[ Developer Local ]
       │
       ▼ (supabase db push)
 ┌───────────┐
 │   DEV     │ ◄── Automated / Manual test verification with test data
 └─────┬─────┘
       │ (PR approval & merge to release branch)
       ▼ (supabase db push --project-ref $STAGING_REF)
 ┌───────────┐
 │  STAGING  │ ◄── End-to-end UAT & client app regression testing
 └─────┬─────┘
       │ (Gated Release Approval)
       ▼ (supabase db push --project-ref $PROD_REF)
 ┌───────────┐
 │   PROD    │ ◄── Production execution (No manual DB edits)
 └───────────┘
```

### Phase 1: DEV Environment Promotion
1. Link your local project or CLI to the DEV Supabase project:
   ```bash
   supabase link --project-ref $DEV_PROJECT_REF
   ```
2. Apply missing migrations to DEV:
   ```bash
   supabase db push
   ```
3. Run test suites and verify feature functionality on Android/iOS/Web using DEV credentials (`.env.dev`).

### Phase 2: STAGING Environment Promotion
1. Open a Pull Request containing the new migration file(s).
2. Upon approval and merge to `staging` or `main`:
   ```bash
   supabase db push --linked --project-ref $STAGING_PROJECT_REF
   ```
3. Execute UAT and verify system stability.

### Phase 3: PROD Release
1. Trigger release deployment pipeline or execute production push with release engineer authorization:
   ```bash
   supabase db push --linked --project-ref $PROD_PROJECT_REF
   ```
2. Confirm migration status:
   ```bash
   supabase migration list --project-ref $PROD_PROJECT_REF
   ```

---

## 5. Security & Environment Configuration

* **Never Commit Credentials**: Real project reference IDs, database passwords, anon keys, service role keys, and Razorpay secrets must never be committed to Git.
* **Environment Files**:
  - `/.env.dev.example` -> Template for DEV (`.env.dev`)
  - `/.env.staging.example` -> Template for STAGING (`.env.staging`)
  - `/.env.prod.example` -> Template for PROD (`.env.prod`)
* **Secrets Panel**: Store actual keys securely in your CI/CD provider's secret vault or AI Studio Secrets panel.
