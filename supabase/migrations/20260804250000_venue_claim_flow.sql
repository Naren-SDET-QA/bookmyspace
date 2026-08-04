-- ============================================================
-- Phase 5: Claim This Venue hardening
-- Evidence validation, single pending claim, owner_verified,
-- audit trail. No Auth user mutations.
-- ============================================================

create unique index if not exists idx_venue_claims_one_pending
  on public.venue_claims(venue_id)
  where status = 'pending';

create or replace function public.write_venue_claim_audit(
  p_action text,
  p_claim_id uuid,
  p_venue_id uuid,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(),
    p_action,
    'venue_claim',
    p_claim_id,
    coalesce(p_details, '{}'::jsonb) || jsonb_build_object('venue_id', p_venue_id)
  );
exception
  when others then
    if sqlstate = '42501' then raise; end if;
end;
$$;

revoke all on function public.write_venue_claim_audit(text, uuid, uuid, jsonb) from public, anon;
grant execute on function public.write_venue_claim_audit(text, uuid, uuid, jsonb) to authenticated, service_role;

create or replace function public.submit_venue_claim(
  p_venue_id uuid,
  p_evidence jsonb default '{}'::jsonb
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.venue_claims;
  v_claimable boolean;
  v_owner_verified boolean;
  v_evidence jsonb := coalesce(p_evidence, '{}'::jsonb);
  v_business text := trim(coalesce(v_evidence->>'business_name', ''));
  v_phone text := trim(coalesce(v_evidence->>'contact_phone', ''));
  v_pending uuid;
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;

  select is_claimable, coalesce(owner_verified, false)
    into v_claimable, v_owner_verified
  from public.venues
  where id = p_venue_id and deleted_at is null and is_active;

  if not found then raise exception 'venue_not_found'; end if;
  if v_owner_verified then raise exception 'venue_already_owner_verified'; end if;
  if not coalesce(v_claimable, false) then raise exception 'venue_not_claimable'; end if;

  if length(v_business) < 3 then
    raise exception 'claim_evidence_business_name_required';
  end if;
  if length(regexp_replace(v_phone, '\D', '', 'g')) < 10 then
    raise exception 'claim_evidence_contact_phone_required';
  end if;

  select id into v_pending
  from public.venue_claims
  where venue_id = p_venue_id and status = 'pending'
    and claimant_user_id <> auth.uid()
  limit 1;
  if v_pending is not null then
    raise exception 'claim_already_pending';
  end if;

  insert into public.venue_claims (venue_id, claimant_user_id, evidence, status)
  values (p_venue_id, auth.uid(), v_evidence, 'pending')
  on conflict (venue_id, claimant_user_id) do update
    set evidence = excluded.evidence,
        status = case
          when public.venue_claims.status = 'approved' then public.venue_claims.status
          else 'pending'
        end,
        updated_at = now(),
        reviewed_by = null,
        reviewed_at = null,
        review_notes = null
  where public.venue_claims.status <> 'approved'
  returning * into v_claim;

  if v_claim is null then
    raise exception 'claim_already_approved';
  end if;

  perform public.write_venue_claim_audit(
    'venue_claim_submitted',
    v_claim.id,
    p_venue_id,
    jsonb_build_object('business_name', v_business)
  );

  return v_claim;
end;
$$;

create or replace function public.admin_review_venue_claim(
  p_claim_id uuid,
  p_approve boolean,
  p_notes text default null
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.venue_claims;
  v_org uuid;
begin
  if not public.is_admin_user() then raise exception 'admin_required'; end if;

  select * into v_claim from public.venue_claims where id = p_claim_id and status = 'pending';
  if v_claim is null then raise exception 'claim_not_found'; end if;

  if p_approve then
    select id into v_org from public.organizations
    where owner_user_id = v_claim.claimant_user_id and deleted_at is null
    order by created_at limit 1;

    if v_org is null then
      insert into public.organizations (owner_user_id, org_type, name, country)
      values (v_claim.claimant_user_id, 'venue_owner',
              'Claimed Venue Organization', 'IN')
      returning id into v_org;
    end if;

    update public.venues
    set org_id = v_org,
        is_claimable = false,
        is_verified = true,
        owner_verified = true,
        owner_verified_fields = '["name","category_id","address_line1","city","state","postal_code","latitude","longitude","phone","website","description","capacity","pricing_base_amount"]'::jsonb,
        updated_at = now()
    where id = v_claim.venue_id;

    insert into public.user_roles (user_id, role, granted_by)
    values (v_claim.claimant_user_id, 'venue_owner', auth.uid())
    on conflict (user_id, role) do update set revoked_at = null;

    update public.venue_claims
    set status = 'rejected',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        review_notes = coalesce(p_notes, '') || ' [auto_rejected:another_claim_approved]',
        updated_at = now()
    where venue_id = v_claim.venue_id
      and id <> p_claim_id
      and status = 'pending';
  end if;

  update public.venue_claims
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_notes = p_notes,
      updated_at = now()
  where id = p_claim_id
  returning * into v_claim;

  perform public.write_venue_claim_audit(
    case when p_approve then 'venue_claim_approved' else 'venue_claim_rejected' end,
    v_claim.id,
    v_claim.venue_id,
    jsonb_build_object('notes', p_notes, 'approve', p_approve)
  );

  return v_claim;
end;
$$;

create or replace function public.admin_list_pending_venue_claims()
returns setof public.venue_claims
language sql
security definer
set search_path = public, pg_temp
as $$
  select c.*
  from public.venue_claims c
  where public.is_admin_user()
    and c.status = 'pending'
  order by c.created_at asc;
$$;

revoke all on function public.admin_list_pending_venue_claims() from public, anon;
grant execute on function public.admin_list_pending_venue_claims() to authenticated;

drop policy if exists venue_claims_select on public.venue_claims;
create policy venue_claims_select on public.venue_claims
  for select using (
    claimant_user_id = (select auth.uid())
    or public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );

drop policy if exists venue_claims_insert on public.venue_claims;
create policy venue_claims_insert on public.venue_claims
  for insert with check (claimant_user_id = (select auth.uid()));

drop policy if exists venue_claims_admin_update on public.venue_claims;
create policy venue_claims_admin_update on public.venue_claims
  for update using (
    public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  )
  with check (
    public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );
