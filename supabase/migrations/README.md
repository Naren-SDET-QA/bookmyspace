# Supabase Migrations

SQL migrations are added in Milestone 2 (database schema, RLS policies, seed data).

Convention: `NNNN_name.sql` where `NNNN` is an incrementing sequence.

Run locally with the Supabase CLI:
  supabase start          # start local stack (requires Docker)
  supabase db reset       # apply all migrations
  supabase migration new  # create a new migration
