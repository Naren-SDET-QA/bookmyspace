-- PG V1 hardening: new listings start draft and owners cannot self-approve.
alter table public.accommodation_properties
  alter column approval_status set default 'draft';

create or replace function public.guard_pg_approval_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.module='pg' and old.module='pg'
     and auth.uid() is not null
     and not public.has_role(auth.uid(),'administrator')
     and not public.has_role(auth.uid(),'super_administrator')
     and current_setting('app.pg_approval_workflow', true) is distinct from 'true'
     and (new.approval_status is distinct from old.approval_status
       or new.approved_at is distinct from old.approved_at
       or new.approved_by is distinct from old.approved_by
       or new.submitted_at is distinct from old.submitted_at) then
    raise exception 'approval workflow required' using errcode='42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_pg_approval_fields on public.accommodation_properties;
create trigger trg_guard_pg_approval_fields
before update on public.accommodation_properties
for each row execute function public.guard_pg_approval_fields();
revoke all on function public.guard_pg_approval_fields() from public,anon,authenticated;
