-- Local-only additive contract for server-authoritative AI clarification state.
create table if not exists public.ai_clarification_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_key uuid not null,
  category_id uuid references public.venue_categories(id) on delete restrict,
  category_slug text not null,
  tenant_id uuid,
  state text not null default 'NEW' check (state in ('NEW','WAITING_FOR_FIELD','WAITING_FOR_CLARIFICATION','READY','EXPIRED','CANCELLED')),
  answers jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, session_key)
);

create index if not exists ai_clarification_user_expiry_idx
  on public.ai_clarification_sessions(user_id, expires_at desc);
create index if not exists ai_clarification_category_idx
  on public.ai_clarification_sessions(category_id, state);

alter table public.ai_clarification_sessions enable row level security;

drop policy if exists ai_clarification_owner_read on public.ai_clarification_sessions;
create policy ai_clarification_owner_read on public.ai_clarification_sessions
  for select to authenticated using (user_id = auth.uid());

drop policy if exists ai_clarification_owner_insert on public.ai_clarification_sessions;
create policy ai_clarification_owner_insert on public.ai_clarification_sessions
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists ai_clarification_owner_update on public.ai_clarification_sessions;
create policy ai_clarification_owner_update on public.ai_clarification_sessions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.ai_clarification_sessions from anon;
grant select, insert, update on public.ai_clarification_sessions to authenticated;
