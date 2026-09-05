-- DEV-only cleanup for supabase/seed_missing_category_samples_dev.sql.
-- Read-only refusal unless explicitly run with psql -v bms_cleanup=1.
begin;
do $$
declare
  enabled boolean := coalesce(current_setting('bms_cleanup', true), '0') = '1';
  removed integer;
begin
  if not enabled then
    raise exception 'REFUSED: cleanup requires explicit -v bms_cleanup=1';
  end if;
  delete from public.venue_facilities
   where venue_id in (select id from public.venues where slug like 'bms-dev-missing-%');
  delete from public.venue_operating_hours
   where venue_id in (select id from public.venues where slug like 'bms-dev-missing-%');
  delete from public.time_slots
   where venue_id in (select id from public.venues where slug like 'bms-dev-missing-%');
  delete from public.venue_images
   where venue_id in (select id from public.venues where slug like 'bms-dev-missing-%');
  delete from public.venues where slug like 'bms-dev-missing-%';
  get diagnostics removed = row_count;
  raise notice 'REMOVED DEV SAMPLE VENUES: %', removed;
end $$;
commit;
