-- Generic module/listing registration configuration.
-- This does not replace bookings, payments, invoices, or email_outbox.

create table if not exists public.module_feature_configs (
  id uuid primary key default gen_random_uuid(),
  module_key text not null,
  venue_id uuid references public.venues(id) on delete cascade,
  registration_enabled boolean not null default false,
  custom_fields_enabled boolean not null default false,
  document_upload_enabled boolean not null default false,
  payment_enabled boolean not null default false,
  advance_payment_enabled boolean not null default false,
  deposit_enabled boolean not null default false,
  installment_payment_enabled boolean not null default false,
  invoice_enabled boolean not null default true,
  email_enabled boolean not null default true,
  notifications_enabled boolean not null default true,
  reviews_enabled boolean not null default true,
  owner_response_enabled boolean not null default false,
  ai_assistant_enabled boolean not null default false,
  voice_booking_enabled boolean not null default false,
  registration_fee_minor bigint check (registration_fee_minor is null or registration_fee_minor >= 0),
  advance_amount_minor bigint check (advance_amount_minor is null or advance_amount_minor >= 0),
  deposit_amount_minor bigint check (deposit_amount_minor is null or deposit_amount_minor >= 0),
  currency text not null default 'INR',
  tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  refund_policy jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (module_key, venue_id)
);

alter table public.module_feature_configs add column if not exists module_enabled boolean not null default true;
alter table public.module_feature_configs add column if not exists approval_required boolean not null default false;
alter table public.module_feature_configs add column if not exists location_required boolean not null default false;
alter table public.module_feature_configs add column if not exists availability_required boolean not null default false;

create table if not exists public.module_form_versions (
  id uuid primary key default gen_random_uuid(),
  module_key text not null,
  venue_id uuid references public.venues(id) on delete cascade,
  version integer not null check (version > 0),
  status text not null default 'published' check (status in ('draft','published','retired')),
  fields jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (module_key, venue_id, version)
);

create table if not exists public.module_document_requirements (
  id uuid primary key default gen_random_uuid(),
  module_key text not null,
  venue_id uuid references public.venues(id) on delete cascade,
  document_key text not null,
  label text not null,
  required boolean not null default false,
  enabled boolean not null default true,
  allowed_mime_types text[] not null default '{}',
  max_size_bytes bigint check (max_size_bytes is null or max_size_bytes > 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (module_key, venue_id, document_key)
);

create table if not exists public.module_form_submissions (
  id uuid primary key default gen_random_uuid(),
  module_key text not null,
  venue_id uuid references public.venues(id) on delete restrict,
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  booking_id uuid unique references public.bookings(id) on delete set null,
  form_version_id uuid not null references public.module_form_versions(id) on delete restrict,
  status text not null default 'submitted' check (status in ('draft','submitted','under_review','approved','rejected','payment_pending','payment_verified','confirmed','cancelled')),
  values jsonb not null default '{}'::jsonb,
  rejection_reason text,
  idempotency_key uuid not null unique,
  submitted_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.module_submission_documents (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.module_form_submissions(id) on delete cascade,
  requirement_id uuid not null references public.module_document_requirements(id) on delete restrict,
  storage_path text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  status text not null default 'uploaded' check (status in ('uploaded','verified','rejected','deleted')),
  created_at timestamptz not null default now(), unique (submission_id, requirement_id)
);
alter table public.module_submission_documents add column if not exists user_id uuid references auth.users(id) on delete restrict;

create index if not exists module_feature_lookup_idx on public.module_feature_configs(module_key, venue_id);
create index if not exists module_form_versions_lookup_idx on public.module_form_versions(module_key, venue_id, status, version desc);
create index if not exists module_submissions_customer_idx on public.module_form_submissions(customer_user_id, created_at desc);
create index if not exists module_submissions_venue_idx on public.module_form_submissions(venue_id, status, created_at desc);
create index if not exists module_submission_documents_submission_idx on public.module_submission_documents(submission_id);

alter table public.module_feature_configs enable row level security;
alter table public.module_form_versions enable row level security;
alter table public.module_document_requirements enable row level security;
alter table public.module_form_submissions enable row level security;
alter table public.module_submission_documents enable row level security;
grant select on public.module_feature_configs, public.module_form_versions, public.module_document_requirements to anon, authenticated;
grant select, insert on public.module_form_submissions to authenticated;
grant select, insert on public.module_submission_documents to authenticated;

create or replace function public.is_platform_admin(uid uuid) returns boolean language sql stable security definer set search_path = public as $$
 select public.has_role(uid, 'administrator') or public.has_role(uid, 'super_administrator');
$$;
revoke all on function public.is_platform_admin(uuid) from public, anon;
grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;

create policy module_features_read on public.module_feature_configs for select using (venue_id is null or exists (select 1 from public.venues v where v.id = venue_id and v.is_active));
create policy module_features_owner_admin_write on public.module_feature_configs for all to authenticated
using (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())))
with check (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));

