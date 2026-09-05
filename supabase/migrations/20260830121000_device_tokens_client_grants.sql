-- Client FCM register/refresh/remove hits public.device_tokens under RLS.
-- Table privileges are separate from RLS; without GRANT, PostgREST returns
-- permission denied even when device_tokens_own would allow the row.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select, insert, update, delete on public.device_tokens to authenticated;
  end if;
end $$;
