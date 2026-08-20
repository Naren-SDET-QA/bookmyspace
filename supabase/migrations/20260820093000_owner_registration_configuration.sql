-- Configurable owner registration fields and private owner values.
-- Sensitive values never live on public venues or public listing payloads.

create table if not exists public.owner_registration_field_configs (
  id uuid primary key default gen_random_uuid(),
  field_key text not null unique,
  display_label text not null,
  field_type text not null check (field_type in ('text','number','phone','email','date','dropdown','multiselect','address','document_upload','image_upload','boolean')),
  enabled boolean not null default true,
  required boolean not null default false,
  owner_visible boolean not null default true,
  customer_visible boolean not null default false,
  admin_only boolean not null default false,
  validation_rules jsonb not null default '{}'::jsonb,
  help_text text,
  placeholder text,
  sensitive boolean not null default false,
  access_policy text not null default 'owner_only'
    check (access_policy in ('public','authenticated','premium','paid','after_booking','after_enquiry','owner_only','admin_only')),
  pricing_feature_key text,
  monetization_type text
    check (monetization_type is null or monetization_type in ('one_time','pay_per_view','subscription','per_lead')),
  display_order integer not null default 0,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (not (sensitive and customer_visible)),
  check (not (admin_only and owner_visible)),
  check (access_policy not in ('paid','premium') or pricing_feature_key is not null)
);

create index if not exists owner_registration_fields_order_idx
  on public.owner_registration_field_configs(enabled, display_order);

create table if not exists public.owner_registration_values (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  field_key text not null references public.owner_registration_field_configs(field_key),
  value_text text,
  value_json jsonb,
  storage_path text,
  sensitive boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, field_key)
);

create index if not exists owner_registration_values_owner_idx
  on public.owner_registration_values(owner_user_id);

alter table public.owner_registration_field_configs enable row level security;
alter table public.owner_registration_values enable row level security;

drop policy if exists owner_registration_fields_owner_read on public.owner_registration_field_configs;
create policy owner_registration_fields_owner_read on public.owner_registration_field_configs
for select to authenticated
using (enabled = true and owner_visible = true);

drop policy if exists owner_registration_fields_admin_manage on public.owner_registration_field_configs;
create policy owner_registration_fields_admin_manage on public.owner_registration_field_configs
for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists owner_registration_values_owner_manage on public.owner_registration_values;
create policy owner_registration_values_owner_manage on public.owner_registration_values
for all to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists owner_registration_values_admin_read on public.owner_registration_values;
create policy owner_registration_values_admin_read on public.owner_registration_values
for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

insert into public.owner_registration_field_configs
  (field_key, display_label, field_type, required, display_order, sensitive, help_text, placeholder)
values
  ('owner_name', 'Owner name', 'text', true, 10, false, null, 'Your full name'),
  ('business_name', 'Business / organization name', 'text', true, 20, false, null, 'Registered business name'),
  ('phone', 'Phone', 'phone', true, 30, false, null, '+country code and number'),
  ('email', 'Email', 'email', true, 40, false, null, 'Business email'),
  ('address', 'Address', 'address', true, 50, false, null, 'Business address'),
  ('postal_code', 'PIN / postal code', 'text', false, 60, false, null, 'Postal code'),
  ('pan', 'PAN', 'text', false, 70, true, 'Visible only to authorized administrators', 'PAN number'),
  ('aadhaar', 'Aadhaar', 'text', false, 80, true, 'Store only when required and never expose publicly', 'Aadhaar number'),
  ('gst', 'GST', 'text', false, 90, false, null, 'GST registration number'),
  ('website', 'Website', 'text', false, 100, false, null, 'https://'),
  ('description', 'Description', 'text', false, 110, false, null, 'Business description')
on conflict (field_key) do nothing;
