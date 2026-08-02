-- ============================================================
-- BookMySpace — Migration 0008: Scheduled Jobs & Reconciliation
--
-- Runs via pg_cron (Supabase enables it). Every job is idempotent
-- so a re-run is always safe.
--
-- NOTE: pg_cron is a Supabase extension; in a bare Postgres you can
-- substitute the external scheduler (e.g. a cron daemon calling the
-- same functions). The functions themselves are dependency-free.
-- ============================================================

-- pg_cron is only available on Supabase; create it only when present.
do $$
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) and not exists (
    select 1 from pg_extension where extname = 'pg_cron'
  ) then
    create extension pg_cron;
  end if;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then

    -- 1. Expire stale booking holds every minute, freeing slots for others.
    perform cron.schedule(
      'expire-booking-holds',
      '* * * * *',
      'select public.expire_stale_holds();'
    );

    -- 2. Reconcile stale pending payments every 5 minutes.
    perform cron.schedule(
      'reconcile-stale-payments',
      '*/5 * * * *',
      'select public.reconcile_stale_payments(30);'
    );

    -- 3. Mark bookings on past dates as completed (daily at 00:30).
    perform cron.schedule(
      'complete-past-bookings',
      '30 0 * * *',
      $q$
      update public.bookings
      set status = 'completed', updated_at = now()
      where status = 'confirmed' and book_date < current_date;
      $q$
    );

    -- 4. Archive audit logs older than 12 months (daily at 02:00).
    create table if not exists public.audit_logs_archive (like public.audit_logs including all);
    alter table public.audit_logs_archive enable row level security;

    perform cron.schedule(
      'archive-audit-logs',
      '0 2 * * *',
      $q$
      with moved as (
        delete from public.audit_logs
        where created_at < now() - interval '12 months'
        returning *
      )
      insert into public.audit_logs_archive select * from moved;
      $q$
    );

    -- 5. Archive old notifications (daily at 03:00).
    create table if not exists public.notifications_archive (like public.notifications including all);
    alter table public.notifications_archive enable row level security;

    perform cron.schedule(
      'archive-notifications',
      '0 3 * * *',
      $q$
      with moved as (
        delete from public.notifications
        where created_at < now() - interval '6 months'
        returning *
      )
      insert into public.notifications_archive select * from moved;
      $q$
    );

  end if;
end $$;
