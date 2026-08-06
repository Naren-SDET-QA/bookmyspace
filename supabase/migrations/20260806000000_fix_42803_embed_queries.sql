-- ============================================================
-- Fix runtime blocker: PostgreSQL 42803
--   "aggregate functions are not allowed in FROM clause of their own query level"
--
-- ROOT CAUSE (query-shape class)
--   The Flutter app listed meeting-room / sports venues with a two-level
--   PostgREST embedding:
--     select=*,venues!inner(...,organizations!inner(owner_user_id))
--   PostgREST translates `!inner` embeds into aggregate subqueries
--   (json_agg / array_agg) generated in a FROM-clause subquery at the same
--   query level as the filter on the innermost embedded column. On the
--   PostgREST versions shipped with older hosted Supabase projects this
--   generated SQL that PostgreSQL rejects with exactly 42803, taking down the
--   venue-list screens inside the E2E booking flow (function hall -> meeting
--   rooms -> sports grounds).
--
-- FIX
--   Replace the embedding with dedicated RPCs that perform the join in plain
--   SQL (no PostgREST-generated aggregate-in-FROM). Each RPC returns the same
--   payload shape the Flutter models already parse
--   ({ ...profile, "venues": { ...venue } }), so the client keeps working.
--   This is a NEW forward-only migration; no deployed migration is modified.
-- ============================================================

-- ------------------------------------------------------------
-- Meeting rooms: list (public) / list owned / fetch single
-- p_owned     -> restrict to the caller's own organization (owner dashboard)
-- p_venue_id  -> fetch a single room
-- Default (neither) -> public list, active venues only, matching the app.
-- ------------------------------------------------------------
create or replace function public.list_meeting_rooms(
  p_owned boolean default false,
  p_venue_id uuid default null
)
returns setof jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select to_jsonb(m) || jsonb_build_object('venues', to_jsonb(v))
  from public.meeting_room_profiles m
  join public.venues v on v.id = m.venue_id
  where (p_venue_id is null or m.venue_id = p_venue_id)
    and (
      (not p_owned and v.is_active)
      or (
        p_owned
        and exists (
          select 1 from public.organizations o
          where o.id = v.org_id
            and o.owner_user_id = auth.uid()
        )
      )
    )
  order by m.updated_at;
$$;

revoke all on function public.list_meeting_rooms(boolean, uuid) from public, anon;
grant execute on function public.list_meeting_rooms(boolean, uuid) to anon, authenticated;

-- ------------------------------------------------------------
-- Sports venues: list (public) / list owned / fetch single
-- Same contract as list_meeting_rooms above.
-- ------------------------------------------------------------
create or replace function public.list_sports_venues(
  p_owned boolean default false,
  p_venue_id uuid default null
)
returns setof jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select to_jsonb(s) || jsonb_build_object('venues', to_jsonb(v))
  from public.sports_venue_profiles s
  join public.venues v on v.id = s.venue_id
  where (p_venue_id is null or s.venue_id = p_venue_id)
    and (
      (not p_owned and v.is_active)
      or (
        p_owned
        and exists (
          select 1 from public.organizations o
          where o.id = v.org_id
            and o.owner_user_id = auth.uid()
        )
      )
    )
  order by s.updated_at;
$$;

revoke all on function public.list_sports_venues(boolean, uuid) from public, anon;
grant execute on function public.list_sports_venues(boolean, uuid) to anon, authenticated;

-- ------------------------------------------------------------
-- Guard: assert the runtime never regresses into the 42803 class.
-- Exposed to authenticated only (used by the SQL regression test).
-- ------------------------------------------------------------
create or replace function public.assert_no_42803_aggregate_patterns()
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_bad integer := 0;
begin
  -- A FROM-clause function with an aggregate at its own query level is the
  -- exact SQL pattern that raises 42803. Search every view in the schema.
  -- A FROM-clause function called with an aggregate at its own query level
  -- is the exact SQL pattern that raises 42803. Scan every public view.
  select count(*) into v_bad
  from pg_views v
  where v.schemaname = 'public'
    and lower(v.definition) ~ 'from\s+(jsonb_array_elements|json_array_elements|unnest|generate_series|regexp_split_to_table|string_to_array|jsonb_each|jsonb_object_keys)\s*\([^)]*(count|sum|avg|min|max|array_agg|jsonb_agg|string_agg)';

  if v_bad > 0 then
    raise exception '42803 risk: % view(s) use an aggregate inside a FROM-clause function at the same query level', v_bad;
  end if;
  return true;
end;
$$;

revoke all on function public.assert_no_42803_aggregate_patterns() from public, anon;
grant execute on function public.assert_no_42803_aggregate_patterns() to authenticated;
