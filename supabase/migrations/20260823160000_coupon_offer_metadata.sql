-- Additive offer targeting metadata on existing coupons.
-- Does not change coupon RLS or payment/booking backends.

alter table public.coupons
  add column if not exists metadata jsonb not null default '{}'::jsonb;

comment on column public.coupons.metadata is
  'Optional offer title and category/listing targeting. Payment application is unchanged.';
