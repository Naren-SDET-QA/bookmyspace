create table public.invoice_configs (
  owner_user_id uuid primary key references auth.users(id) on delete cascade,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config)='object'),
  next_number bigint not null default 1 check(next_number>0),
  updated_at timestamptz not null default now()
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id),
  customer_user_id uuid not null references auth.users(id),
  booking_id uuid references public.bookings(id) on delete restrict,
  parent_invoice_id uuid references public.invoices(id) on delete restrict,
  document_type text not null check(document_type in ('receipt','tax_invoice','credit_note')),
  status text not null check(status in ('issued','cancelled','refunded','partially_refunded')),
  sequence_number bigint not null,
  invoice_number text not null,
  currency text not null,
  subtotal numeric(14,2) not null check(subtotal>=0),
  discount numeric(14,2) not null default 0 check(discount>=0),
  tax_total numeric(14,2) not null default 0 check(tax_total>=0),
  fee_total numeric(14,2) not null default 0 check(fee_total>=0),
  total numeric(14,2) not null check(total>=0),
  paid numeric(14,2) not null default 0 check(paid>=0),
  due numeric(14,2) not null default 0,
  refund numeric(14,2) not null default 0 check(refund>=0),
  config_snapshot jsonb not null check(jsonb_typeof(config_snapshot)='object'),
  invoice_snapshot jsonb not null check(jsonb_typeof(invoice_snapshot)='object'),
  issued_at timestamptz not null default now(),
  unique(owner_user_id,sequence_number),
  unique(owner_user_id,invoice_number)
);
create index invoices_booking_idx on public.invoices(booking_id);
create index invoices_customer_idx on public.invoices(customer_user_id,issued_at desc);

alter table public.invoice_configs enable row level security;
alter table public.invoices enable row level security;
create policy invoice_configs_owner_read on public.invoice_configs for select to authenticated
 using(owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
create policy invoices_authorized_read on public.invoices for select to authenticated
 using(owner_user_id=(select auth.uid()) or customer_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
grant select on public.invoice_configs,public.invoices to authenticated;
revoke insert,update,delete on public.invoice_configs,public.invoices from anon,authenticated;

create or replace function public.save_invoice_config(p_config jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.owner_profiles where user_id=v_uid) and not public.has_role(v_uid,'administrator') then raise exception 'owner or admin required' using errcode='42501';end if;
 if jsonb_typeof(p_config)<>'object' then raise exception 'invalid config' using errcode='22023';end if;
 insert into public.invoice_configs(owner_user_id,config) values(v_uid,p_config)
 on conflict(owner_user_id) do update set config=excluded.config,updated_at=now();
end$$;
revoke all on function public.save_invoice_config(jsonb) from public,anon;
grant execute on function public.save_invoice_config(jsonb) to authenticated;

create or replace function public.issue_invoice(p_booking_id uuid,p_document_type text,p_invoice jsonb,p_parent_invoice_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid();v_owner uuid;v_customer uuid;v_config jsonb;v_seq bigint;v_prefix text;v_number text;v_id uuid;v_booking_status text;
 v_subtotal numeric;v_discount numeric;v_tax numeric;v_fee numeric;v_total numeric;v_paid numeric;v_due numeric;v_refund numeric;v_currency text;v_payment_ref text;v_payment_method text;v_payment_status text;v_status text;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_document_type not in('receipt','tax_invoice','credit_note') then raise exception 'invalid document type' using errcode='22023';end if;
 select o.owner_user_id,b.user_id,b.workflow_status into v_owner,v_customer,v_booking_status from public.bookings b join public.venues v on v.id=b.venue_id join public.organizations o on o.id=v.org_id where b.id=p_booking_id;
 if not found then raise exception 'booking not found';end if;
 if v_uid<>v_owner and not public.has_role(v_uid,'administrator') then raise exception 'not permitted' using errcode='42501';end if;
 if p_document_type='credit_note' and not exists(select 1 from public.invoices where id=p_parent_invoice_id and booking_id=p_booking_id and owner_user_id=v_owner) then raise exception 'valid parent invoice required' using errcode='22023';end if;
 insert into public.invoice_configs(owner_user_id,config) values(v_owner,'{}') on conflict do nothing;
 update public.invoice_configs set next_number=next_number+1 where owner_user_id=v_owner returning config,next_number-1 into v_config,v_seq;
 v_prefix:=coalesce(nullif(v_config->>'invoice_prefix',''),case when p_document_type='credit_note' then 'CN' else 'INV' end);
 v_number:=v_prefix||'-'||lpad(v_seq::text,6,'0');
 v_subtotal:=coalesce((p_invoice->>'subtotal')::numeric,0);v_discount:=coalesce((p_invoice->>'discount')::numeric,0);
 v_tax:=coalesce((p_invoice->>'tax_total')::numeric,0);v_fee:=coalesce((p_invoice->>'fee_total')::numeric,0);
 v_total:=v_subtotal-v_discount+v_tax+v_fee;v_currency:=coalesce(nullif(p_invoice->>'currency',''),'INR');
 select coalesce(p.amount,0),coalesce(p.provider_payment_id,''),coalesce(p.method,''),coalesce(p.status::text,'unpaid') into v_paid,v_payment_ref,v_payment_method,v_payment_status from public.payments p where p.booking_id=p_booking_id and p.status in('captured','refunded','partially_refunded') order by p.updated_at desc limit 1;
 if not found then v_paid:=case when v_total=0 then 0 else 0 end;v_payment_ref:='';v_payment_method:='';v_payment_status:=case when v_total=0 then 'free' else 'unpaid' end;end if;
 select coalesce(sum(r.amount),0) into v_refund from public.refunds r where r.booking_id=p_booking_id and r.status='processed';
 v_due:=greatest(v_total-v_paid,0);v_status:=case when p_document_type='credit_note' or v_refund>=v_paid and v_refund>0 then 'refunded' when v_refund>0 then 'partially_refunded' when v_booking_status='cancelled' then 'cancelled' else 'issued' end;
 if least(v_subtotal,v_discount,v_tax,v_fee,v_total,v_paid,v_refund)<0 then raise exception 'amounts cannot be negative' using errcode='22023';end if;
 if jsonb_typeof(coalesce(p_invoice->'line_items','[]'))<>'array' then raise exception 'line_items must be an array' using errcode='22023';end if;
 insert into public.invoices(owner_user_id,customer_user_id,booking_id,parent_invoice_id,document_type,status,sequence_number,invoice_number,currency,subtotal,discount,tax_total,fee_total,total,paid,due,refund,config_snapshot,invoice_snapshot)
 values(v_owner,v_customer,p_booking_id,p_parent_invoice_id,p_document_type,v_status,v_seq,v_number,v_currency,v_subtotal,v_discount,v_tax,v_fee,v_total,v_paid,v_due,v_refund,v_config,p_invoice||jsonb_build_object('booking_id',p_booking_id,'invoice_number',v_number,'payment_ref',v_payment_ref,'payment_method',v_payment_method,'payment_status',v_payment_status)) returning id into v_id;
 return v_id;
end$$;
revoke all on function public.issue_invoice(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.issue_invoice(uuid,text,jsonb,uuid) to authenticated;

create or replace function public.invoice_immutable() returns trigger language plpgsql as $$begin raise exception 'issued invoices are immutable' using errcode='42501';end$$;
create trigger invoices_immutable before update or delete on public.invoices for each row execute function public.invoice_immutable();
