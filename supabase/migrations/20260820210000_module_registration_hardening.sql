-- Additive hardening for the generic module registration framework.
-- No existing registration/payment/location contract is replaced.

alter table public.module_feature_configs add column if not exists documents_enabled boolean not null default false;
alter table public.module_feature_configs add column if not exists payment_required_before_approval boolean not null default false;
alter table public.module_feature_configs add column if not exists payment_required_before_confirmation boolean not null default false;
alter table public.module_feature_configs add column if not exists payment_refundable boolean not null default true;
alter table public.module_feature_configs add column if not exists map_enabled boolean not null default true;
alter table public.module_feature_configs add column if not exists voice_enabled boolean not null default false;
alter table public.module_feature_configs add column if not exists ai_help_enabled boolean not null default false;
alter table public.module_feature_configs add column if not exists multilingual_enabled boolean not null default true;
alter table public.module_feature_configs add column if not exists review_enabled boolean not null default true;

create or replace function public.register_module_submission_document(
  p_submission_id uuid,
  p_requirement_id uuid,
  p_storage_path text,
  p_mime_type text,
  p_size_bytes bigint
)
returns public.module_submission_documents
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_submission public.module_form_submissions;
  v_requirement public.module_document_requirements;
  v_document public.module_submission_documents;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_submission from public.module_form_submissions
    where id=p_submission_id and customer_user_id=v_uid;
  if not found then raise exception 'submission_not_found' using errcode='42501'; end if;
  select * into v_requirement from public.module_document_requirements
    where id=p_requirement_id and module_key=v_submission.module_key and enabled=true;
  if not found then raise exception 'document_requirement_unavailable' using errcode='22023'; end if;
  if p_storage_path is null or (storage.foldername(p_storage_path))[1] <> v_uid::text then
    raise exception 'invalid_document_path' using errcode='22023';
  end if;
  if p_size_bytes is null or p_size_bytes <= 0 or
     (v_requirement.max_size_bytes is not null and p_size_bytes > v_requirement.max_size_bytes) then
    raise exception 'document_size_invalid' using errcode='22023';
  end if;
  if cardinality(v_requirement.allowed_mime_types) > 0 and
     not (lower(p_mime_type) = any (select lower(x) from unnest(v_requirement.allowed_mime_types) x)) then
    raise exception 'document_type_invalid' using errcode='22023';
  end if;
  insert into public.module_submission_documents(submission_id, requirement_id, user_id, storage_path, mime_type, size_bytes)
    values (p_submission_id, p_requirement_id, v_uid, p_storage_path, lower(p_mime_type), p_size_bytes)
    on conflict (submission_id, requirement_id) do update set
      user_id=excluded.user_id, storage_path=excluded.storage_path,
      mime_type=excluded.mime_type, size_bytes=excluded.size_bytes,
      status='uploaded', created_at=now()
    returning * into v_document;
  return v_document;
end;
$$;
revoke all on function public.register_module_submission_document(uuid,uuid,text,text,bigint) from public, anon;
grant execute on function public.register_module_submission_document(uuid,uuid,text,text,bigint) to authenticated, service_role;
