-- Read-only contract checks for the local generic resource foundation.
select to_regclass('public.bookable_resources') as resources_table;
select column_name from information_schema.columns
where table_schema = 'public' and table_name in ('bookings','booking_holds')
  and column_name in ('resource_id','resource_start_at','resource_end_at');
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'refunds'
  and column_name in ('idempotency_key','policy_snapshot','refund_amount','provider_status');
select to_regclass('public.inventory_restorations') as restoration_table;
