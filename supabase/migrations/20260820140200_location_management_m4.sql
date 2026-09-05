-- Location Master M4 management metadata. Additive and unrelated to booking.
alter table public.location_suggestions
  add column if not exists rejection_reason text;

create index if not exists location_nodes_status_name_idx
  on public.location_nodes(status, normalized_name);

create index if not exists location_history_location_created_idx
  on public.location_change_history(location_id, created_at desc);

-- Keep the venue association queryable without changing existing venue fields.
create index if not exists venues_location_node_all_idx
  on public.venues(location_node_id);
