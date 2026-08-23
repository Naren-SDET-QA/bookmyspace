-- Bounded PIN/hierarchy lookup indexes. Additive; no geography seed and no
-- changes to existing location RLS policies.

create index if not exists location_nodes_active_level_name_idx
  on public.location_nodes (level, normalized_name)
  where status = 'active' and approved_at is not null;

create index if not exists location_nodes_active_parent_name_idx
  on public.location_nodes (parent_id, normalized_name)
  where status = 'active' and approved_at is not null;
