-- Test harness: minimal Supabase `auth` schema stub for local migration validation.
-- NOT used in production. Simulates auth.users so migrations apply on plain Postgres.
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  instance_id uuid,
  email text,
  phone text,
  raw_user_meta_data jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- Demo user so migration 0007 seed data (org, venues) is created locally.
insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000001',
  'owner@demo.com',
  '{"full_name": "Demo Owner"}'
)
on conflict (id) do nothing;
