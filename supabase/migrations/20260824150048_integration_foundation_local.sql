-- Local-only Phase 6.1 integration configuration foundation.
-- No credentials, external calls, executors, or booking changes are included.

create table if not exists public.integrations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  type text not null check (type in ('REST_API','GRAPHQL','MCP','WEBHOOK','SUPABASE_RPC')),
  provider text,
  description text,
  icon text,
  enabled boolean not null default false,
  environment text not null default 'development' check (environment in ('development','staging','production')),
  base_url text,
  authentication_type text not null default 'NONE' check (authentication_type in ('NONE','API_KEY','BEARER_TOKEN','BASIC_AUTH','OAUTH2','CUSTOM_HEADER','MCP_AUTH')),
  configuration jsonb not null default '{}'::jsonb,
  input_schema jsonb not null default '{}'::jsonb,
  output_schema jsonb not null default '{}'::jsonb,
  status text not null default 'disabled' check (status in ('disabled','enabled','error','testing')),
  display_order integer not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table if not exists public.integration_credentials (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references public.integrations(id) on delete cascade,
  secret_reference text not null,
  environment text not null default 'development' check (environment in ('development','staging','production')),
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  rotated_at timestamptz,
  unique (integration_id, environment, secret_reference)
);

create table if not exists public.integration_actions (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references public.integrations(id) on delete cascade,
  name text not null,
  slug text not null,
  method text not null default 'POST' check (method in ('GET','POST','PUT','PATCH','DELETE')),
  endpoint text,
  tool_name text,
  headers_template jsonb not null default '{}'::jsonb,
  query_template jsonb not null default '{}'::jsonb,
  path_template jsonb not null default '{}'::jsonb,
  body_template jsonb not null default '{}'::jsonb,
  request_mapping jsonb not null default '{}'::jsonb,
  response_mapping jsonb not null default '{}'::jsonb,
  timeout_ms integer not null default 10000 check (timeout_ms between 100 and 120000),
  retry_config jsonb not null default '{"max_attempts": 1}'::jsonb,
  enabled boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (integration_id, slug)
);

create table if not exists public.integration_mappings (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references public.integration_actions(id) on delete cascade,
  source_path text not null,
  target_path text not null,
  direction text not null default 'request' check (direction in ('request','response')),
  transform text,
  display_order integer not null default 0,
  enabled boolean not null default true,
  unique (action_id, direction, source_path, target_path)
);

create table if not exists public.integration_events (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references public.integrations(id) on delete cascade,
  action_id uuid references public.integration_actions(id) on delete cascade,
  event_name text not null check (event_name in ('booking.created','booking.held','booking.confirmed','booking.cancelled','payment.created','payment.success','payment.failed')),
  payload_mapping jsonb not null default '{}'::jsonb,
  enabled boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (integration_id, action_id, event_name)
);

create table if not exists public.integration_tools (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references public.integrations(id) on delete cascade,
  tool_name text not null,
  description text,
  input_schema jsonb not null default '{}'::jsonb,
  output_schema jsonb not null default '{}'::jsonb,
  enabled boolean not null default false,
  discovered_at timestamptz,
  unique (integration_id, tool_name)
);

create table if not exists public.integration_logs (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid references public.integrations(id) on delete set null,
  action_id uuid references public.integration_actions(id) on delete set null,
  event_id uuid references public.integration_events(id) on delete set null,
  request_id uuid,
  status text not null check (status in ('queued','running','success','failed','disabled','timeout')),
  duration_ms integer,
  error_code text,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists integrations_enabled_order_idx on public.integrations(enabled, display_order) where archived_at is null;
create index if not exists integration_actions_enabled_idx on public.integration_actions(integration_id, enabled, display_order);
create index if not exists integration_events_enabled_idx on public.integration_events(event_name, enabled);
create index if not exists integration_logs_created_idx on public.integration_logs(created_at desc);

alter table public.integrations enable row level security;
alter table public.integration_credentials enable row level security;
alter table public.integration_actions enable row level security;
alter table public.integration_mappings enable row level security;
alter table public.integration_events enable row level security;
alter table public.integration_tools enable row level security;
alter table public.integration_logs enable row level security;

drop policy if exists integrations_admin_read on public.integrations;
create policy integrations_admin_read on public.integrations for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
drop policy if exists integrations_admin_write on public.integrations;
create policy integrations_admin_write on public.integrations for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists integration_credentials_admin_read on public.integration_credentials;
create policy integration_credentials_admin_read on public.integration_credentials for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));
drop policy if exists integration_credentials_admin_write on public.integration_credentials;
create policy integration_credentials_admin_write on public.integration_credentials for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

do $$ declare t text; begin
  foreach t in array array['integration_actions','integration_mappings','integration_events','integration_tools'] loop
    execute format('drop policy if exists %I on public.%I', t || '_admin_read', t);
    execute format('create policy %I on public.%I for select to authenticated using (public.has_role(auth.uid(), ''administrator'') or public.has_role(auth.uid(), ''super_administrator''))', t || '_admin_read', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_write', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.has_role(auth.uid(), ''administrator'') or public.has_role(auth.uid(), ''super_administrator'')) with check (public.has_role(auth.uid(), ''administrator'') or public.has_role(auth.uid(), ''super_administrator''))', t || '_admin_write', t);
  end loop;
end $$;

drop policy if exists integration_logs_admin_read on public.integration_logs;
create policy integration_logs_admin_read on public.integration_logs for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

-- Table privileges are deliberately broad enough for RLS policy evaluation;
-- the policies above remain the authorization boundary.  Credentials contain
-- references only, never secret material, and logs contain no credentials.
revoke all on public.integrations, public.integration_credentials,
  public.integration_actions, public.integration_mappings,
  public.integration_events, public.integration_tools,
  public.integration_logs from anon;
grant select, insert, update, delete on public.integrations,
  public.integration_credentials, public.integration_actions,
  public.integration_mappings, public.integration_events,
  public.integration_tools to authenticated;
grant select on public.integration_logs to authenticated;