create policy module_forms_published_read on public.module_form_versions for select using (status = 'published');
create policy module_forms_owner_admin_write on public.module_form_versions for all to authenticated
using (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())))
with check (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));

create policy module_docs_read on public.module_document_requirements for select using (enabled = true);
create policy module_docs_owner_admin_write on public.module_document_requirements for all to authenticated
using (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())))
with check (public.is_platform_admin((select auth.uid())) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));

create policy module_submissions_customer_read on public.module_form_submissions for select to authenticated using (customer_user_id = (select auth.uid()));
create policy module_submissions_owner_read on public.module_form_submissions for select to authenticated using (exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));
create policy module_submissions_admin_read on public.module_form_submissions for select to authenticated using (public.is_platform_admin((select auth.uid())));
create policy module_submissions_customer_insert on public.module_form_submissions for insert to authenticated with check (customer_user_id = (select auth.uid()) and status = 'submitted');
create policy module_submissions_admin_update on public.module_form_submissions for update to authenticated using (public.is_platform_admin((select auth.uid()))) with check (public.is_platform_admin((select auth.uid())));

create policy module_submission_docs_customer_read on public.module_submission_documents for select to authenticated using (exists (select 1 from public.module_form_submissions s where s.id=submission_id and s.customer_user_id=(select auth.uid())));
create policy module_submission_docs_customer_insert on public.module_submission_documents for insert to authenticated with check (
  user_id = (select auth.uid()) and exists (select 1 from public.module_form_submissions s where s.id=submission_id and s.customer_user_id=(select auth.uid()))
);
create policy module_submission_docs_customer_update on public.module_submission_documents for update to authenticated
using (exists (select 1 from public.module_form_submissions s where s.id=submission_id and s.customer_user_id=(select auth.uid())))
with check (user_id=(select auth.uid()));
create policy module_submission_docs_owner_read on public.module_submission_documents for select to authenticated using (exists (select 1 from public.module_form_submissions s join public.venues v on v.id=s.venue_id join public.organizations o on o.id=v.org_id where s.id=submission_id and o.owner_user_id=(select auth.uid())));
create policy module_submission_docs_admin_read on public.module_submission_documents for select to authenticated using (public.is_platform_admin((select auth.uid())));

create or replace function public.validate_module_submission_transition(p_from text, p_to text)
returns boolean language sql immutable as $$
select case when p_from = p_to then true else (p_from,p_to) in (
 ('draft','submitted'),('submitted','under_review'),('under_review','approved'),('under_review','rejected'),
 ('approved','payment_pending'),('payment_pending','payment_verified'),('payment_verified','confirmed'),
 ('submitted','cancelled'),('under_review','cancelled'),('approved','cancelled'),('confirmed','cancelled')) end;
$$;
revoke all on function public.validate_module_submission_transition(text,text) from public, anon;
grant execute on function public.validate_module_submission_transition(text,text) to authenticated, service_role;

-- The only customer submission entry point. It derives the customer and
-- lifecycle status from auth/configuration; clients cannot choose either.
create or replace function public.submit_module_registration(
  p_module_key text, p_venue_id uuid, p_booking_id uuid,
  p_form_version_id uuid, p_values jsonb, p_idempotency_key uuid
)
returns table (submission_id uuid, submission_status text, payment_required boolean, approval_required boolean)
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid(); v_config public.module_feature_configs;
  v_form public.module_form_versions; v_field jsonb; v_value jsonb;
  v_status text;
