-- Removes ONLY the fixed BookMySpace E2E TEST DATA dataset. Do not run automatically.
begin;
delete from public.accommodation_properties where id='e2e00000-0000-4000-8000-000000000001';
delete from public.venues where id in (
  'e2e40000-0000-4000-8000-000000000001','e2e40000-0000-4000-8000-000000000002',
  'e2e40000-0000-4000-8000-000000000003','e2e40000-0000-4000-8000-000000000004'
);
commit;
