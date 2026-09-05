-- Local E2E contract support only. These grants are required because venues
-- RLS policies evaluate related tables, and PostgREST still requires SELECT
-- privilege on every table touched by the policy/query.
grant select on public.owner_profiles, public.organizations, public.venues,
  public.time_slots, public.bookings, public.refunds, public.coupons,
  public.invoice_documents, public.booking_check_ins, public.help_articles
  to authenticated;
