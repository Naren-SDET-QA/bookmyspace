-- Read-performance only. Do not seed or alter location data.
create extension if not exists pg_trgm;

create index if not exists location_nodes_active_search_trgm_idx
  on public.location_nodes
  using gin (name gin_trgm_ops, normalized_name gin_trgm_ops)
  where status = 'active' and approved_at is not null;

-- One bounded recursive read for the selected node's ancestors. SECURITY
-- INVOKER preserves the existing location_nodes RLS policy.
create or replace function public.get_location_path(
  p_location_id uuid,
  p_max_depth integer default 32
)
returns table(node jsonb, depth integer)
language sql
stable
security invoker
set search_path = public
as $$
  with recursive chain as (
    select n.id, n.parent_id, to_jsonb(n) as node, 0 as depth
    from public.location_nodes n
    where n.id = p_location_id

    union all

    select parent.id, parent.parent_id, to_jsonb(parent), chain.depth + 1
    from public.location_nodes parent
    join chain on parent.id = chain.parent_id
    where chain.depth < least(greatest(coalesce(p_max_depth, 32), 1), 32)
  )
  select chain.node, chain.depth
  from chain
  order by chain.depth desc;
$$;

grant execute on function public.get_location_path(uuid, integer)
  to anon, authenticated;
