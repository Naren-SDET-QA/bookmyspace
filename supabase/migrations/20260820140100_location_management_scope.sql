-- Location management scope.
-- Owners may submit and maintain their own pending nodes only. They cannot
-- approve, activate, merge or edit the approved global master.

drop policy if exists location_nodes_owner_pending_insert on public.location_nodes;
create policy location_nodes_owner_pending_insert on public.location_nodes
for insert to authenticated
with check (
  created_by = auth.uid()
  and status = 'pending'
  and approved_at is null
  and merged_into_id is null
  and (
    parent_id is null
    or exists (
      select 1 from public.location_nodes parent
      where parent.id = location_nodes.parent_id
        and parent.status = 'active'
        and parent.approved_at is not null
    )
  )
);

drop policy if exists location_nodes_owner_pending_update on public.location_nodes;
drop policy if exists location_nodes_owner_pending_read on public.location_nodes;
create policy location_nodes_owner_pending_read on public.location_nodes
for select to authenticated
using (created_by = auth.uid() and status = 'pending');

create policy location_nodes_owner_pending_update on public.location_nodes
for update to authenticated
using (created_by = auth.uid() and status = 'pending' and approved_at is null)
with check (created_by = auth.uid() and status = 'pending' and approved_at is null);

drop policy if exists location_aliases_owner_pending_manage on public.location_aliases;
create policy location_aliases_owner_pending_manage on public.location_aliases
for all to authenticated
using (exists (
  select 1 from public.location_nodes n
  where n.id = location_id
    and n.created_by = auth.uid()
    and n.status = 'pending'
    and n.approved_at is null
))
with check (exists (
  select 1 from public.location_nodes n
  where n.id = location_id
    and n.created_by = auth.uid()
    and n.status = 'pending'
    and n.approved_at is null
));

drop policy if exists location_history_owner_read on public.location_change_history;
create policy location_history_owner_read on public.location_change_history
for select to authenticated
using (exists (
  select 1 from public.location_nodes n
  where n.id = location_id and n.created_by = auth.uid()
));
