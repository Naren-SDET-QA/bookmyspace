-- Local additive repair: RLS still scopes event writes to auth.uid() = user_id.
grant insert on public.analytics_events to authenticated;
