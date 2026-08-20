-- Server-generated invoice artifacts.  The table is intentionally separate
-- from payments: one booking has one authoritative invoice artifact.
create table if not exists public.invoice_documents (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  booking_id uuid not null unique references public.bookings(id) on delete restrict,
  payment_id uuid references public.payments(id) on delete set null,
  storage_path text unique,
  status text not null default 'pending' check (status in ('pending','generated','failed')),
  generated_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoice_documents_payment_idx
  on public.invoice_documents(payment_id);

alter table public.email_outbox
  drop constraint if exists email_outbox_invoice_id_fkey;
alter table public.email_outbox
  add constraint email_outbox_invoice_id_fkey
  foreign key (invoice_id) references public.invoice_documents(id) on delete set null;

insert into storage.buckets (id, name, public)
values ('invoices', 'invoices', false)
on conflict (id) do update set public = false;

alter table public.invoice_documents enable row level security;
revoke all on public.invoice_documents from anon;
grant select on public.invoice_documents to authenticated;

create policy invoice_documents_customer_read on public.invoice_documents
for select to authenticated using (
  exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = (select auth.uid()))
);

create policy invoice_documents_owner_read on public.invoice_documents
for select to authenticated using (
  exists (
    select 1 from public.bookings b
    join public.venues v on v.id = b.venue_id
    join public.organizations o on o.id = v.org_id
    where b.id = booking_id and o.owner_user_id = (select auth.uid())
  )
);

create policy invoice_documents_admin_read on public.invoice_documents
for select to authenticated using (
  public.has_role((select auth.uid()), 'administrator')
  or public.has_role((select auth.uid()), 'super_administrator')
);

create or replace function public.set_invoice_documents_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists invoice_documents_updated_at on public.invoice_documents;
create trigger invoice_documents_updated_at before update on public.invoice_documents
for each row execute function public.set_invoice_documents_updated_at();

-- Invoice PDFs are written/read through the service-role Edge Function only.
revoke all on storage.objects from anon, authenticated;