begin
  if v_user is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select * into v_config from public.module_feature_configs
    where module_key = p_module_key and (venue_id = p_venue_id or venue_id is null)
    order by (venue_id is not null) desc limit 1;
  if not found or not v_config.module_enabled or not v_config.registration_enabled then
    raise exception 'registration_disabled' using errcode = '22023';
  end if;
  select * into v_form from public.module_form_versions
    where id = p_form_version_id and module_key = p_module_key and status = 'published'
      and (venue_id = p_venue_id or venue_id is null);
  if not found then raise exception 'form_version_unavailable' using errcode = '22023'; end if;
  if p_values is null then raise exception 'form_values_required' using errcode = '22023'; end if;
  for v_field in select value from jsonb_array_elements(v_form.fields) where (value->>'enabled')::boolean is distinct from false and (value->>'required')::boolean = true loop
    v_value := p_values -> (v_field->>'key');
    if v_value is null or v_value = 'null'::jsonb or btrim(coalesce(v_value #>> '{}','')) = '' then
      raise exception 'required_field_missing:%', v_field->>'key' using errcode = '22023';
    end if;
  end loop;
  if exists (select 1 from public.module_form_submissions where idempotency_key = p_idempotency_key) then
    return query select s.id, s.status, v_config.payment_enabled, v_config.approval_required from public.module_form_submissions s where s.idempotency_key = p_idempotency_key;
    return;
  end if;
  v_status := case when v_config.approval_required then 'submitted' else 'submitted' end;
  insert into public.module_form_submissions(module_key, venue_id, customer_user_id, booking_id, form_version_id, status, values, idempotency_key, submitted_at)
  values (p_module_key, p_venue_id, v_user, p_booking_id, p_form_version_id, v_status, p_values, p_idempotency_key, now())
  returning id into submission_id;
  return query select submission_id, v_status, v_config.payment_enabled, v_config.approval_required;
end;
$$;
revoke all on function public.submit_module_registration(text,uuid,uuid,uuid,jsonb,uuid) from public, anon;
grant execute on function public.submit_module_registration(text,uuid,uuid,uuid,jsonb,uuid) to authenticated, service_role;

insert into storage.buckets (id, name, public) values ('module-documents','module-documents',false) on conflict (id) do update set public=false;
create policy module_documents_customer_insert on storage.objects for insert to authenticated
with check (bucket_id = 'module-documents' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy module_documents_customer_update on storage.objects for update to authenticated
using (bucket_id = 'module-documents' and (storage.foldername(name))[1] = (select auth.uid()::text))
with check (bucket_id = 'module-documents' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy module_documents_customer_read on storage.objects for select to authenticated using (
  bucket_id = 'module-documents' and exists (
    select 1 from public.module_submission_documents d join public.module_form_submissions s on s.id=d.submission_id
    where s.customer_user_id=(select auth.uid()) and d.storage_path=name
  )
);
create policy module_documents_owner_admin_read on storage.objects for select to authenticated using (
  bucket_id = 'module-documents' and (public.is_platform_admin((select auth.uid())) or exists (
    select 1 from public.module_submission_documents d join public.module_form_submissions s on s.id=d.submission_id
    join public.venues v on v.id=s.venue_id join public.organizations o on o.id=v.org_id
    where d.storage_path=name and o.owner_user_id=(select auth.uid())
  ))
);

create or replace function public.review_module_submission(p_submission_id uuid, p_next_status text, p_reason text default null)
returns public.module_form_submissions
language plpgsql security definer set search_path = public
as $$
declare v_old public.module_form_submissions; v_new public.module_form_submissions; v_uid uuid := auth.uid(); v_allowed boolean := false;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_old from public.module_form_submissions where id=p_submission_id for update;
  if not found then raise exception 'submission_not_found' using errcode='P0002'; end if;
  v_allowed := public.is_platform_admin(v_uid) or exists (select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=v_old.venue_id and o.owner_user_id=v_uid);
  if not v_allowed then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.validate_module_submission_transition(v_old.status, p_next_status) then raise exception 'invalid_submission_transition' using errcode='22023'; end if;
  update public.module_form_submissions set status=p_next_status, rejection_reason=case when p_next_status='rejected' then p_reason else rejection_reason end, updated_at=now() where id=p_submission_id returning * into v_new;
  return v_new;
end;
$$;
revoke all on function public.review_module_submission(uuid,text,text) from public, anon;
grant execute on function public.review_module_submission(uuid,text,text) to authenticated, service_role;
