


BEGIN;

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';

-- Required by UUID defaults and venue geography. These are additive and do
-- not replace Supabase-managed extension objects.
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "public";
CREATE EXTENSION IF NOT EXISTS "postgis" WITH SCHEMA "public";
CREATE EXTENSION IF NOT EXISTS "btree_gist" WITH SCHEMA "public";



CREATE TYPE "public"."booking_status" AS ENUM (
    'held',
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'refunded',
    'no_show'
);


ALTER TYPE "public"."booking_status" OWNER TO "postgres";


CREATE TYPE "public"."course_mode" AS ENUM (
    'online',
    'offline',
    'hybrid'
);


ALTER TYPE "public"."course_mode" OWNER TO "postgres";


CREATE TYPE "public"."event_category" AS ENUM (
    'meeting',
    'conference',
    'workshop',
    'sports',
    'entertainment',
    'cultural',
    'exhibition',
    'community'
);


ALTER TYPE "public"."event_category" OWNER TO "postgres";


CREATE TYPE "public"."org_type" AS ENUM (
    'venue_owner',
    'institute_owner',
    'event_organizer'
);


ALTER TYPE "public"."org_type" OWNER TO "postgres";


CREATE TYPE "public"."payment_status" AS ENUM (
    'pending',
    'authorized',
    'captured',
    'failed',
    'refunded',
    'partially_refunded'
);


ALTER TYPE "public"."payment_status" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'customer',
    'venue_owner',
    'institute_owner',
    'event_organizer',
    'support_agent',
    'administrator',
    'super_administrator'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."venue_category" AS ENUM (
    'function_hall',
    'marriage_hall',
    'convention_center',
    'party_hall',
    'meeting_room',
    'community_hall',
    'sports_ground',
    'coworking_space',
    'auditorium'
);


ALTER TYPE "public"."venue_category" OWNER TO "postgres";


CREATE TYPE "public"."verification_status" AS ENUM (
    'pending',
    'submitted',
    'approved',
    'rejected'
);


ALTER TYPE "public"."verification_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."acquire_booking_hold"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_user_id" "uuid", "p_idempotency_key" "uuid", "p_amount" numeric, "p_hold_minutes" integer DEFAULT 10) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_slot_start time;
  v_slot_end time;
  v_hold_id uuid;
  v_expires timestamptz;
  v_lock_key bigint;
begin
  select start_time, end_time into v_slot_start, v_slot_end
  from public.time_slots where id = p_slot_id;
  if not found then
    raise exception 'invalid slot' using errcode = '22023';
  end if;

  -- Existing hold for this idempotency key? Return it (idempotent).
  select id into v_hold_id
  from public.booking_holds
  where idempotency_key = p_idempotency_key;
  if v_hold_id is not null then
    return v_hold_id;
  end if;

  -- Serialize concurrent requests for the same (venue, date).
  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- Double-check overlaps within the transaction (holds + bookings).
  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id
      and h.book_date = p_book_date
      and h.status = 'active'
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id
          and s.start_time < v_slot_end
          and s.end_time > v_slot_start
      )
  ) or exists (
    select 1 from public.bookings b
    where b.venue_id = p_venue_id
      and b.book_date = p_book_date
      and b.status in ('held', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot_end
      and b.end_time > v_slot_start
  ) then
    raise exception 'slot unavailable' using errcode = 'P0001';
  end if;

  v_expires := now() + make_interval(mins => p_hold_minutes);

  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, p_amount, v_expires
  ) returning id into v_hold_id;

  return v_hold_id;
end $$;


ALTER FUNCTION "public"."acquire_booking_hold"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_user_id" "uuid", "p_idempotency_key" "uuid", "p_amount" numeric, "p_hold_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."acquire_booking_hold_for_current_user"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_idempotency_key" "uuid", "p_hold_minutes" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_uid uuid:=auth.uid(); v_price numeric; v_start time; v_settings public.hall_booking_settings%rowtype;
  v_id uuid; v_minutes integer; v_start_at timestamp;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  select s.price_amount,s.start_time into v_price,v_start from public.time_slots s join public.venues v on v.id=s.venue_id
  where s.id=p_slot_id and s.venue_id=p_venue_id and s.is_active and v.is_active and v.deleted_at is null;
  if not found then raise exception 'invalid slot' using errcode='22023'; end if;
  select * into v_settings from public.hall_booking_settings where venue_id=p_venue_id;
  if not found then v_settings.min_notice_minutes:=0; v_settings.max_advance_days:=365; v_settings.checkout_hold_minutes:=10; end if;
  v_start_at:=p_book_date+v_start;
  if p_book_date<current_date or v_start_at<localtimestamp+make_interval(mins=>v_settings.min_notice_minutes)
    or p_book_date>current_date+v_settings.max_advance_days then
    raise exception 'outside booking window' using errcode='P0001';
  end if;
  if exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_book_date)
    or not exists(select 1 from public.venue_operating_hours where venue_id=p_venue_id
      and day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not is_closed) then
    raise exception 'slot unavailable' using errcode='P0001';
  end if;
  v_minutes:=least(greatest(coalesce(v_settings.checkout_hold_minutes,10),2),30);
  v_id:=public.acquire_booking_hold(p_venue_id,p_slot_id,p_book_date,v_uid,p_idempotency_key,v_price,v_minutes);
  return jsonb_build_object('hold_id',v_id,'expires_in_minutes',v_minutes);
end $$;


ALTER FUNCTION "public"."acquire_booking_hold_for_current_user"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_idempotency_key" "uuid", "p_hold_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_commerce_payment"("p_reference_id" "uuid", "p_payment_ref" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare c commerce_references;begin select * into c from commerce_references where id=p_reference_id for update;if not found then raise exception 'commerce reference not found';end if;update commerce_references set payment_status='captured',booking_status='confirmed',updated_at=now()where id=c.id;if c.module='stays'then update stay_bookings set payment_status='captured',status='confirmed',updated_at=now()where id=c.reservation_id and status='payment_pending';else update bookings set workflow_status='paid'where id=c.legacy_booking_id and workflow_status='payment_pending';perform confirm_booking(c.legacy_booking_id,p_payment_ref);end if;end$$;


ALTER FUNCTION "public"."apply_commerce_payment"("p_reference_id" "uuid", "p_payment_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_commerce_refund"("p_reference_id" "uuid", "p_partial" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare c commerce_references;v_status text:=case when p_partial then 'partially_refunded'else 'refunded'end;begin select * into c from commerce_references where id=p_reference_id for update;if not found then raise exception 'commerce reference not found';end if;update commerce_references set payment_status=v_status,refund_status=v_status,booking_status=v_status,updated_at=now()where id=c.id;if c.module='stays'then update stay_bookings set payment_status=v_status,status=v_status,updated_at=now()where id=c.reservation_id;update stay_booking_rooms set active=false where stay_booking_id=c.reservation_id and not p_partial;else update bookings set status=case when p_partial then status else 'refunded'::booking_status end,workflow_status=v_status where id=c.legacy_booking_id;end if;end$$;


ALTER FUNCTION "public"."apply_commerce_refund"("p_reference_id" "uuid", "p_partial" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."attach_registration_file"("p_submission_id" "uuid", "p_field_key" "text", "p_storage_path" "text", "p_original_name" "text", "p_mime_type" "text", "p_size_bytes" bigint) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_id uuid;begin
 if not exists(select 1 from public.registration_submissions where id=p_submission_id and submitted_by=auth.uid())then raise exception 'not permitted' using errcode='42501';end if;
 if split_part(p_storage_path,'/',1)<>auth.uid()::text or split_part(p_storage_path,'/',2)<>p_submission_id::text then raise exception 'invalid storage path' using errcode='42501';end if;
 insert into public.registration_submission_files(submission_id,field_key,storage_path,original_name,mime_type,size_bytes)values(p_submission_id,p_field_key,p_storage_path,p_original_name,p_mime_type,p_size_bytes)returning id into v_id;return v_id;end$$;


ALTER FUNCTION "public"."attach_registration_file"("p_submission_id" "uuid", "p_field_key" "text", "p_storage_path" "text", "p_original_name" "text", "p_mime_type" "text", "p_size_bytes" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."available_stay_units"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer) RETURNS TABLE("unit_id" "uuid", "available" integer, "nightly_rate" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
 select u.id,count(r.id)::integer,coalesce((select sr.nightly_rate from stay_rates sr where sr.unit_id=u.id and sr.start_date<=p_check_in and sr.end_date>=p_check_out-1 order by sr.start_date desc limit 1),u.price_nightly)
 from accommodation_units u join accommodation_properties p on p.id=u.property_id join stay_physical_rooms r on r.unit_id=u.id and r.is_active
 where p.id=p_property_id and p.module='stay' and p.is_active and u.is_active and p_check_out>p_check_in and p_adults>0 and p_children>=0 and u.max_adults>=p_adults and u.max_children>=p_children
 and not exists(select 1 from stay_blocks x where x.physical_room_id=r.id and x.stay_dates&&daterange(p_check_in,p_check_out,'[)'))
 and not exists(select 1 from stay_booking_rooms br where br.physical_room_id=r.id and br.active and br.stay_dates&&daterange(p_check_in,p_check_out,'[)'))
 group by u.id,u.price_nightly;
$$;


ALTER FUNCTION "public"."available_stay_units"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."available_time_slots"("p_venue_id" "uuid", "p_book_date" "date") RETURNS TABLE("slot_id" "uuid", "label" "text", "start_time" time without time zone, "end_time" time without time zone, "price_amount" numeric, "is_available" boolean, "reason" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select s.id,s.label,s.start_time,s.end_time,s.price_amount,
    s.is_active and not exists(select 1 from public.venue_blocked_dates d where d.venue_id=s.venue_id and d.blocked_date=p_book_date)
    and not exists(select 1 from public.venue_slot_blocks x where x.slot_id=s.id and x.blocked_date=p_book_date)
    and exists(select 1 from public.venue_operating_hours h where h.venue_id=s.venue_id
      and h.day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not h.is_closed)
    and not exists(select 1 from public.booking_holds b join public.time_slots hs on hs.id=b.slot_id
      where b.venue_id=s.venue_id and b.book_date=p_book_date and b.status='active' and b.expires_at>now()
      and hs.start_time<s.end_time and hs.end_time>s.start_time)
    and not exists(select 1 from public.bookings b where b.venue_id=s.venue_id and b.book_date=p_book_date
      and b.status in ('held','pending','confirmed','completed') and b.start_time<s.end_time and b.end_time>s.start_time),
    case when not s.is_active then 'inactive'
      when exists(select 1 from public.venue_blocked_dates d where d.venue_id=s.venue_id and d.blocked_date=p_book_date) then 'blocked'
      when exists(select 1 from public.venue_slot_blocks x where x.slot_id=s.id and x.blocked_date=p_book_date) then 'blocked'
      when not exists(select 1 from public.venue_operating_hours h where h.venue_id=s.venue_id
        and h.day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not h.is_closed) then 'closed'
      when exists(select 1 from public.booking_holds b join public.time_slots hs on hs.id=b.slot_id
        where b.venue_id=s.venue_id and b.book_date=p_book_date and b.status='active' and b.expires_at>now()
        and hs.start_time<s.end_time and hs.end_time>s.start_time) then 'held'
      when exists(select 1 from public.bookings b where b.venue_id=s.venue_id and b.book_date=p_book_date
        and b.status in ('held','pending','confirmed','completed') and b.start_time<s.end_time and b.end_time>s.start_time) then 'booked'
      else 'available' end
  from public.time_slots s where s.venue_id=p_venue_id order by s.start_time;
$$;


ALTER FUNCTION "public"."available_time_slots"("p_venue_id" "uuid", "p_book_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."begin_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_claimed boolean;
begin
  insert into public.webhook_events(provider,event_id,event_type,payload,attempts,processing_started_at)
  values(p_provider,p_event_id,p_event_type,p_payload,1,now())
  on conflict(provider,event_id) do update set
    event_type=excluded.event_type, payload=excluded.payload,
    attempts=public.webhook_events.attempts+1,
    processing_started_at=now(), last_error=null
  where public.webhook_events.processed=false
    and (public.webhook_events.processing_started_at is null
      or public.webhook_events.processing_started_at < now()-interval '2 minutes');
  get diagnostics v_claimed = row_count;
  return v_claimed;
end $$;


ALTER FUNCTION "public"."begin_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bind_registration_form"("p_template_id" "uuid", "p_module_key" "text", "p_resource_id" "uuid", "p_collection_stage" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_id uuid;begin
 if not exists(select 1 from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')))then raise exception 'not permitted' using errcode='42501';end if;
 insert into public.registration_form_bindings(module_key,resource_id,template_id,collection_stage,created_by)values(trim(p_module_key),p_resource_id,p_template_id,p_collection_stage,v_uid)
 on conflict(module_key,resource_id,collection_stage)do update set template_id=excluded.template_id,is_active=true returning id into v_id;return v_id;end$$;


ALTER FUNCTION "public"."bind_registration_form"("p_template_id" "uuid", "p_module_key" "text", "p_resource_id" "uuid", "p_collection_stage" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_event_registration"("p_registration_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  update public.event_registrations
  set status = 'cancelled', updated_at = now()
  where id = p_registration_id
    and user_id = p_user_id
    and status = 'registered';
  if not found then
    raise exception 'registration not cancellable' using errcode = 'P0001';
  end if;
end $$;


ALTER FUNCTION "public"."cancel_event_registration"("p_registration_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."notification_deliveries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "notification_id" "uuid" NOT NULL,
    "channel" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "next_attempt_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_error" "text",
    "delivered_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_deliveries_channel_check" CHECK (("channel" = ANY (ARRAY['push'::"text", 'email'::"text", 'sms'::"text", 'whatsapp'::"text"]))),
    CONSTRAINT "notification_deliveries_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'delivered'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."notification_deliveries" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_notification_deliveries"("p_limit" integer DEFAULT 25) RETURNS SETOF "public"."notification_deliveries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  return query with claimed as (
    select id from public.notification_deliveries
    where status in ('pending','failed') and next_attempt_at<=now() and attempts<8
    order by next_attempt_at for update skip locked limit greatest(1,least(p_limit,100))
  ) update public.notification_deliveries d set status='processing',attempts=attempts+1,updated_at=now()
    from claimed where d.id=claimed.id returning d.*;
end $$;


ALTER FUNCTION "public"."claim_notification_deliveries"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commerce_receipt"("p_reference_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select jsonb_build_object('commerce_reference_id',c.id,'booking_id',c.reservation_id,'booking_ref',c.metadata->>'booking_ref','receipt_number',i.invoice_number,'hall_name',c.metadata->>'resource_name','customer_name',coalesce(p.full_name,p.email,'Customer'),'customer_phone',coalesce(p.phone,''),'book_date',coalesce(c.metadata->>'book_date',c.metadata->>'check_in'),'start_time',coalesce(c.metadata->>'start_time',c.metadata->>'check_in'),'end_time',coalesce(c.metadata->>'end_time',c.metadata->>'check_out'),'amount',c.amount,'tax_amount',coalesce(i.tax_total,0),'total_amount',c.amount,'currency',c.currency,'booking_status',c.booking_status,'payment_status',c.payment_status,'payment_ref',coalesce(pay.provider_payment_id,''))from commerce_references c left join profiles p on p.id=c.customer_user_id left join lateral(select * from invoices x where x.commerce_reference_id=c.id order by issued_at desc limit 1)i on true left join lateral(select * from payments x where x.commerce_reference_id=c.id order by created_at desc limit 1)pay on true where c.id=p_reference_id and(c.customer_user_id=auth.uid()or c.owner_user_id=auth.uid()or public.has_role(auth.uid(),'administrator'))$$;


ALTER FUNCTION "public"."commerce_receipt"("p_reference_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commerce_reference_for_booking"("p_booking_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select id from commerce_references where legacy_booking_id=p_booking_id and(customer_user_id=auth.uid()or owner_user_id=auth.uid()or public.has_role(auth.uid(),'administrator'))$$;


ALTER FUNCTION "public"."commerce_reference_for_booking"("p_booking_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commerce_reference_for_reservation"("p_module" "text", "p_reservation_id" "uuid") RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select id from commerce_references where module=p_module and reservation_id=p_reservation_id and(customer_user_id=auth.uid()or owner_user_id=auth.uid()or public.has_role(auth.uid(),'administrator'))$$;


ALTER FUNCTION "public"."commerce_reference_for_reservation"("p_module" "text", "p_reservation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commerce_status"("p_reference_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select booking_status from commerce_references where id=p_reference_id and(customer_user_id=auth.uid()or owner_user_id=auth.uid()or public.has_role(auth.uid(),'administrator'))$$;


ALTER FUNCTION "public"."commerce_status"("p_reference_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."commerce_status_for_booking"("p_booking_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select booking_status from commerce_references where legacy_booking_id=p_booking_id and(customer_user_id=auth.uid()or owner_user_id=auth.uid()or public.has_role(auth.uid(),'administrator'))$$;


ALTER FUNCTION "public"."commerce_status_for_booking"("p_booking_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_notification_delivery"("p_delivery_id" "uuid", "p_success" boolean, "p_error" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  update public.notification_deliveries set
    status=case when p_success then 'delivered' else 'failed' end,
    delivered_at=case when p_success then now() else null end,
    last_error=case when p_success then null else left(coalesce(p_error,'delivery failed'),500) end,
    next_attempt_at=case when p_success then next_attempt_at else now()+make_interval(secs=>least(3600,power(2,attempts)::integer*30)) end,
    updated_at=now() where id=p_delivery_id and status='processing';
end $$;


ALTER FUNCTION "public"."complete_notification_delivery"("p_delivery_id" "uuid", "p_success" boolean, "p_error" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_webhook_event"("p_provider" "text", "p_event_id" "text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  update public.webhook_events set processed=true,processed_at=now(),processing_started_at=null,last_error=null
  where provider=p_provider and event_id=p_event_id;
$$;


ALTER FUNCTION "public"."complete_webhook_event"("p_provider" "text", "p_event_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_booking"("p_booking_id" "uuid", "p_payment_ref" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  update public.bookings set status='confirmed',workflow_status='confirmed',confirmed_at=coalesce(confirmed_at,now()),
    receipt_number=coalesce(receipt_number,'BMS-R-'||upper(substr(replace(id::text,'-',''),1,12))),
    metadata=coalesce(metadata,'{}')||jsonb_build_object('payment_ref',p_payment_ref)
  where id=p_booking_id and status='pending' and workflow_status in ('payment_pending','paid');
end $$;


ALTER FUNCTION "public"."confirm_booking"("p_booking_id" "uuid", "p_payment_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_booking_from_hold"("p_hold_id" "uuid", "p_user_id" "uuid", "p_booking_ref" "text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_hold public.booking_holds%rowtype;
  v_slot public.time_slots%rowtype;
  v_tax_rate numeric;
  v_tax numeric;
  v_total numeric;
  v_booking_id uuid;
  v_status public.booking_status;
begin
  select * into v_hold
  from public.booking_holds
  where id = p_hold_id
  for update;

  if not found or v_hold.user_id <> p_user_id then
    raise exception 'invalid hold' using errcode = '22023';
  end if;
  if v_hold.status <> 'active' or v_hold.expires_at <= now() then
    raise exception 'hold expired' using errcode = 'P0001';
  end if;

  select * into v_slot
  from public.time_slots
  where id = v_hold.slot_id
    and venue_id = v_hold.venue_id
    and is_active;

  if not found or v_slot.price_amount <> v_hold.price_amount then
    raise exception 'invalid slot price' using errcode = '22023';
  end if;

  select tax_rate into v_tax_rate
  from public.venues
  where id = v_hold.venue_id and is_active and deleted_at is null;

  if not found then
    raise exception 'venue unavailable' using errcode = '22023';
  end if;

  v_tax := round(v_slot.price_amount * v_tax_rate / 100, 2);
  v_total := v_slot.price_amount + v_tax;
  v_status := case when v_total = 0 then 'confirmed'::public.booking_status
                   else 'pending'::public.booking_status end;

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date,
    start_time, end_time, hold_id, status, quantity,
    amount, tax_amount, total_amount, currency, confirmed_at
  ) values (
    p_booking_ref, p_user_id, v_hold.venue_id, v_slot.id, v_hold.book_date,
    v_slot.start_time, v_slot.end_time, v_hold.id, v_status, 1,
    v_slot.price_amount, v_tax, v_total, 'INR',
    case when v_status = 'confirmed' then now() else null end
  ) returning id into v_booking_id;

  update public.booking_holds set status = 'confirmed' where id = v_hold.id;
  return v_booking_id;
end;
$$;


ALTER FUNCTION "public"."create_booking_from_hold"("p_hold_id" "uuid", "p_user_id" "uuid", "p_booking_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_booking_from_hold_for_current_user"("p_hold_id" "uuid", "p_booking_ref" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_uid uuid:=auth.uid(); v_id uuid; v_mode text; v_window integer; v_timeout integer;
  v_total numeric; v_start timestamp; v_flow text;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  v_id:=public.create_booking_from_hold(p_hold_id,v_uid,p_booking_ref);
  select coalesce(s.booking_mode,'instant'),coalesce(s.instant_book_window_hours,48),
    coalesce(s.approval_timeout_minutes,1440),b.total_amount,b.book_date+b.start_time
    into v_mode,v_window,v_timeout,v_total,v_start from public.bookings b
    left join public.hall_booking_settings s on s.venue_id=b.venue_id where b.id=v_id;
  if v_total=0 and (v_mode='instant' or (v_mode='hybrid' and v_start<=localtimestamp+make_interval(hours=>v_window))) then
    v_flow:='confirmed';
  elsif v_mode='approval' or (v_mode='hybrid' and v_start>localtimestamp+make_interval(hours=>v_window)) then
    v_flow:='requested';
  else v_flow:='payment_pending'; end if;
  update public.bookings set workflow_status=v_flow,
    status=case when v_flow='confirmed' then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when v_flow='confirmed' then now() else null end,
    approval_deadline=case when v_flow='requested' then now()+make_interval(mins=>v_timeout) else null end
    where id=v_id;
  return v_id;
end $$;


ALTER FUNCTION "public"."create_booking_from_hold_for_current_user"("p_hold_id" "uuid", "p_booking_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[] DEFAULT '{}'::"date"[]) RETURNS "uuid"[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_uid uuid:=auth.uid(); v_date date; v_dates date[]; v_quote jsonb; v_slot uuid; v_tax numeric; v_total numeric;
  v_id uuid; v_ids uuid[]:='{}'; v_mode text; v_window integer; v_timeout integer; v_flow text;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  v_dates:=array(select distinct d from unnest(array_append(coalesce(p_recurrence_dates,'{}'),p_book_date)) d order by d);
  if cardinality(v_dates)>52 then raise exception 'maximum 52 occurrences' using errcode='22023'; end if;
  select id into v_slot from public.time_slots where venue_id=p_venue_id and label='Variable duration' and is_active limit 1;
  select booking_mode,instant_book_window_hours,approval_timeout_minutes into v_mode,v_window,v_timeout from public.meeting_room_profiles where venue_id=p_venue_id;
  if not found then raise exception 'meeting room not found' using errcode='22023'; end if;
  foreach v_date in array v_dates loop
    select booking_id into v_id from public.meeting_booking_idempotency where user_id=v_uid and idempotency_key=p_idempotency_key and occurrence_date=v_date;
    if v_id is not null then v_ids:=array_append(v_ids,v_id); continue; end if;
    perform pg_advisory_xact_lock(hashtextextended(p_venue_id::text||':'||v_date::text,0));
    v_quote:=public.meeting_room_quote(p_venue_id,v_date,p_start_time,p_duration_minutes);
    if not coalesce((v_quote->>'available')::boolean,false) then raise exception 'room unavailable on %',v_date using errcode='P0001'; end if;
    v_tax:=round((v_quote->>'price')::numeric*(select tax_rate from public.venues where id=p_venue_id)/100,2); v_total:=(v_quote->>'price')::numeric+v_tax;
    v_flow:=case when v_mode='approval' or (v_mode='hybrid' and v_date+p_start_time>localtimestamp+make_interval(hours=>v_window)) then 'requested'
      when v_total=0 then 'confirmed' else 'payment_pending' end;
    insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,workflow_status,
      amount,tax_amount,total_amount,approval_deadline,confirmed_at,metadata)
    values('MR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_uid,p_venue_id,v_slot,v_date,p_start_time,
      p_start_time+make_interval(mins=>p_duration_minutes),case when v_flow='confirmed' then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
      v_flow,(v_quote->>'price')::numeric,v_tax,v_total,case when v_flow='requested' then now()+make_interval(mins=>v_timeout) end,
      case when v_flow='confirmed' then now() end,jsonb_build_object('module','meeting_room','duration_minutes',p_duration_minutes,'idempotency_key',p_idempotency_key)) returning id into v_id;
    insert into public.meeting_booking_idempotency values(v_uid,p_idempotency_key,v_date,v_id);
    v_ids:=array_append(v_ids,v_id);
  end loop;
  return v_ids;
exception when exclusion_violation then raise exception 'room unavailable' using errcode='P0001';
end $$;


ALTER FUNCTION "public"."create_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_meeting_room"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_room_type" "text", "p_hourly_rate" numeric, "p_half_day_rate" numeric, "p_full_day_rate" numeric, "p_buffer_minutes" integer, "p_amenities" "text"[]) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_org uuid; v_category uuid; v_venue uuid;
begin
  select id into v_org from public.organizations where owner_user_id=auth.uid() and deleted_at is null limit 1;
  if v_org is null then raise exception 'owner organization required' using errcode='42501'; end if;
  select id into v_category from public.venue_categories where slug='meeting_room';
  insert into public.venues(org_id,category_id,name,slug,description,city,state,latitude,longitude,capacity,pricing_base_amount)
  values(v_org,v_category,trim(p_name),lower(regexp_replace(trim(p_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(gen_random_uuid()::text,1,8),
    trim(p_description),trim(p_city),trim(p_state),p_latitude,p_longitude,p_capacity,p_hourly_rate) returning id into v_venue;
  insert into public.meeting_room_profiles(venue_id,room_type,hourly_rate,half_day_rate,full_day_rate,buffer_minutes,amenities)
  values(v_venue,p_room_type,p_hourly_rate,p_half_day_rate,p_full_day_rate,p_buffer_minutes,coalesce(p_amenities,'{}'));
  insert into public.time_slots(venue_id,label,start_time,end_time,price_amount) values(v_venue,'Variable duration','00:00','23:59',p_hourly_rate);
  insert into public.venue_operating_hours(venue_id,day_of_week,opens_at,closes_at)
    select v_venue,d,'09:00','18:00' from generate_series(0,6)d;
  return v_venue;
end $$;


ALTER FUNCTION "public"."create_meeting_room"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_room_type" "text", "p_hourly_rate" numeric, "p_half_day_rate" numeric, "p_full_day_rate" numeric, "p_buffer_minutes" integer, "p_amenities" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_offline_booking"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_customer_name" "text", "p_customer_phone" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_slot public.time_slots; v_id uuid; v_tax numeric;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_venue_id::text||':'||p_book_date::text,0));
  select s.* into v_slot from public.time_slots s join public.venues v on v.id=s.venue_id
    join public.organizations o on o.id=v.org_id where s.id=p_slot_id and s.venue_id=p_venue_id
    and s.is_active and o.owner_user_id=auth.uid();
  if not found then raise exception 'slot not found or not permitted'; end if;
  select round(v_slot.price_amount*v.tax_rate/100,2) into v_tax from public.venues v where v.id=p_venue_id;
  insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,
    workflow_status,amount,tax_amount,total_amount,metadata,confirmed_at)
  values('OFF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid(),p_venue_id,p_slot_id,
    p_book_date,v_slot.start_time,v_slot.end_time,'confirmed','confirmed',v_slot.price_amount,v_tax,
    v_slot.price_amount+v_tax,jsonb_build_object('source','offline','customer_name',trim(p_customer_name),
    'customer_phone',trim(p_customer_phone)),now()) returning id into v_id;
  return v_id;
exception when exclusion_violation then raise exception 'slot unavailable' using errcode='P0001';
end $$;


ALTER FUNCTION "public"."create_offline_booking"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_customer_name" "text", "p_customer_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_offline_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_owner uuid; v_ids uuid[];
begin
  select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=p_venue_id;
  if v_owner is distinct from auth.uid() then raise exception 'not permitted' using errcode='42501'; end if;
  v_ids:=public.create_meeting_booking(p_venue_id,p_book_date,p_start_time,p_duration_minutes,gen_random_uuid(),'{}');
  update public.bookings set status='confirmed',workflow_status='confirmed',confirmed_at=now(),
    metadata=metadata||jsonb_build_object('source','offline','customer_name',trim(p_customer_name),'customer_phone',trim(p_customer_phone)) where id=v_ids[1];
  return v_ids[1];
end $$;


ALTER FUNCTION "public"."create_offline_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_offline_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_owner uuid;v_ids uuid[];begin select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=p_venue_id;
 if v_owner is distinct from auth.uid() then raise exception 'not permitted' using errcode='42501';end if;
 v_ids:=public.create_sports_booking(p_venue_id,p_book_date,p_start_time,p_duration_minutes,gen_random_uuid(),'{}');
 update public.bookings set status='confirmed',workflow_status='confirmed',confirmed_at=now(),metadata=metadata||jsonb_build_object('source','offline','customer_name',trim(p_customer_name),'customer_phone',trim(p_customer_phone)) where id=v_ids[1];return v_ids[1];end $$;


ALTER FUNCTION "public"."create_offline_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venues" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "category_id" "uuid",
    "name" "text" NOT NULL,
    "slug" "text",
    "description" "text",
    "address_line1" "text",
    "address_line2" "text",
    "city" "text",
    "state" "text",
    "postal_code" "text",
    "country" "text" DEFAULT 'IN'::"text" NOT NULL,
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "geog" "public"."geography"(Point,4326) GENERATED ALWAYS AS (("public"."st_setsrid"("public"."st_makepoint"("longitude", "latitude"), 4326))::"public"."geography") STORED,
    "capacity" integer,
    "pricing_base_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "pricing_currency" "text" DEFAULT 'INR'::"text" NOT NULL,
    "tax_rate" numeric(5,2) DEFAULT 18.00 NOT NULL,
    "parking_capacity" integer,
    "food_options" "text",
    "rules" "text",
    "cancellation_policy" "jsonb",
    "is_verified" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "avg_rating" numeric(3,2) DEFAULT 0 NOT NULL,
    "rating_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "search_document" "tsvector" GENERATED ALWAYS AS ((("setweight"("to_tsvector"('"english"'::"regconfig", COALESCE("name", ''::"text")), 'A'::"char") || "setweight"("to_tsvector"('"english"'::"regconfig", COALESCE("city", ''::"text")), 'B'::"char")) || "setweight"("to_tsvector"('"english"'::"regconfig", COALESCE("description", ''::"text")), 'B'::"char"))) STORED,
    CONSTRAINT "venues_avg_rating_check" CHECK ((("avg_rating" >= (0)::numeric) AND ("avg_rating" <= (5)::numeric))),
    CONSTRAINT "venues_capacity_check" CHECK (("capacity" > 0)),
    CONSTRAINT "venues_pricing_base_amount_check" CHECK (("pricing_base_amount" >= (0)::numeric)),
    CONSTRAINT "venues_tax_rate_check" CHECK ((("tax_rate" >= (0)::numeric) AND ("tax_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."venues" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_owner_venue"("p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric) RETURNS "public"."venues"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_org_id uuid;
  v_venue public.venues;
begin
  -- Get owner's org.
  select id into v_org_id
  from public.organizations
  where owner_user_id = auth.uid()
  limit 1;

  if v_org_id is null then
    raise exception 'owner_org_not_found';
  end if;

  insert into public.venues (
    org_id, category_id, name, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, slug
  ) values (
    v_org_id, p_category_id, p_name, p_description, p_city, p_state,
    p_latitude, p_longitude, p_capacity, p_pricing_base_amount,
    lower(replace(p_name, ' ', '-'))
  ) returning * into v_venue;

  return v_venue;
end;
$$;


ALTER FUNCTION "public"."create_owner_venue"("p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_registration_form"("p_name" "text", "p_module_key" "text", "p_schema" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_id uuid;begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.owner_profiles where user_id=v_uid) and not public.has_role(v_uid,'administrator') then raise exception 'owner or admin required' using errcode='42501';end if;
 insert into public.registration_form_templates(owner_user_id,name,module_key,current_version)values(v_uid,trim(p_name),trim(p_module_key),1)returning id into v_id;
 insert into public.registration_form_versions(template_id,version,schema,created_by)values(v_id,1,p_schema,v_uid);return v_id;end$$;


ALTER FUNCTION "public"."create_registration_form"("p_name" "text", "p_module_key" "text", "p_schema" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[] DEFAULT '{}'::"date"[]) RETURNS "uuid"[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_uid uuid:=auth.uid();v_date date;v_dates date[];v_quote jsonb;v_slot uuid;v_tax numeric;v_id uuid;v_ids uuid[]:='{}';v_mode text;v_window int;v_timeout int;v_flow text;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 v_dates:=array(select distinct d from unnest(array_append(coalesce(p_recurrence_dates,'{}'),p_book_date))d order by d);if cardinality(v_dates)>52 then raise exception 'maximum 52 occurrences';end if;
 select id into v_slot from public.time_slots where venue_id=p_venue_id and label='Variable duration' and is_active limit 1;
 select booking_mode,instant_book_window_hours,approval_timeout_minutes into v_mode,v_window,v_timeout from public.sports_venue_profiles where venue_id=p_venue_id;if not found then raise exception 'sports venue not found';end if;
 foreach v_date in array v_dates loop
  select booking_id into v_id from public.sports_booking_idempotency where user_id=v_uid and idempotency_key=p_idempotency_key and occurrence_date=v_date;
  if v_id is not null then v_ids:=array_append(v_ids,v_id);continue;end if;
  perform pg_advisory_xact_lock(hashtextextended(p_venue_id::text||':'||v_date::text,0));v_quote:=public.sports_venue_quote(p_venue_id,v_date,p_start_time,p_duration_minutes);
  if not coalesce((v_quote->>'available')::bool,false) then raise exception 'sports venue unavailable on %',v_date using errcode='P0001';end if;
  v_tax:=round((v_quote->>'price')::numeric*(select tax_rate from public.venues where id=p_venue_id)/100,2);
  v_flow:=case when v_mode='approval' or(v_mode='hybrid' and v_date+p_start_time>localtimestamp+make_interval(hours=>v_window)) then 'requested' when (v_quote->>'price')::numeric+v_tax=0 then 'confirmed' else 'payment_pending' end;
  insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,workflow_status,amount,tax_amount,total_amount,approval_deadline,confirmed_at,metadata)
  values('SP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_uid,p_venue_id,v_slot,v_date,p_start_time,p_start_time+make_interval(mins=>p_duration_minutes),case when v_flow='confirmed' then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,v_flow,(v_quote->>'price')::numeric,v_tax,(v_quote->>'price')::numeric+v_tax,case when v_flow='requested' then now()+make_interval(mins=>v_timeout) end,case when v_flow='confirmed' then now() end,jsonb_build_object('module','sports','duration_minutes',p_duration_minutes,'idempotency_key',p_idempotency_key)) returning id into v_id;
  insert into public.sports_booking_idempotency values(v_uid,p_idempotency_key,v_date,v_id);v_ids:=array_append(v_ids,v_id);
 end loop;return v_ids;
exception when exclusion_violation then raise exception 'sports venue unavailable' using errcode='P0001';
end $$;


ALTER FUNCTION "public"."create_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sports_venue"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_capacity" integer, "p_sport_type" "text", "p_hourly_rate" numeric, "p_session_minutes" integer, "p_session_rate" numeric, "p_buffer_minutes" integer, "p_equipment" "text"[], "p_amenities" "text"[]) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_org uuid;v_category uuid;v_venue uuid;
begin
 select id into v_org from public.organizations where owner_user_id=auth.uid() and deleted_at is null limit 1;
 if v_org is null then raise exception 'owner organization required' using errcode='42501';end if;
 select id into v_category from public.venue_categories where slug='sports_ground';
 insert into public.venues(org_id,category_id,name,slug,description,city,state,latitude,longitude,capacity,pricing_base_amount)
 values(v_org,v_category,trim(p_name),lower(regexp_replace(trim(p_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(gen_random_uuid()::text,1,8),trim(p_description),trim(p_city),trim(p_state),17.385,78.4867,p_capacity,p_hourly_rate) returning id into v_venue;
 insert into public.sports_venue_profiles values(v_venue,p_sport_type,p_hourly_rate,p_session_minutes,p_session_rate,60,30,p_buffer_minutes,'instant',48,1440,coalesce(p_equipment,'{}'),coalesce(p_amenities,'{}'),now());
 insert into public.time_slots(venue_id,label,start_time,end_time,price_amount) values(v_venue,'Variable duration','00:00','23:59',p_hourly_rate);
 insert into public.venue_operating_hours(venue_id,day_of_week,opens_at,closes_at) select v_venue,d,'06:00','22:00' from generate_series(0,6)d;
 return v_venue;
end $$;


ALTER FUNCTION "public"."create_sports_venue"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_capacity" integer, "p_sport_type" "text", "p_hourly_rate" numeric, "p_session_minutes" integer, "p_session_rate" numeric, "p_buffer_minutes" integer, "p_equipment" "text"[], "p_amenities" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_stay_booking"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer, "p_rooms" "jsonb", "p_idempotency_key" "uuid", "p_registration_submission_id" "uuid" DEFAULT NULL::"uuid", "p_offline_customer" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_actor uuid:=auth.uid();v_customer uuid:=coalesce(p_offline_customer,v_actor);v_owner uuid;v_mode text;v_booking uuid;v_sub numeric:=0;v_discount numeric:=0;v_tax numeric:=0;v_fee numeric:=0;v_item jsonb;v_charge jsonb;v_unit uuid;v_qty int;v_rate numeric;v_room uuid;v_nights int:=p_check_out-p_check_in;i int;v_taxes jsonb:='[]';v_fees jsonb:='[]';v_rate_discount numeric:=0;v_base numeric;
begin
 if v_actor is null then raise exception 'authentication required' using errcode='42501';end if;if p_check_in<current_date or p_check_out<=p_check_in then raise exception 'invalid stay dates' using errcode='22023';end if;
 select o.owner_user_id,p.booking_mode into v_owner,v_mode from accommodation_properties p join organizations o on o.id=p.org_id where p.id=p_property_id and p.module='stay' and p.is_active;if not found then raise exception 'property unavailable';end if;
 if p_offline_customer is not null and v_actor<>v_owner and not public.has_role(v_actor,'administrator') then raise exception 'owner required for offline booking' using errcode='42501';end if;
 if jsonb_typeof(p_rooms)<>'array' or jsonb_array_length(p_rooms)=0 then raise exception 'select rooms' using errcode='22023';end if;
 if exists(select 1 from stay_bookings where user_id=v_customer and idempotency_key=p_idempotency_key)then select id into v_booking from stay_bookings where user_id=v_customer and idempotency_key=p_idempotency_key;return v_booking;end if;
 for v_item in select * from jsonb_array_elements(p_rooms) order by value->>'unit_id' loop
  v_unit:=(v_item->>'unit_id')::uuid;v_qty:=greatest((v_item->>'quantity')::int,1);perform pg_advisory_xact_lock(hashtext(v_unit::text));
  select nightly_rate into v_rate from available_stay_units(p_property_id,p_check_in,p_check_out,p_adults,p_children) where unit_id=v_unit and available>=v_qty;if not found then raise exception 'room no longer available' using errcode='P0001';end if;
  select taxes,fees,discount into v_taxes,v_fees,v_rate_discount from stay_rates where unit_id=v_unit and start_date<=p_check_in and end_date>=p_check_out-1 order by start_date desc limit 1;if not found then v_taxes:='[]';v_fees:='[]';v_rate_discount:=0;end if;
  v_base:=v_rate*v_nights*v_qty;v_sub:=v_sub+v_base;v_discount:=v_discount+least(v_rate_discount*v_qty,v_base);
  for v_charge in select * from jsonb_array_elements(v_taxes)loop v_tax:=v_tax+case when v_charge->>'type'='percent' then v_base*coalesce((v_charge->>'value')::numeric,0)/100 else coalesce((v_charge->>'value')::numeric,0)*v_qty end;end loop;
  for v_charge in select * from jsonb_array_elements(v_fees)loop v_fee:=v_fee+case when v_charge->>'type'='percent' then v_base*coalesce((v_charge->>'value')::numeric,0)/100 else coalesce((v_charge->>'value')::numeric,0)*v_qty end;end loop;
 end loop;
 insert into stay_bookings(user_id,property_id,idempotency_key,check_in,check_out,adults,children,status,subtotal,discount,tax_total,fee_total,total,registration_submission_id,is_offline,created_by)
 values(v_customer,p_property_id,p_idempotency_key,p_check_in,p_check_out,p_adults,p_children,case when p_offline_customer is not null then 'confirmed' when v_mode='approval' then 'requested' when v_sub=0 then 'confirmed' else 'payment_pending' end,v_sub,v_discount,v_tax,v_fee,v_sub-v_discount+v_tax+v_fee,p_registration_submission_id,p_offline_customer is not null,v_actor)returning id into v_booking;
 for v_item in select * from jsonb_array_elements(p_rooms) order by value->>'unit_id' loop
  v_unit:=(v_item->>'unit_id')::uuid;v_qty:=greatest((v_item->>'quantity')::int,1);select nightly_rate into v_rate from available_stay_units(p_property_id,p_check_in,p_check_out,p_adults,p_children)where unit_id=v_unit;
  for i in 1..v_qty loop select r.id into v_room from stay_physical_rooms r where r.unit_id=v_unit and r.is_active and not exists(select 1 from stay_blocks x where x.physical_room_id=r.id and x.stay_dates&&daterange(p_check_in,p_check_out,'[)'))and not exists(select 1 from stay_booking_rooms br where br.physical_room_id=r.id and br.stay_dates&&daterange(p_check_in,p_check_out,'[)')) order by r.room_code for update skip locked limit 1;if v_room is null then raise exception 'room no longer available';end if;insert into stay_booking_rooms(stay_booking_id,physical_room_id,unit_id,nightly_rate,stay_dates)values(v_booking,v_room,v_unit,v_rate,daterange(p_check_in,p_check_out,'[)'));end loop;
 end loop;return v_booking;
end$$;


ALTER FUNCTION "public"."create_stay_booking"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer, "p_rooms" "jsonb", "p_idempotency_key" "uuid", "p_registration_submission_id" "uuid", "p_offline_customer" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_app_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select case
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='super_administrator' and revoked_at is null) then 'admin'
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='administrator' and revoked_at is null) then 'admin'
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='venue_owner' and revoked_at is null) then 'owner'
    else 'customer' end;
$$;


ALTER FUNCTION "public"."current_app_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."customer_booking_receipt"("p_booking_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select commerce_receipt((select id from commerce_references where legacy_booking_id=p_booking_id))$$;


ALTER FUNCTION "public"."customer_booking_receipt"("p_booking_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_owner_account"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$ begin
  if auth.uid() is null or auth.uid()<>p_user_id then raise exception 'not permitted'; end if;
  delete from public.owner_profiles where user_id=auth.uid();
end; $$;


ALTER FUNCTION "public"."delete_owner_account"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_owner_venue"("p_venue_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_exists boolean;
begin
  select exists(
    select 1
    from public.venues v
    join public.organizations o on o.id = v.org_id
    where v.id = p_venue_id
      and o.owner_user_id = auth.uid()
  ) into v_exists;

  if not v_exists then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set deleted_at = now(), is_active = false
  where id = p_venue_id;
end;
$$;


ALTER FUNCTION "public"."delete_owner_venue"("p_venue_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."drop_course_enrollment"("p_batch_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
begin
  update public.course_enrollments
  set status = 'dropped'
  where batch_id = p_batch_id and user_id = p_user_id and status = 'enrolled';
  if not found then
    raise exception 'enrollment not found' using errcode = 'P0001';
  end if;

  update public.course_batches
  set enrolled_count = (
    select count(*) from public.course_enrollments
    where batch_id = p_batch_id and status = 'enrolled'
  )
  where id = p_batch_id;
end $$;


ALTER FUNCTION "public"."drop_course_enrollment"("p_batch_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_booking_notification"("p_user_id" "uuid", "p_booking_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_category" "text", "p_dedupe_key" "text", "p_target_route" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_notification_id uuid; v_preferences public.notification_preferences;
begin
  if p_user_id is null then return null; end if;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  if (p_category='booking' and coalesce(v_preferences.booking_updates,true)=false)
    or (p_category='payment' and coalesce(v_preferences.payment_updates,true)=false)
    or (p_category='reminder' and coalesce(v_preferences.reminders,true)=false) then return null;
  end if;

  if coalesce(v_preferences.in_app,true) then
    insert into public.notifications(user_id,type,title,body,data,dedupe_key)
    values(p_user_id,p_type,p_title,p_body,
      jsonb_build_object('booking_id',p_booking_id,'target_route',p_target_route,'in_app',true),p_dedupe_key)
    on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing
    returning id into v_notification_id;
  end if;

  -- A notification row is the canonical payload for every future channel.
  if v_notification_id is null and
    (coalesce(v_preferences.push,false) or coalesce(v_preferences.email,false)
      or coalesce(v_preferences.sms,false) or coalesce(v_preferences.whatsapp,false)) then
    insert into public.notifications(user_id,type,title,body,data,dedupe_key)
    values(p_user_id,p_type,p_title,p_body,
      jsonb_build_object('booking_id',p_booking_id,'target_route',p_target_route,'in_app',false),p_dedupe_key)
    on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing
    returning id into v_notification_id;
    if v_notification_id is null then
      select id into v_notification_id from public.notifications
      where user_id=p_user_id and dedupe_key=p_dedupe_key;
    end if;
  end if;

  if v_notification_id is not null then
    if coalesce(v_preferences.push,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'push') on conflict do nothing; end if;
    if coalesce(v_preferences.email,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'email') on conflict do nothing; end if;
    if coalesce(v_preferences.sms,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'sms') on conflict do nothing; end if;
    if coalesce(v_preferences.whatsapp,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'whatsapp') on conflict do nothing; end if;
  end if;
  return v_notification_id;
end $$;


ALTER FUNCTION "public"."enqueue_booking_notification"("p_user_id" "uuid", "p_booking_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_category" "text", "p_dedupe_key" "text", "p_target_route" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_upcoming_booking_reminders"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare r record; v_owner uuid; n integer:=0;
begin
  for r in select b.* from public.bookings b where b.workflow_status='confirmed'
    and (b.book_date+b.start_time) > now()
    and (b.book_date+b.start_time) <= now()+interval '24 hours'
  loop
    select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=r.venue_id;
    perform public.enqueue_booking_notification(r.user_id,r.id,'booking_reminder','Booking tomorrow',r.booking_ref,'reminder',r.id||':customer:reminder:'||r.book_date,'/bookings?bookingId='||r.id);
    perform public.enqueue_booking_notification(v_owner,r.id,'owner_booking_reminder','Upcoming booking',r.booking_ref,'reminder',r.id||':owner:reminder:'||r.book_date,'/owner/bookings?bookingId='||r.id);
    n:=n+1;
  end loop;
  return n;
end $$;


ALTER FUNCTION "public"."enqueue_upcoming_booking_reminders"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enroll_in_course"("p_batch_id" "uuid", "p_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_capacity integer;
  v_enrollment_id uuid;
  v_lock_key bigint;
begin
  -- Only active batches of published courses can be enrolled in.
  select b.capacity into v_capacity
  from public.course_batches b
  join public.courses c on c.id = b.course_id
  where b.id = p_batch_id and b.is_active and c.status = 'published';
  if not found then
    raise exception 'batch not available' using errcode = 'P0001';
  end if;

  v_lock_key := hashtextextended('batch:' || p_batch_id::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  if (select enrolled_count from public.course_batches where id = p_batch_id)
     >= v_capacity then
    raise exception 'batch full' using errcode = 'P0001';
  end if;

  insert into public.course_enrollments (batch_id, user_id, status)
  values (p_batch_id, p_user_id, 'enrolled')
  on conflict (batch_id, user_id) do nothing
  returning id into v_enrollment_id;

  -- Count seats even when the user was already enrolled (idempotent).
  update public.course_batches
  set enrolled_count = (
    select count(*) from public.course_enrollments
    where batch_id = p_batch_id and status = 'enrolled'
  )
  where id = p_batch_id;

  if v_enrollment_id is null then
    select id into v_enrollment_id
    from public.course_enrollments
    where batch_id = p_batch_id and user_id = p_user_id;
  end if;

  return v_enrollment_id;
end $$;


ALTER FUNCTION "public"."enroll_in_course"("p_batch_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."event_detail"("p_event_id" "uuid", "p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "org_id" "uuid", "venue_id" "uuid", "category" "public"."event_category", "title" "text", "description" "text", "starts_at" timestamp with time zone, "ends_at" timestamp with time zone, "capacity" integer, "ticket_price" numeric, "is_free" boolean, "cover_image" "text", "status" "text", "venue_name" "text", "registered_count" bigint, "user_registered" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    e.id, e.org_id, e.venue_id, e.category, e.title, e.description,
    e.starts_at, e.ends_at, e.capacity, e.ticket_price, e.is_free,
    e.cover_image, e.status,
    v.name as venue_name,
    coalesce((
      select sum(r.quantity)
      from public.event_registrations r
      where r.event_id = e.id and r.status = 'registered'
    ), 0) as registered_count,
    case
      when p_user_id is null then false
      else exists (
        select 1 from public.event_registrations r
        where r.event_id = e.id and r.user_id = p_user_id
          and r.status = 'registered'
      )
    end as user_registered
  from public.events e
  left join public.venues v on v.id = e.venue_id
  where e.id = p_event_id and e.status = 'published';
$$;


ALTER FUNCTION "public"."event_detail"("p_event_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."event_summaries"("p_user_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "org_id" "uuid", "venue_id" "uuid", "category" "public"."event_category", "title" "text", "description" "text", "starts_at" timestamp with time zone, "ends_at" timestamp with time zone, "capacity" integer, "ticket_price" numeric, "is_free" boolean, "cover_image" "text", "status" "text", "venue_name" "text", "registered_count" bigint, "user_registered" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    e.id, e.org_id, e.venue_id, e.category, e.title, e.description,
    e.starts_at, e.ends_at, e.capacity, e.ticket_price, e.is_free,
    e.cover_image, e.status,
    v.name as venue_name,
    coalesce((
      select sum(r.quantity)
      from public.event_registrations r
      where r.event_id = e.id and r.status = 'registered'
    ), 0) as registered_count,
    case
      when p_user_id is null then false
      else exists (
        select 1 from public.event_registrations r
        where r.event_id = e.id and r.user_id = p_user_id
          and r.status = 'registered'
      )
    end as user_registered
  from public.events e
  left join public.venues v on v.id = e.venue_id
  where e.status = 'published' and e.ends_at > now()
  order by e.starts_at asc;
$$;


ALTER FUNCTION "public"."event_summaries"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expire_hall_workflows"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare n integer;
begin
  perform public.expire_stale_holds();
  update public.bookings set workflow_status='expired',status='cancelled',cancelled_at=now()
    where workflow_status='requested' and approval_deadline<now();
  get diagnostics n=row_count; return n;
end $$;


ALTER FUNCTION "public"."expire_hall_workflows"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expire_stale_holds"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
declare
  v_expired integer := 0;
begin
  update public.booking_holds
  set status = 'expired'
  where status = 'active' and expires_at < now();
  get diagnostics v_expired = row_count;
  return v_expired;
end $$;


ALTER FUNCTION "public"."expire_stale_holds"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fail_webhook_event"("p_provider" "text", "p_event_id" "text", "p_error" "text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  update public.webhook_events set processing_started_at=null,last_error=left(coalesce(p_error,'processing failed'),500)
  where provider=p_provider and event_id=p_event_id and processed=false;
$$;


ALTER FUNCTION "public"."fail_webhook_event"("p_provider" "text", "p_event_id" "text", "p_error" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_owner_profile"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select jsonb_build_object(
    'id',op.id,'user_id',op.user_id,'email',op.email,'name',op.name,
    'phone',op.phone,'whatsapp',op.whatsapp,'photo_url',op.photo_url,
    'business_name',o.name,'address',o.address_line1,'city',o.city,'state',o.state,
    'latitude',o.latitude,'longitude',o.longitude,'org_id',o.id)
  from public.owner_profiles op
  left join public.organizations o on o.owner_user_id=op.user_id and o.deleted_at is null
  where op.user_id=auth.uid() order by o.created_at limit 1;
$$;


ALTER FUNCTION "public"."get_owner_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_owner_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select p.user_id
  from public.owner_profiles p
  where p.user_id = (select auth.uid())
$$;


ALTER FUNCTION "public"."get_owner_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_owner_venues"() RETURNS SETOF "public"."venues"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select v.*
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where o.owner_user_id = auth.uid()
    and v.deleted_at is null
  order by v.created_at desc;
$$;


ALTER FUNCTION "public"."get_owner_venues"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'customer')
  on conflict (user_id, role) do nothing;

  return new;
end $$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_role"("uid" "uuid", "r" "public"."user_role") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1 from public.user_roles
    where user_id = uid and role = r and revoked_at is null
  );
$$;


ALTER FUNCTION "public"."has_role"("uid" "uuid", "r" "public"."user_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invoice_immutable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$begin raise exception 'issued invoices are immutable' using errcode='42501';end$$;


ALTER FUNCTION "public"."invoice_immutable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_org_owner"("org_id" "uuid", "uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1 from public.organizations
    where id = org_id and owner_user_id = uid and deleted_at is null
  );
$$;


ALTER FUNCTION "public"."is_org_owner"("org_id" "uuid", "uid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."issue_commerce_invoice"("p_reference_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb" DEFAULT '{}'::"jsonb", "p_parent_invoice_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare c commerce_references;v_uid uuid:=auth.uid();v_config jsonb;v_seq bigint;v_prefix text;v_number text;v_id uuid;v_paid numeric:=0;v_refund numeric:=0;v_payment_ref text:='';v_method text:='';v_payment_status text:='unpaid';v_status text;begin
 select * into c from commerce_references where id=p_reference_id;if not found then raise exception 'reference not found';end if;if v_uid<>c.owner_user_id and not public.has_role(v_uid,'administrator')and not(p_document_type='receipt'and v_uid=c.customer_user_id and c.booking_status='confirmed')then raise exception 'not permitted' using errcode='42501';end if;if p_document_type not in('receipt','tax_invoice','credit_note')then raise exception 'invalid document type';end if;if p_document_type='credit_note'and not exists(select 1 from invoices where id=p_parent_invoice_id and commerce_reference_id=c.id)then raise exception 'valid parent invoice required';end if;
 select coalesce(amount,0),coalesce(provider_payment_id,''),coalesce(method,''),status::text into v_paid,v_payment_ref,v_method,v_payment_status from payments where commerce_reference_id=c.id and status in('captured','refunded','partially_refunded')order by updated_at desc limit 1;if not found and c.payment_status='free'then v_payment_status:='free';end if;select coalesce(sum(amount),0)into v_refund from refunds where commerce_reference_id=c.id and status='processed';
 insert into invoice_configs(owner_user_id,config)values(c.owner_user_id,'{}')on conflict do nothing;update invoice_configs set next_number=next_number+1 where owner_user_id=c.owner_user_id returning config,next_number-1 into v_config,v_seq;v_prefix:=coalesce(nullif(v_config->>'invoice_prefix',''),case when p_document_type='credit_note'then 'CN'else 'INV'end);v_number:=v_prefix||'-'||lpad(v_seq::text,6,'0');v_status:=case when p_document_type='credit_note'or v_refund>=v_paid and v_refund>0 then 'refunded'when v_refund>0 then 'partially_refunded'when c.booking_status='cancelled'then 'cancelled'else 'issued'end;
 insert into invoices(owner_user_id,customer_user_id,booking_id,commerce_reference_id,parent_invoice_id,document_type,status,sequence_number,invoice_number,currency,subtotal,discount,tax_total,fee_total,total,paid,due,refund,config_snapshot,invoice_snapshot)values(c.owner_user_id,c.customer_user_id,c.legacy_booking_id,c.id,p_parent_invoice_id,p_document_type,v_status,v_seq,v_number,c.currency,coalesce((p_invoice->>'subtotal')::numeric,c.amount),coalesce((p_invoice->>'discount')::numeric,0),coalesce((p_invoice->>'tax_total')::numeric,0),coalesce((p_invoice->>'fee_total')::numeric,0),c.amount,v_paid,greatest(c.amount-v_paid,0),v_refund,v_config,c.metadata||p_invoice||jsonb_build_object('module',c.module,'resource_id',c.resource_id,'reservation_id',c.reservation_id,'invoice_number',v_number,'payment_ref',v_payment_ref,'payment_method',v_method,'payment_status',v_payment_status))returning id into v_id;return v_id;end$$;


ALTER FUNCTION "public"."issue_commerce_invoice"("p_reference_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."issue_invoice"("p_booking_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$select issue_commerce_invoice((select id from commerce_references where legacy_booking_id=p_booking_id),p_document_type,p_invoice,p_parent_invoice_id)$$;


ALTER FUNCTION "public"."issue_invoice"("p_booking_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_ticket_resolved"("p_ticket_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update public.support_tickets
  set status = 'resolved', resolved_at = now(), updated_at = now()
  where id = p_ticket_id;
  if not found then
    raise exception 'ticket not found' using errcode = 'P0001';
  end if;
end $$;


ALTER FUNCTION "public"."mark_ticket_resolved"("p_ticket_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."meeting_room_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare r public.meeting_room_profiles; v_end time; v_day smallint; v_open time; v_close time; v_price numeric; v_available boolean:=true;
begin
  select * into r from public.meeting_room_profiles where venue_id=p_venue_id;
  if not found or p_duration_minutes<r.min_duration_minutes or mod(p_duration_minutes,r.booking_increment_minutes)<>0 then
    return jsonb_build_object('available',false,'reason','Invalid duration');
  end if;
  v_end:=p_start_time+make_interval(mins=>p_duration_minutes);
  if v_end<=p_start_time then return jsonb_build_object('available',false,'reason','Booking must end the same day'); end if;
  v_day:=((extract(dow from p_book_date)::int+6)%7)::smallint;
  select opens_at,closes_at into v_open,v_close from public.venue_operating_hours where venue_id=p_venue_id and day_of_week=v_day and not is_closed;
  if not found or p_start_time<v_open or v_end>v_close then v_available:=false; end if;
  if exists(select 1 from public.meeting_room_breaks where venue_id=p_venue_id and day_of_week=v_day and (p_start_time,v_end) overlaps(start_time,end_time)) then v_available:=false; end if;
  if exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_book_date) then v_available:=false; end if;
  if exists(select 1 from public.bookings b where b.venue_id=p_venue_id and b.book_date=p_book_date
    and b.status in ('held','pending','confirmed','completed')
    and (p_start_time,v_end) overlaps(b.start_time-make_interval(mins=>r.buffer_minutes),b.end_time+make_interval(mins=>r.buffer_minutes))) then v_available:=false; end if;
  v_price:=case when p_duration_minutes>=480 then r.full_day_rate when p_duration_minutes>=240 then r.half_day_rate
    else ceil(p_duration_minutes/30.0)*(r.hourly_rate/2) end;
  return jsonb_build_object('available',v_available,'end_time',v_end,'price',round(v_price,2),'currency','INR');
end $$;


ALTER FUNCTION "public"."meeting_room_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_enrolled_batches"("p_user_id" "uuid") RETURNS TABLE("batch_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select e.batch_id
  from public.course_enrollments e
  where e.user_id = p_user_id and e.status = 'enrolled';
$$;


ALTER FUNCTION "public"."my_enrolled_batches"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."nearby_venues"("p_lat" double precision, "p_lng" double precision, "radius_km" double precision DEFAULT 25, "max_rows" integer DEFAULT 20) RETURNS TABLE("id" "uuid", "org_id" "uuid", "category_id" "uuid", "name" "text", "slug" "text", "description" "text", "address_line1" "text", "address_line2" "text", "city" "text", "state" "text", "postal_code" "text", "country" "text", "latitude" double precision, "longitude" double precision, "capacity" integer, "pricing_base_amount" numeric, "pricing_currency" "text", "tax_rate" numeric, "parking_capacity" integer, "food_options" "text", "rules" "text", "cancellation_policy" "jsonb", "is_verified" boolean, "is_active" boolean, "avg_rating" numeric, "rating_count" integer, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "deleted_at" timestamp with time zone, "search_document" "tsvector", "distance_km" double precision, "venue_categories" "jsonb", "venue_images" "jsonb")
    LANGUAGE "sql" STABLE
    AS $$
  select
    v.id, v.org_id, v.category_id, v.name, v.slug, v.description,
    v.address_line1, v.address_line2, v.city, v.state, v.postal_code,
    v.country, v.latitude, v.longitude, v.capacity,
    v.pricing_base_amount, v.pricing_currency, v.tax_rate,
    v.parking_capacity, v.food_options, v.rules, v.cancellation_policy,
    v.is_verified, v.is_active, v.avg_rating, v.rating_count,
    v.created_at, v.updated_at, v.deleted_at, v.search_document,
    (st_distance(v.geog, st_makepoint(p_lng, p_lat)::geography) / 1000.0)::double precision as distance_km,
    jsonb_build_object(
      'id', c.id, 'slug', c.slug, 'name', c.name, 'icon', c.icon
    ) as venue_categories,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
          'id', img.id,
          'url', img.url,
          'thumbnail_url', img.thumbnail_url,
          'alt_text', img.alt_text,
          'is_cover', img.is_cover,
          'sort_order', img.sort_order
        ) order by img.is_cover desc, img.sort_order asc)
       from public.venue_images img where img.venue_id = v.id),
      '[]'::jsonb
    ) as venue_images
  from public.venues v
  left join public.venue_categories c on c.id = v.category_id
  where v.is_active
    and v.deleted_at is null
    and st_dwithin(
      v.geog,
      st_makepoint(p_lng, p_lat)::geography,
      radius_km * 1000
    )
  order by distance_km asc
  limit max_rows;
$$;


ALTER FUNCTION "public"."nearby_venues"("p_lat" double precision, "p_lng" double precision, "radius_km" double precision, "max_rows" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_hall_booking_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_owner uuid; v_customer_route text; v_owner_route text;
begin
  select o.owner_user_id into v_owner from public.venues v
    join public.organizations o on o.id=v.org_id where v.id=new.venue_id;
  v_customer_route := '/bookings?bookingId='||new.id;
  v_owner_route := '/owner/bookings?bookingId='||new.id;

  if tg_op='UPDATE' and new.status='cancelled'
    and old.status is distinct from new.status
    and new.workflow_status is not distinct from old.workflow_status then
    new.workflow_status := 'cancelled';
  end if;

  if tg_op='INSERT' then
    if new.workflow_status='requested' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'request_submitted','Request submitted',new.booking_ref,'booking',new.id||':customer:requested',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_new_request','New booking request',new.booking_ref,'booking',new.id||':owner:requested',v_owner_route);
    elsif new.workflow_status='payment_pending' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'payment_required','Payment required','Pay now to confirm '||new.booking_ref||'.','payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.workflow_status='confirmed' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    end if;
  elsif tg_op='UPDATE' and old.workflow_status is distinct from new.workflow_status then
    if new.workflow_status='payment_pending' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_approved','Booking approved','Your request '||new.booking_ref||' was approved.','booking',new.id||':customer:approved',v_customer_route);
      perform public.enqueue_booking_notification(new.user_id,new.id,'payment_required','Payment required','Pay now to confirm '||new.booking_ref||'.','payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.workflow_status='rejected' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_rejected','Booking rejected',new.booking_ref,'booking',new.id||':customer:rejected',v_customer_route);
    elsif new.workflow_status='confirmed' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    elsif new.workflow_status='cancelled' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_cancelled','Booking cancelled',new.booking_ref,'booking',new.id||':customer:cancelled',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_cancelled','Booking cancelled',new.booking_ref,'booking',new.id||':owner:cancelled',v_owner_route);
    end if;
  end if;
  if new.workflow_status='confirmed' and new.receipt_number is null then
    new.receipt_number:='BMS-R-'||upper(substr(replace(new.id::text,'-',''),1,12));
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."notify_hall_booking_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_hall_payment_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_booking public.bookings; v_owner uuid; v_customer_route text; v_owner_route text;
begin
  if tg_op='UPDATE' and old.status is not distinct from new.status then return new; end if;
  if new.status::text not in ('captured','failed') then return new; end if;
  select * into v_booking from public.bookings where id=new.booking_id;
  select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=v_booking.venue_id;
  v_customer_route := '/bookings?bookingId='||v_booking.id;
  v_owner_route := '/owner/payments?bookingId='||v_booking.id;
  if new.status::text='captured' then
    perform public.enqueue_booking_notification(v_booking.user_id,v_booking.id,'payment_success','Payment successful',v_booking.booking_ref,'payment',new.id||':customer:captured',v_customer_route);
    perform public.enqueue_booking_notification(v_owner,v_booking.id,'owner_payment_received','Payment received',v_booking.booking_ref,'payment',new.id||':owner:captured',v_owner_route);
  else
    perform public.enqueue_booking_notification(v_booking.user_id,v_booking.id,'payment_failed','Payment failed','Payment for '||v_booking.booking_ref||' failed. You can retry safely.','payment',new.id||':customer:failed',v_customer_route);
    perform public.enqueue_booking_notification(v_owner,v_booking.id,'owner_payment_failed','Payment failed',v_booking.booking_ref,'payment',new.id||':owner:failed',v_owner_route);
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."notify_hall_payment_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_booking_requests"() RETURNS TABLE("id" "uuid", "booking_ref" "text", "venue_id" "uuid", "hall_name" "text", "book_date" "date", "start_time" time without time zone, "end_time" time without time zone, "amount" numeric, "total_amount" numeric, "workflow_status" "text", "approval_deadline" timestamp with time zone, "owner_decision_at" timestamp with time zone, "rejection_reason" "text", "customer_name" "text", "customer_phone" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.bookings b set workflow_status='expired',status='cancelled',cancelled_at=now()
    where b.workflow_status='requested' and b.approval_deadline<=now()
    and exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
      where v.id=b.venue_id and o.owner_user_id=auth.uid());
  return query select b.id,b.booking_ref,b.venue_id,v.name,b.book_date,b.start_time,b.end_time,b.amount,b.total_amount,
    b.workflow_status,b.approval_deadline,b.owner_decision_at,b.rejection_reason,
    coalesce(b.metadata->>'customer_name',p.full_name,p.email,'Customer'),
    coalesce(b.metadata->>'customer_phone',p.phone,''),b.created_at
  from public.bookings b join public.venues v on v.id=b.venue_id join public.organizations o on o.id=v.org_id
  left join public.profiles p on p.id=b.user_id where o.owner_user_id=auth.uid()
    and b.workflow_status in ('requested','expired','approved','payment_pending','paid','confirmed','rejected')
  order by case when b.workflow_status='requested' then 0 else 1 end,b.created_at desc;
end $$;


ALTER FUNCTION "public"."owner_booking_requests"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_copy_day_availability"("p_venue_id" "uuid", "p_source" "date", "p_targets" "date"[]) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare d date;n integer:=0;source_blocked boolean;
begin
  if not exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  source_blocked:=exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_source);
  foreach d in array p_targets loop
    delete from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=d;
    delete from public.venue_slot_blocks where venue_id=p_venue_id and blocked_date=d;
    if source_blocked then insert into public.venue_blocked_dates(venue_id,blocked_date,reason) values(p_venue_id,d,'Copied availability'); end if;
    insert into public.venue_slot_blocks(venue_id,slot_id,blocked_date,reason)
      select venue_id,slot_id,d,'Copied availability' from public.venue_slot_blocks
      where venue_id=p_venue_id and blocked_date=p_source;
    n:=n+1;
  end loop; return n;
end $$;


ALTER FUNCTION "public"."owner_copy_day_availability"("p_venue_id" "uuid", "p_source" "date", "p_targets" "date"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_day_slots"("p_venue_id" "uuid", "p_book_date" "date") RETURNS TABLE("slot_id" "uuid", "label" "text", "start_time" time without time zone, "end_time" time without time zone, "price_amount" numeric, "is_active" boolean, "status" "text", "booking_id" "uuid", "booking_ref" "text", "customer_name" "text", "customer_phone" "text", "workflow_status" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  with allowed as (select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()), availability as (
    select * from public.available_time_slots(p_venue_id,p_book_date)
  )
  select s.id,s.label,s.start_time,s.end_time,s.price_amount,s.is_active,a.reason,
    b.id,b.booking_ref,coalesce(b.metadata->>'customer_name',p.full_name,p.email),
    coalesce(b.metadata->>'customer_phone',p.phone),b.workflow_status
  from public.time_slots s join allowed on true join availability a on a.slot_id=s.id
  left join lateral (select x.* from public.bookings x where x.venue_id=p_venue_id and x.book_date=p_book_date
    and x.status in ('held','pending','confirmed','completed') and x.start_time<s.end_time and x.end_time>s.start_time
    order by x.created_at desc limit 1) b on true left join public.profiles p on p.id=b.user_id
  where s.venue_id=p_venue_id order by s.start_time;
$$;


ALTER FUNCTION "public"."owner_day_slots"("p_venue_id" "uuid", "p_book_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_total numeric;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select b.total_amount into v_total from public.bookings b where b.id=p_booking_id and b.workflow_status='requested'
    and (b.approval_deadline is null or b.approval_deadline>now()) and exists(select 1 from public.venues v
      join public.organizations o on o.id=v.org_id where v.id=b.venue_id and o.owner_user_id=auth.uid()) for update;
  if not found then raise exception 'booking not found, expired or not permitted'; end if;
  update public.bookings set owner_decision_at=now(),approval_deadline=null,
    workflow_status=case when not p_accept then 'rejected' when v_total=0 then 'confirmed' else 'payment_pending' end,
    status=case when not p_accept then 'cancelled'::public.booking_status when v_total=0 then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when p_accept and v_total=0 then now() else null end,
    cancelled_at=case when not p_accept then now() else null end where id=p_booking_id;
end $$;


ALTER FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean, "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_total numeric;v_deadline timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select b.total_amount,b.approval_deadline into v_total,v_deadline from public.bookings b
    where b.id=p_booking_id and b.workflow_status='requested' and exists(select 1 from public.venues v
      join public.organizations o on o.id=v.org_id where v.id=b.venue_id and o.owner_user_id=auth.uid()) for update;
  if not found then raise exception 'request already handled or not permitted' using errcode='P0001'; end if;
  if v_deadline is not null and v_deadline<=now() then
    update public.bookings set workflow_status='expired',status='cancelled',cancelled_at=now() where id=p_booking_id;
    raise exception 'approval request expired' using errcode='P0001';
  end if;
  if not p_accept and nullif(trim(coalesce(p_reason,'')),'') is null then
    raise exception 'rejection reason required' using errcode='22023';
  end if;
  update public.bookings set owner_decision_at=now(),approval_deadline=null,
    rejection_reason=case when p_accept then null else trim(p_reason) end,
    workflow_status=case when not p_accept then 'rejected' when v_total=0 then 'confirmed' else 'payment_pending' end,
    status=case when not p_accept then 'cancelled'::public.booking_status when v_total=0 then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when p_accept and v_total=0 then now() else null end,
    cancelled_at=case when not p_accept then now() else null end where id=p_booking_id;
end $$;


ALTER FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_set_date_block"("p_venue_id" "uuid", "p_date" "date", "p_blocked" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  if not exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  if p_blocked then insert into public.venue_blocked_dates(venue_id,blocked_date,reason)
    values(p_venue_id,p_date,'Owner blocked') on conflict(venue_id,blocked_date) do update set reason=excluded.reason;
  else delete from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_date; end if;
end $$;


ALTER FUNCTION "public"."owner_set_date_block"("p_venue_id" "uuid", "p_date" "date", "p_blocked" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."owner_set_slot_block"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_date" "date", "p_blocked" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  if not exists(select 1 from public.time_slots s join public.venues v on v.id=s.venue_id
    join public.organizations o on o.id=v.org_id where s.id=p_slot_id and s.venue_id=p_venue_id
    and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  if p_blocked then insert into public.venue_slot_blocks(venue_id,slot_id,blocked_date,reason)
    values(p_venue_id,p_slot_id,p_date,'Owner blocked') on conflict(slot_id,blocked_date) do nothing;
  else delete from public.venue_slot_blocks where slot_id=p_slot_id and blocked_date=p_date; end if;
end $$;


ALTER FUNCTION "public"."owner_set_slot_block"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_date" "date", "p_blocked" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."publish_registration_form"("p_template_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_version int;begin
 select current_version into v_version from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')) for update;if not found then raise exception 'not permitted' using errcode='42501';end if;
 update public.registration_form_versions set published_at=coalesce(published_at,now()) where template_id=p_template_id and version=v_version;
 update public.registration_form_templates set status='published',updated_at=now() where id=p_template_id;end$$;


ALTER FUNCTION "public"."publish_registration_form"("p_template_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reconcile_stale_payments"("p_stale_after_minutes" integer DEFAULT 30) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
declare
  v_count integer := 0;
begin
  update public.payments
  set status = 'failed', updated_at = now()
  where status = 'pending'
    and created_at < now() - make_interval(mins => p_stale_after_minutes);
  get diagnostics v_count = row_count;
  return v_count;
end $$;


ALTER FUNCTION "public"."reconcile_stale_payments"("p_stale_after_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_for_event"("p_event_id" "uuid", "p_user_id" "uuid", "p_quantity" integer DEFAULT 1) RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_capacity integer;
  v_ticket_price numeric(12,2);
  v_registration_id uuid;
  v_lock_key bigint;
begin
  -- Only published, not-yet-finished events can be registered for.
  select capacity, ticket_price into v_capacity, v_ticket_price
  from public.events
  where id = p_event_id and status = 'published' and ends_at > now();
  if not found then
    raise exception 'event not available' using errcode = 'P0001';
  end if;

  if p_quantity < 1 or p_quantity > 50 then
    raise exception 'invalid quantity' using errcode = '22023';
  end if;

  -- Serialize concurrent registrations for the same event.
  v_lock_key := hashtextextended('event:' || p_event_id::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- Capacity check counts live (non-cancelled) registrations.
  if (select coalesce(sum(quantity), 0)
      from public.event_registrations
      where event_id = p_event_id and status = 'registered')
     + p_quantity > v_capacity then
    raise exception 'event full' using errcode = 'P0001';
  end if;

  insert into public.event_registrations (
    event_id, user_id, quantity, total_amount, status
  ) values (
    p_event_id, p_user_id, p_quantity,
    round(coalesce(v_ticket_price, 0) * p_quantity, 2),
    'registered'
  )
  on conflict (event_id, user_id) do update
    set quantity = excluded.quantity,
        total_amount = excluded.total_amount,
        status = 'registered',
        updated_at = now()
  returning id into v_registration_id;

  return v_registration_id;
end $$;


ALTER FUNCTION "public"."register_for_event"("p_event_id" "uuid", "p_user_id" "uuid", "p_quantity" integer) OWNER TO "postgres";




CREATE OR REPLACE FUNCTION "public"."register_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.webhook_events (provider, event_id, event_type, payload)
  values (p_provider, p_event_id, p_event_type, p_payload)
  on conflict (provider, event_id) do nothing;
  return found;
end $$;


ALTER FUNCTION "public"."register_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registration_immutable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$begin raise exception 'registration snapshots are immutable' using errcode='42501';end$$;


ALTER FUNCTION "public"."registration_immutable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registration_version_immutable"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$begin
 if tg_op='DELETE' then raise exception 'form versions are immutable' using errcode='42501';end if;
 if old.template_id<>new.template_id or old.version<>new.version or old.schema<>new.schema or old.created_by<>new.created_by or old.created_at<>new.created_at or old.published_at is not null then raise exception 'form versions are immutable' using errcode='42501';end if;return new;end$$;


ALTER FUNCTION "public"."registration_version_immutable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reject_blocked_hall_hold"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  if exists(select 1 from public.venue_blocked_dates where venue_id=new.venue_id and blocked_date=new.book_date)
    or exists(select 1 from public.venue_slot_blocks where slot_id=new.slot_id and blocked_date=new.book_date) then
    raise exception 'slot unavailable' using errcode='P0001';
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."reject_blocked_hall_hold"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reserve_accommodation"("p_property_id" "uuid", "p_unit_id" "uuid", "p_move_in" "date" DEFAULT NULL::"date", "p_check_in" "date" DEFAULT NULL::"date", "p_check_out" "date" DEFAULT NULL::"date", "p_guests" integer DEFAULT 1) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_user uuid := auth.uid();
  v_module text;
  v_inventory integer;
  v_price numeric(12,2);
  v_reserved bigint;
  v_id uuid;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if p_guests < 1 then raise exception 'invalid guest count'; end if;

  perform pg_advisory_xact_lock(hashtext(p_unit_id::text));
  select p.module, u.inventory,
    case when p.module = 'pg' then u.rent_monthly else u.price_nightly end
  into v_module, v_inventory, v_price
  from public.accommodation_properties p
  join public.accommodation_units u on u.property_id = p.id
  where p.id = p_property_id and u.id = p_unit_id
    and p.is_active and u.is_active
    and u.available_from <= coalesce(p_move_in, p_check_in);

  if not found then raise exception 'unit unavailable'; end if;

  if v_module = 'pg' then
    if p_move_in is null or p_move_in < current_date then
      raise exception 'invalid move-in date';
    end if;
    select count(*) into v_reserved
      from public.accommodation_reservations
      where unit_id = p_unit_id and status in ('reserved','confirmed');
  else
    if p_check_in is null or p_check_out is null or p_check_in < current_date or p_check_out <= p_check_in then
      raise exception 'invalid stay dates';
    end if;
    select count(*) into v_reserved
      from public.accommodation_reservations
      where unit_id = p_unit_id and status in ('reserved','confirmed')
        and check_in < p_check_out and check_out > p_check_in;
  end if;

  if v_reserved >= v_inventory then raise exception 'unit unavailable'; end if;

  insert into public.accommodation_reservations (
    user_id, property_id, unit_id, module, move_in_date,
    check_in, check_out, guests, amount
  ) values (
    v_user, p_property_id, p_unit_id, v_module, p_move_in,
    p_check_in, p_check_out, p_guests,
    case when v_module = 'pg' then v_price
      else v_price * (p_check_out - p_check_in) end
  ) returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."reserve_accommodation"("p_property_id" "uuid", "p_unit_id" "uuid", "p_move_in" "date", "p_check_in" "date", "p_check_out" "date", "p_guests" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reviews_rating_trigger"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.update_venue_rating(new.venue_id);
  end if;
  if tg_op = 'DELETE' then
    perform public.update_venue_rating(old.venue_id);
  end if;
  return null;
end;
$$;


ALTER FUNCTION "public"."reviews_rating_trigger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_invoice_config"("p_config" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.owner_profiles where user_id=v_uid) and not public.has_role(v_uid,'administrator') then raise exception 'owner or admin required' using errcode='42501';end if;
 if jsonb_typeof(p_config)<>'object' then raise exception 'invalid config' using errcode='22023';end if;
 insert into public.invoice_configs(owner_user_id,config) values(v_uid,p_config)
 on conflict(owner_user_id) do update set config=excluded.config,updated_at=now();
end$$;


ALTER FUNCTION "public"."save_invoice_config"("p_config" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_owner_profile"("p_name" "text", "p_phone" "text" DEFAULT NULL::"text", "p_whatsapp" "text" DEFAULT NULL::"text", "p_business_name" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_city" "text" DEFAULT NULL::"text", "p_state" "text" DEFAULT NULL::"text", "p_latitude" double precision DEFAULT NULL::double precision, "p_longitude" double precision DEFAULT NULL::double precision, "p_photo_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare v_uid uuid:=auth.uid(); v_email text; v_org uuid;
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  select email into v_email from auth.users where id=v_uid;
  if nullif(trim(p_name),'') is null then raise exception 'name required'; end if;
  insert into public.owner_profiles(user_id,email,name,phone,whatsapp,photo_url)
  values(v_uid,v_email,trim(p_name),p_phone,p_whatsapp,p_photo_url)
  on conflict(user_id) do update set name=excluded.name,phone=excluded.phone,
    whatsapp=excluded.whatsapp,photo_url=excluded.photo_url,updated_at=now();
  insert into public.profiles(id,full_name,phone,email,avatar_url)
  values(v_uid,trim(p_name),p_phone,v_email,p_photo_url)
  on conflict(id) do update set full_name=excluded.full_name,phone=excluded.phone,
    avatar_url=excluded.avatar_url,updated_at=now();
  insert into public.user_roles(user_id,role) values(v_uid,'venue_owner')
  on conflict(user_id,role) do update set revoked_at=null;
  select id into v_org from public.organizations where owner_user_id=v_uid and deleted_at is null limit 1;
  if v_org is null then
    insert into public.organizations(owner_user_id,org_type,name,address_line1,city,state,latitude,longitude)
    values(v_uid,'venue_owner',coalesce(nullif(trim(p_business_name),''),trim(p_name)),p_address,p_city,p_state,p_latitude,p_longitude)
    returning id into v_org;
  else
    update public.organizations set
      name=coalesce(nullif(trim(p_business_name),''),name),address_line1=p_address,
      city=p_city,state=p_state,latitude=p_latitude,longitude=p_longitude,updated_at=now()
    where id=v_org;
  end if;
  update public.profiles set default_org_id=v_org where id=v_uid;
  return public.get_owner_profile();
end; $$;


ALTER FUNCTION "public"."save_owner_profile"("p_name" "text", "p_phone" "text", "p_whatsapp" "text", "p_business_name" "text", "p_address" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_photo_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_registration_form_version"("p_template_id" "uuid", "p_schema" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_version int;begin
 perform 1 from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')) for update;if not found then raise exception 'not permitted' using errcode='42501';end if;
 select coalesce(max(version),0)+1 into v_version from public.registration_form_versions where template_id=p_template_id;
 insert into public.registration_form_versions(template_id,version,schema,created_by)values(p_template_id,v_version,p_schema,v_uid);
 update public.registration_form_templates set current_version=v_version,status='draft',updated_at=now() where id=p_template_id;return v_version;end$$;


ALTER FUNCTION "public"."save_registration_form_version"("p_template_id" "uuid", "p_schema" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end $$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sports_venue_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare r public.sports_venue_profiles;v_end time;v_day smallint;v_open time;v_close time;v_price numeric;v_available bool:=true;
begin
 select * into r from public.sports_venue_profiles where venue_id=p_venue_id;
 if not found or p_duration_minutes<r.min_duration_minutes or mod(p_duration_minutes,r.booking_increment_minutes)<>0 then return jsonb_build_object('available',false,'reason','Invalid duration');end if;
 v_end:=p_start_time+make_interval(mins=>p_duration_minutes);if v_end<=p_start_time then return jsonb_build_object('available',false,'reason','Booking must end the same day');end if;
 v_day:=((extract(dow from p_book_date)::int+6)%7)::smallint;
 select opens_at,closes_at into v_open,v_close from public.venue_operating_hours where venue_id=p_venue_id and day_of_week=v_day and not is_closed;
 if not found or p_start_time<v_open or v_end>v_close then v_available:=false;end if;
 if exists(select 1 from public.sports_venue_breaks where venue_id=p_venue_id and day_of_week=v_day and (p_start_time,v_end) overlaps(start_time,end_time)) then v_available:=false;end if;
 if exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_book_date) then v_available:=false;end if;
 if exists(select 1 from public.bookings b where b.venue_id=p_venue_id and b.book_date=p_book_date and b.status in ('held','pending','confirmed','completed')
  and (p_start_time,v_end) overlaps(b.start_time-make_interval(mins=>r.buffer_minutes),b.end_time+make_interval(mins=>r.buffer_minutes))) then v_available:=false;end if;
 v_price:=case when p_duration_minutes=r.session_minutes then r.session_rate else ceil(p_duration_minutes/30.0)*(r.hourly_rate/2) end;
 return jsonb_build_object('available',v_available,'end_time',v_end,'price',round(v_price,2),'currency','INR');
end $$;


ALTER FUNCTION "public"."sports_venue_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_registration_form"("p_template_id" "uuid", "p_booking_id" "uuid", "p_payload" "jsonb", "p_participant_index" integer DEFAULT 0, "p_participant_scope" "text" DEFAULT 'primary'::"text", "p_collection_stage" "text" DEFAULT 'pre_booking'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_version public.registration_form_versions;f jsonb;v_key text;v_value jsonb;v_id uuid;begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 select v.* into v_version from public.registration_form_versions v join public.registration_form_templates t on t.id=v.template_id where t.id=p_template_id and t.status='published' and v.version=t.current_version and v.published_at is not null;
 if not found then raise exception 'published form not found';end if;
 if p_booking_id is not null and not exists(select 1 from public.bookings where id=p_booking_id and user_id=v_uid)then raise exception 'booking not permitted' using errcode='42501';end if;
 for f in select * from jsonb_array_elements(coalesce(v_version.schema->'fields','[]'))loop
  if coalesce((f->>'enabled')::bool,true)=false then continue;end if;
  if coalesce(f->>'collection_stage','pre_booking')<>p_collection_stage then continue;end if;
  if coalesce(f->>'participant_scope','primary')='primary' and p_participant_index>0 then continue;end if;
  v_key:=f->>'key';v_value:=p_payload->v_key;
  if coalesce((f->>'required')::bool,false) and(v_value is null or v_value='null'::jsonb or v_value='""'::jsonb)then raise exception 'required field: %',v_key using errcode='22023';end if;
  if v_value is not null and f->>'type'='number' then begin perform(v_value#>>'{}')::numeric;exception when others then raise exception 'invalid number: %',v_key using errcode='22023';end;end if;
  if v_value is not null and coalesce(f#>>'{validation,pattern}','')<>'' and(v_value#>>'{}')!~(f#>>'{validation,pattern}')then raise exception 'invalid field: %',v_key using errcode='22023';end if;
 end loop;
 insert into public.registration_submissions(template_id,form_version_id,booking_id,module_key,subject_user_id,submitted_by,participant_index,participant_scope,collection_stage,payload)
 select p_template_id,v_version.id,p_booking_id,t.module_key,v_uid,v_uid,p_participant_index,p_participant_scope,p_collection_stage,p_payload from public.registration_form_templates t where t.id=p_template_id returning id into v_id;return v_id;end$$;


ALTER FUNCTION "public"."submit_registration_form"("p_template_id" "uuid", "p_booking_id" "uuid", "p_payload" "jsonb", "p_participant_index" integer, "p_participant_scope" "text", "p_collection_stage" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_booking_commerce_reference"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_module text;v_owner uuid;v_org uuid;v_name text;begin
 select case when exists(select 1 from meeting_room_profiles where venue_id=new.venue_id)then 'meetings' when exists(select 1 from sports_venue_profiles where venue_id=new.venue_id)then 'sports' else 'function_hall' end,o.owner_user_id,o.id,v.name into v_module,v_owner,v_org,v_name from venues v join organizations o on o.id=v.org_id where v.id=new.venue_id;
 insert into commerce_references(module,resource_id,reservation_id,legacy_booking_id,owner_user_id,org_id,customer_user_id,amount,currency,booking_status,payment_status,metadata)values(v_module,new.venue_id,new.id,new.id,v_owner,v_org,new.user_id,new.total_amount,new.currency,new.workflow_status,case when new.total_amount=0 and new.workflow_status='confirmed'then 'free' else 'unpaid'end,coalesce(new.metadata,'{}'::jsonb)||jsonb_build_object('booking_ref',new.booking_ref,'book_date',new.book_date,'start_time',new.start_time,'end_time',new.end_time,'resource_name',v_name))on conflict(module,reservation_id)do update set amount=excluded.amount,booking_status=excluded.booking_status,metadata=excluded.metadata,updated_at=now();return new;end$$;


ALTER FUNCTION "public"."sync_booking_commerce_reference"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_stay_commerce_reference"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_owner uuid;v_org uuid;v_name text;begin select o.owner_user_id,o.id,p.name into v_owner,v_org,v_name from accommodation_properties p join organizations o on o.id=p.org_id where p.id=new.property_id;insert into commerce_references(module,resource_id,reservation_id,owner_user_id,org_id,customer_user_id,amount,currency,booking_status,payment_status,metadata)values('stays',new.property_id,new.id,v_owner,v_org,new.user_id,new.total,new.currency,new.status,new.payment_status,jsonb_build_object('booking_ref',new.booking_ref,'check_in',new.check_in,'check_out',new.check_out,'adults',new.adults,'children',new.children,'resource_name',v_name))on conflict(module,reservation_id)do update set amount=excluded.amount,booking_status=excluded.booking_status,payment_status=excluded.payment_status,metadata=excluded.metadata,updated_at=now();return new;end$$;


ALTER FUNCTION "public"."sync_stay_commerce_reference"() OWNER TO "postgres";




































CREATE OR REPLACE FUNCTION "public"."update_owner_venue"("p_venue_id" "uuid", "p_name" "text" DEFAULT NULL::"text", "p_category_id" "uuid" DEFAULT NULL::"uuid", "p_description" "text" DEFAULT NULL::"text", "p_city" "text" DEFAULT NULL::"text", "p_state" "text" DEFAULT NULL::"text", "p_latitude" double precision DEFAULT NULL::double precision, "p_longitude" double precision DEFAULT NULL::double precision, "p_capacity" integer DEFAULT NULL::integer, "p_pricing_base_amount" numeric DEFAULT NULL::numeric, "p_is_active" boolean DEFAULT NULL::boolean) RETURNS "public"."venues"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare
  v_venue public.venues;
begin
  -- Verify ownership.
  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid();

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set
    name = coalesce(p_name, name),
    category_id = coalesce(p_category_id, category_id),
    description = coalesce(p_description, description),
    city = coalesce(p_city, city),
    state = coalesce(p_state, state),
    latitude = coalesce(p_latitude, latitude),
    longitude = coalesce(p_longitude, longitude),
    capacity = coalesce(p_capacity, capacity),
    pricing_base_amount = coalesce(p_pricing_base_amount, pricing_base_amount),
    is_active = coalesce(p_is_active, is_active),
    slug = case when p_name is not null then lower(replace(p_name, ' ', '-')) else slug end,
    updated_at = now()
  where id = p_venue_id
  returning * into v_venue;

  return v_venue;
end;
$$;


ALTER FUNCTION "public"."update_owner_venue"("p_venue_id" "uuid", "p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric, "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_stay_booking_status"("p_booking_id" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$declare v_uid uuid:=auth.uid();v_current text;v_customer uuid;v_owner uuid;begin
 select b.status,b.user_id,o.owner_user_id into v_current,v_customer,v_owner from stay_bookings b join accommodation_properties p on p.id=b.property_id join organizations o on o.id=p.org_id where b.id=p_booking_id for update;if not found then raise exception 'booking not found';end if;
 if p_status='cancelled' and v_uid=v_customer and v_current in('requested','payment_pending','confirmed') then null;
 elsif v_uid=v_owner or public.has_role(v_uid,'administrator') then if not((v_current='requested' and p_status in('payment_pending','confirmed','rejected'))or(v_current in('payment_pending','confirmed')and p_status in('cancelled','no_show','completed','refunded','partially_refunded')))then raise exception 'invalid transition';end if;
 else raise exception 'not permitted' using errcode='42501';end if;
 update stay_bookings set status=p_status,updated_at=now() where id=p_booking_id;
 if p_status in('rejected','cancelled','refunded')then update stay_booking_rooms set active=false where stay_booking_id=p_booking_id;end if;
end$$;


ALTER FUNCTION "public"."update_stay_booking_status"("p_booking_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_venue_rating"("p_venue_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update public.venues
  set
    avg_rating = coalesce(
      (select avg(r.rating)::numeric(3,2) from public.reviews r where r.venue_id = p_venue_id),
      0
    ),
    rating_count = (
      select count(*)::integer from public.reviews r where r.venue_id = p_venue_id
    ),
    updated_at = now()
  where id = p_venue_id;
end;
$$;


ALTER FUNCTION "public"."update_venue_rating"("p_venue_id" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_properties" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "module" "text" NOT NULL,
    "property_type" "text" NOT NULL,
    "gender_policy" "text",
    "name" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "address" "text" DEFAULT ''::"text" NOT NULL,
    "city" "text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "cover_image" "text",
    "amenities" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "food_included" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "photos" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "check_in_time" time without time zone DEFAULT '14:00:00'::time without time zone NOT NULL,
    "check_out_time" time without time zone DEFAULT '11:00:00'::time without time zone NOT NULL,
    "booking_mode" "text" DEFAULT 'instant'::"text" NOT NULL,
    "stay_rules" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "registration_form_id" "uuid",
    CONSTRAINT "accommodation_gender_check" CHECK (((("module" = 'pg'::"text") AND ("gender_policy" IS NOT NULL)) OR (("module" = 'stay'::"text") AND ("gender_policy" IS NULL)))),
    CONSTRAINT "accommodation_properties_booking_mode_check" CHECK (("booking_mode" = ANY (ARRAY['instant'::"text", 'approval'::"text"]))),
    CONSTRAINT "accommodation_properties_gender_policy_check" CHECK (("gender_policy" = ANY (ARRAY['men'::"text", 'women'::"text", 'unisex'::"text"]))),
    CONSTRAINT "accommodation_properties_module_check" CHECK (("module" = ANY (ARRAY['pg'::"text", 'stay'::"text"])))
);


ALTER TABLE "public"."accommodation_properties" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_reservations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "property_id" "uuid" NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "module" "text" NOT NULL,
    "move_in_date" "date",
    "check_in" "date",
    "check_out" "date",
    "guests" integer DEFAULT 1 NOT NULL,
    "amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'reserved'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accommodation_reservation_dates_check" CHECK (((("module" = 'pg'::"text") AND ("move_in_date" IS NOT NULL) AND ("check_in" IS NULL) AND ("check_out" IS NULL)) OR (("module" = 'stay'::"text") AND ("move_in_date" IS NULL) AND ("check_in" IS NOT NULL) AND ("check_out" > "check_in")))),
    CONSTRAINT "accommodation_reservations_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "accommodation_reservations_guests_check" CHECK (("guests" > 0)),
    CONSTRAINT "accommodation_reservations_module_check" CHECK (("module" = ANY (ARRAY['pg'::"text", 'stay'::"text"]))),
    CONSTRAINT "accommodation_reservations_status_check" CHECK (("status" = ANY (ARRAY['reserved'::"text", 'confirmed'::"text", 'cancelled'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."accommodation_reservations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "property_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "occupancy_type" "text" NOT NULL,
    "capacity" integer DEFAULT 1 NOT NULL,
    "inventory" integer DEFAULT 1 NOT NULL,
    "rent_monthly" numeric(12,2),
    "price_nightly" numeric(12,2),
    "deposit" numeric(12,2) DEFAULT 0 NOT NULL,
    "available_from" "date" DEFAULT CURRENT_DATE NOT NULL,
    "amenities" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "photos" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "max_adults" integer DEFAULT 2 NOT NULL,
    "max_children" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "accommodation_unit_price_check" CHECK (((("rent_monthly" IS NOT NULL) AND ("price_nightly" IS NULL)) OR (("rent_monthly" IS NULL) AND ("price_nightly" IS NOT NULL)))),
    CONSTRAINT "accommodation_units_capacity_check" CHECK (("capacity" > 0)),
    CONSTRAINT "accommodation_units_deposit_check" CHECK (("deposit" >= (0)::numeric)),
    CONSTRAINT "accommodation_units_inventory_check" CHECK (("inventory" > 0)),
    CONSTRAINT "accommodation_units_max_adults_check" CHECK (("max_adults" > 0)),
    CONSTRAINT "accommodation_units_max_children_check" CHECK (("max_children" >= 0)),
    CONSTRAINT "accommodation_units_price_nightly_check" CHECK (("price_nightly" >= (0)::numeric)),
    CONSTRAINT "accommodation_units_rent_monthly_check" CHECK (("rent_monthly" >= (0)::numeric))
);


ALTER TABLE "public"."accommodation_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."accommodation_visits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "property_id" "uuid" NOT NULL,
    "visit_at" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'scheduled'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accommodation_visits_status_check" CHECK (("status" = ANY (ARRAY['scheduled'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."accommodation_visits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."analytics_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "session_id" "uuid",
    "event_type" "text" NOT NULL,
    "properties" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."analytics_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "actor_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "details" "jsonb" DEFAULT '{}'::"jsonb",
    "ip_address" "text",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs_archive" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text",
    "entity_id" "uuid",
    "details" "jsonb",
    "ip_address" "text",
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_logs_archive" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."booking_coupons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "coupon_id" "uuid" NOT NULL,
    "discount_amount" numeric(12,2) NOT NULL,
    CONSTRAINT "booking_coupons_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric))
);


ALTER TABLE "public"."booking_coupons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."booking_holds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "idempotency_key" "uuid" NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "slot_id" "uuid" NOT NULL,
    "book_date" "date" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "price_amount" numeric(12,2) NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "booking_holds_price_amount_check" CHECK (("price_amount" >= (0)::numeric)),
    CONSTRAINT "booking_holds_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'confirmed'::"text", 'expired'::"text", 'released'::"text"])))
);


ALTER TABLE "public"."booking_holds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_ref" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "slot_id" "uuid" NOT NULL,
    "book_date" "date" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "hold_id" "uuid",
    "status" "public"."booking_status" DEFAULT 'pending'::"public"."booking_status" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'INR'::"text" NOT NULL,
    "tax_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_amount" numeric(12,2) NOT NULL,
    "cancellation_policy" "jsonb",
    "metadata" "jsonb",
    "confirmed_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "workflow_status" "text" DEFAULT 'payment_pending'::"text" NOT NULL,
    "approval_deadline" timestamp with time zone,
    "receipt_number" "text",
    "owner_decision_at" timestamp with time zone,
    "rejection_reason" "text",
    CONSTRAINT "bookings_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "bookings_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric)),
    CONSTRAINT "bookings_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "bookings_tax_amount_check" CHECK (("tax_amount" >= (0)::numeric)),
    CONSTRAINT "bookings_total_amount_check" CHECK (("total_amount" >= (0)::numeric)),
    CONSTRAINT "bookings_workflow_status_check" CHECK (("workflow_status" = ANY (ARRAY['requested'::"text", 'held'::"text", 'approved'::"text", 'payment_pending'::"text", 'paid'::"text", 'confirmed'::"text", 'completed'::"text", 'rejected'::"text", 'cancelled'::"text", 'expired'::"text", 'blocked'::"text"])))
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commerce_references" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module" "text" NOT NULL,
    "reference_type" "text" DEFAULT 'booking'::"text" NOT NULL,
    "resource_id" "uuid" NOT NULL,
    "reservation_id" "uuid" NOT NULL,
    "legacy_booking_id" "uuid",
    "owner_user_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "customer_user_id" "uuid" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "currency" "text" DEFAULT 'INR'::"text" NOT NULL,
    "booking_status" "text" NOT NULL,
    "payment_status" "text" DEFAULT 'unpaid'::"text" NOT NULL,
    "refund_status" "text" DEFAULT 'none'::"text" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "commerce_references_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."commerce_references" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."coupons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "description" "text",
    "discount_type" "text" NOT NULL,
    "discount_value" numeric(12,2) NOT NULL,
    "max_discount_amount" numeric(12,2),
    "min_booking_amount" numeric(12,2) DEFAULT 0,
    "max_uses" integer,
    "max_uses_per_user" integer DEFAULT 1,
    "starts_at" timestamp with time zone,
    "ends_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "coupons_discount_type_check" CHECK (("discount_type" = ANY (ARRAY['percentage'::"text", 'fixed'::"text"]))),
    CONSTRAINT "coupons_discount_value_check" CHECK (("discount_value" > (0)::numeric))
);


ALTER TABLE "public"."coupons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."course_batches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "course_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "starts_on" "date" NOT NULL,
    "capacity" integer NOT NULL,
    "enrolled_count" integer DEFAULT 0 NOT NULL,
    "timetable" "jsonb",
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "course_batches_capacity_check" CHECK (("capacity" > 0)),
    CONSTRAINT "course_batches_enrolled_count_check" CHECK (("enrolled_count" >= 0))
);


ALTER TABLE "public"."course_batches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."course_enrollments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "batch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'enrolled'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "course_enrollments_status_check" CHECK (("status" = ANY (ARRAY['enrolled'::"text", 'dropped'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."course_enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."courses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "institute_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "mode" "public"."course_mode" DEFAULT 'offline'::"public"."course_mode" NOT NULL,
    "venue_id" "uuid",
    "duration_weeks" integer NOT NULL,
    "fee_amount" numeric(12,2) NOT NULL,
    "instructor_name" "text",
    "cover_image" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "courses_duration_weeks_check" CHECK (("duration_weeks" > 0)),
    CONSTRAINT "courses_fee_amount_check" CHECK (("fee_amount" >= (0)::numeric)),
    CONSTRAINT "courses_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."courses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crash_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "session_id" "uuid",
    "error_message" "text" NOT NULL,
    "stack_trace" "text",
    "platform" "text" DEFAULT 'flutter'::"text" NOT NULL,
    "version" "text" DEFAULT '1.0.0'::"text" NOT NULL,
    "properties" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."crash_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "token" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."disputes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "resolution" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "disputes_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'investigating'::"text", 'resolved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."disputes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "total_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'registered'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "event_registrations_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "event_registrations_status_check" CHECK (("status" = ANY (ARRAY['registered'::"text", 'cancelled'::"text", 'checked_in'::"text"]))),
    CONSTRAINT "event_registrations_total_amount_check" CHECK (("total_amount" >= (0)::numeric))
);


ALTER TABLE "public"."event_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "venue_id" "uuid",
    "category" "public"."event_category" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "capacity" integer,
    "ticket_price" numeric(12,2) DEFAULT 0,
    "is_free" boolean DEFAULT false NOT NULL,
    "cover_image" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "events_capacity_check" CHECK (("capacity" > 0)),
    CONSTRAINT "events_check" CHECK (("ends_at" > "starts_at")),
    CONSTRAINT "events_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'cancelled'::"text", 'completed'::"text"]))),
    CONSTRAINT "events_ticket_price_check" CHECK (("ticket_price" >= (0)::numeric))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."favorites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."favorites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hall_booking_settings" (
    "venue_id" "uuid" NOT NULL,
    "booking_mode" "text" DEFAULT 'instant'::"text" NOT NULL,
    "min_notice_minutes" integer DEFAULT 0 NOT NULL,
    "max_advance_days" integer DEFAULT 365 NOT NULL,
    "instant_book_window_hours" integer DEFAULT 48 NOT NULL,
    "approval_timeout_minutes" integer DEFAULT 1440 NOT NULL,
    "checkout_hold_minutes" integer DEFAULT 10 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hall_booking_settings_approval_timeout_minutes_check" CHECK ((("approval_timeout_minutes" >= 5) AND ("approval_timeout_minutes" <= 10080))),
    CONSTRAINT "hall_booking_settings_booking_mode_check" CHECK (("booking_mode" = ANY (ARRAY['instant'::"text", 'approval'::"text", 'hybrid'::"text"]))),
    CONSTRAINT "hall_booking_settings_checkout_hold_minutes_check" CHECK ((("checkout_hold_minutes" >= 2) AND ("checkout_hold_minutes" <= 30))),
    CONSTRAINT "hall_booking_settings_instant_book_window_hours_check" CHECK (("instant_book_window_hours" >= 0)),
    CONSTRAINT "hall_booking_settings_max_advance_days_check" CHECK ((("max_advance_days" >= 1) AND ("max_advance_days" <= 730))),
    CONSTRAINT "hall_booking_settings_min_notice_minutes_check" CHECK (("min_notice_minutes" >= 0))
);


ALTER TABLE "public"."hall_booking_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."institutes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "logo_image" "text",
    "is_verified" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."institutes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoice_configs" (
    "owner_user_id" "uuid" NOT NULL,
    "config" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "next_number" bigint DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "invoice_configs_config_check" CHECK (("jsonb_typeof"("config") = 'object'::"text")),
    CONSTRAINT "invoice_configs_next_number_check" CHECK (("next_number" > 0))
);


ALTER TABLE "public"."invoice_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid" NOT NULL,
    "customer_user_id" "uuid" NOT NULL,
    "booking_id" "uuid",
    "parent_invoice_id" "uuid",
    "document_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "sequence_number" bigint NOT NULL,
    "invoice_number" "text" NOT NULL,
    "currency" "text" NOT NULL,
    "subtotal" numeric(14,2) NOT NULL,
    "discount" numeric(14,2) DEFAULT 0 NOT NULL,
    "tax_total" numeric(14,2) DEFAULT 0 NOT NULL,
    "fee_total" numeric(14,2) DEFAULT 0 NOT NULL,
    "total" numeric(14,2) NOT NULL,
    "paid" numeric(14,2) DEFAULT 0 NOT NULL,
    "due" numeric(14,2) DEFAULT 0 NOT NULL,
    "refund" numeric(14,2) DEFAULT 0 NOT NULL,
    "config_snapshot" "jsonb" NOT NULL,
    "invoice_snapshot" "jsonb" NOT NULL,
    "issued_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "commerce_reference_id" "uuid",
    CONSTRAINT "invoices_config_snapshot_check" CHECK (("jsonb_typeof"("config_snapshot") = 'object'::"text")),
    CONSTRAINT "invoices_discount_check" CHECK (("discount" >= (0)::numeric)),
    CONSTRAINT "invoices_document_type_check" CHECK (("document_type" = ANY (ARRAY['receipt'::"text", 'tax_invoice'::"text", 'credit_note'::"text"]))),
    CONSTRAINT "invoices_fee_total_check" CHECK (("fee_total" >= (0)::numeric)),
    CONSTRAINT "invoices_invoice_snapshot_check" CHECK (("jsonb_typeof"("invoice_snapshot") = 'object'::"text")),
    CONSTRAINT "invoices_paid_check" CHECK (("paid" >= (0)::numeric)),
    CONSTRAINT "invoices_refund_check" CHECK (("refund" >= (0)::numeric)),
    CONSTRAINT "invoices_status_check" CHECK (("status" = ANY (ARRAY['issued'::"text", 'cancelled'::"text", 'refunded'::"text", 'partially_refunded'::"text"]))),
    CONSTRAINT "invoices_subtotal_check" CHECK (("subtotal" >= (0)::numeric)),
    CONSTRAINT "invoices_tax_total_check" CHECK (("tax_total" >= (0)::numeric)),
    CONSTRAINT "invoices_total_check" CHECK (("total" >= (0)::numeric))
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meeting_booking_idempotency" (
    "user_id" "uuid" NOT NULL,
    "idempotency_key" "uuid" NOT NULL,
    "occurrence_date" "date" NOT NULL,
    "booking_id" "uuid" NOT NULL
);


ALTER TABLE "public"."meeting_booking_idempotency" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meeting_room_breaks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "day_of_week" smallint NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "label" "text" DEFAULT 'Break'::"text" NOT NULL,
    CONSTRAINT "meeting_room_breaks_check" CHECK (("end_time" > "start_time")),
    CONSTRAINT "meeting_room_breaks_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6)))
);


ALTER TABLE "public"."meeting_room_breaks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meeting_room_profiles" (
    "venue_id" "uuid" NOT NULL,
    "room_type" "text" NOT NULL,
    "hourly_rate" numeric(12,2) NOT NULL,
    "half_day_rate" numeric(12,2) NOT NULL,
    "full_day_rate" numeric(12,2) NOT NULL,
    "min_duration_minutes" integer DEFAULT 60 NOT NULL,
    "booking_increment_minutes" integer DEFAULT 30 NOT NULL,
    "buffer_minutes" integer DEFAULT 15 NOT NULL,
    "booking_mode" "text" DEFAULT 'instant'::"text" NOT NULL,
    "instant_book_window_hours" integer DEFAULT 48 NOT NULL,
    "approval_timeout_minutes" integer DEFAULT 1440 NOT NULL,
    "amenities" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "meeting_room_profiles_booking_increment_minutes_check" CHECK (("booking_increment_minutes" = ANY (ARRAY[30, 60]))),
    CONSTRAINT "meeting_room_profiles_booking_mode_check" CHECK (("booking_mode" = ANY (ARRAY['instant'::"text", 'approval'::"text", 'hybrid'::"text"]))),
    CONSTRAINT "meeting_room_profiles_buffer_minutes_check" CHECK ((("buffer_minutes" >= 0) AND ("buffer_minutes" <= 240))),
    CONSTRAINT "meeting_room_profiles_full_day_rate_check" CHECK (("full_day_rate" >= (0)::numeric)),
    CONSTRAINT "meeting_room_profiles_half_day_rate_check" CHECK (("half_day_rate" >= (0)::numeric)),
    CONSTRAINT "meeting_room_profiles_hourly_rate_check" CHECK (("hourly_rate" >= (0)::numeric)),
    CONSTRAINT "meeting_room_profiles_min_duration_minutes_check" CHECK (("min_duration_minutes" >= 30)),
    CONSTRAINT "meeting_room_profiles_room_type_check" CHECK (("room_type" = ANY (ARRAY['meeting'::"text", 'conference'::"text", 'training'::"text"])))
);


ALTER TABLE "public"."meeting_room_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "user_id" "uuid" NOT NULL,
    "booking_updates" boolean DEFAULT true NOT NULL,
    "payment_updates" boolean DEFAULT true NOT NULL,
    "reminders" boolean DEFAULT true NOT NULL,
    "in_app" boolean DEFAULT true NOT NULL,
    "push" boolean DEFAULT false NOT NULL,
    "email" boolean DEFAULT false NOT NULL,
    "sms" boolean DEFAULT false NOT NULL,
    "whatsapp" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "read_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dedupe_key" "text"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications_archive" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text",
    "data" "jsonb",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dedupe_key" "text"
);


ALTER TABLE "public"."notifications_archive" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid" NOT NULL,
    "org_type" "public"."org_type" NOT NULL,
    "name" "text" NOT NULL,
    "legal_name" "text",
    "gstin" "text",
    "pan" "text",
    "address_line1" "text",
    "address_line2" "text",
    "city" "text",
    "state" "text",
    "postal_code" "text",
    "country" "text" DEFAULT 'IN'::"text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "identity_verification" "public"."verification_status" DEFAULT 'pending'::"public"."verification_status" NOT NULL,
    "business_verification" "public"."verification_status" DEFAULT 'pending'::"public"."verification_status" NOT NULL,
    "verification_docs" "jsonb",
    "commission_rate" numeric(5,2) DEFAULT 10.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "organizations_commission_rate_check" CHECK ((("commission_rate" >= (0)::numeric) AND ("commission_rate" <= (100)::numeric)))
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."owner_bank_accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "account_holder" "text" NOT NULL,
    "bank_name" "text" NOT NULL,
    "account_number_encrypted" "text" NOT NULL,
    "ifsc_code" "text" NOT NULL,
    "upi_id" "text",
    "is_verified" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."owner_bank_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."owner_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone" "text",
    "whatsapp" "text",
    "photo_url" "text"
);


ALTER TABLE "public"."owner_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "provider_attempt_id" "text",
    "status" "public"."payment_status" DEFAULT 'pending'::"public"."payment_status" NOT NULL,
    "error_code" "text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."payment_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "provider" "text" DEFAULT 'razorpay'::"text" NOT NULL,
    "provider_order_id" "text",
    "provider_payment_id" "text",
    "amount" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'INR'::"text" NOT NULL,
    "status" "public"."payment_status" DEFAULT 'pending'::"public"."payment_status" NOT NULL,
    "method" "text",
    "is_refundable" boolean DEFAULT true NOT NULL,
    "metadata" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "commerce_reference_id" "uuid",
    CONSTRAINT "payments_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "payments_reference_required" CHECK ((("commerce_reference_id" IS NOT NULL) OR ("booking_id" IS NOT NULL)))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payouts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "org_id" "uuid" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "commission_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'requested'::"text" NOT NULL,
    "provider" "text" DEFAULT 'razorpay'::"text",
    "provider_payout_id" "text",
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "processed_at" timestamp with time zone,
    CONSTRAINT "payouts_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "payouts_status_check" CHECK (("status" = ANY (ARRAY['requested'::"text", 'approved'::"text", 'processing'::"text", 'paid'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."payouts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."platform_commissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid" NOT NULL,
    "org_id" "uuid" NOT NULL,
    "commission_rate" numeric(5,2) NOT NULL,
    "commission_amount" numeric(12,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."platform_commissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pricing_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "day_of_week" smallint,
    "start_date" "date",
    "end_date" "date",
    "price_multiplier" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "is_seasonal" boolean DEFAULT false NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "pricing_rules_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6))),
    CONSTRAINT "pricing_rules_price_multiplier_check" CHECK (("price_multiplier" > (0)::numeric))
);


ALTER TABLE "public"."pricing_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "full_name" "text",
    "phone" "text",
    "email" "text",
    "avatar_url" "text",
    "locale" "text" DEFAULT 'en'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "default_org_id" "uuid"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."refunds" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "payment_id" "uuid" NOT NULL,
    "booking_id" "uuid",
    "amount" numeric(12,2) NOT NULL,
    "reason" "text",
    "status" "text" DEFAULT 'requested'::"text" NOT NULL,
    "provider_refund_id" "text",
    "processed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "commerce_reference_id" "uuid",
    CONSTRAINT "refunds_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "refunds_reference_required" CHECK ((("commerce_reference_id" IS NOT NULL) OR ("booking_id" IS NOT NULL))),
    CONSTRAINT "refunds_status_check" CHECK (("status" = ANY (ARRAY['requested'::"text", 'approved'::"text", 'processed'::"text", 'rejected'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."refunds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registration_form_bindings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "module_key" "text" NOT NULL,
    "resource_id" "uuid",
    "template_id" "uuid" NOT NULL,
    "collection_stage" "text" DEFAULT 'pre_booking'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."registration_form_bindings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registration_form_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "module_key" "text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "current_version" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "registration_form_templates_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."registration_form_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registration_form_versions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid" NOT NULL,
    "version" integer NOT NULL,
    "schema" "jsonb" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "published_at" timestamp with time zone,
    CONSTRAINT "registration_form_versions_schema_check" CHECK (("jsonb_typeof"("schema") = 'object'::"text")),
    CONSTRAINT "registration_form_versions_version_check" CHECK (("version" > 0))
);


ALTER TABLE "public"."registration_form_versions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registration_submission_files" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "submission_id" "uuid" NOT NULL,
    "field_key" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "original_name" "text" NOT NULL,
    "mime_type" "text",
    "size_bytes" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "registration_submission_files_size_bytes_check" CHECK ((("size_bytes" >= 1) AND ("size_bytes" <= 10485760)))
);


ALTER TABLE "public"."registration_submission_files" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registration_submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid" NOT NULL,
    "form_version_id" "uuid" NOT NULL,
    "booking_id" "uuid",
    "module_key" "text" NOT NULL,
    "subject_user_id" "uuid" NOT NULL,
    "submitted_by" "uuid" NOT NULL,
    "participant_index" integer DEFAULT 0 NOT NULL,
    "participant_scope" "text" DEFAULT 'primary'::"text" NOT NULL,
    "collection_stage" "text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "registration_submissions_participant_index_check" CHECK (("participant_index" >= 0)),
    CONSTRAINT "registration_submissions_participant_scope_check" CHECK (("participant_scope" = ANY (ARRAY['primary'::"text", 'all'::"text"])))
);


ALTER TABLE "public"."registration_submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "rating" smallint NOT NULL,
    "title" "text",
    "body" "text",
    "owner_reply" "text",
    "owner_replied_at" timestamp with time zone,
    "is_verified" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sports_booking_idempotency" (
    "user_id" "uuid" NOT NULL,
    "idempotency_key" "uuid" NOT NULL,
    "occurrence_date" "date" NOT NULL,
    "booking_id" "uuid" NOT NULL
);


ALTER TABLE "public"."sports_booking_idempotency" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sports_venue_breaks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "day_of_week" smallint NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "label" "text" DEFAULT 'Break'::"text" NOT NULL,
    CONSTRAINT "sports_venue_breaks_check" CHECK (("end_time" > "start_time")),
    CONSTRAINT "sports_venue_breaks_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6)))
);


ALTER TABLE "public"."sports_venue_breaks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sports_venue_profiles" (
    "venue_id" "uuid" NOT NULL,
    "sport_type" "text" NOT NULL,
    "hourly_rate" numeric(12,2) NOT NULL,
    "session_minutes" integer DEFAULT 60 NOT NULL,
    "session_rate" numeric(12,2) NOT NULL,
    "min_duration_minutes" integer DEFAULT 60 NOT NULL,
    "booking_increment_minutes" integer DEFAULT 30 NOT NULL,
    "buffer_minutes" integer DEFAULT 15 NOT NULL,
    "booking_mode" "text" DEFAULT 'instant'::"text" NOT NULL,
    "instant_book_window_hours" integer DEFAULT 48 NOT NULL,
    "approval_timeout_minutes" integer DEFAULT 1440 NOT NULL,
    "equipment" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "amenities" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sports_venue_profiles_booking_increment_minutes_check" CHECK (("booking_increment_minutes" = ANY (ARRAY[30, 60]))),
    CONSTRAINT "sports_venue_profiles_booking_mode_check" CHECK (("booking_mode" = ANY (ARRAY['instant'::"text", 'approval'::"text", 'hybrid'::"text"]))),
    CONSTRAINT "sports_venue_profiles_buffer_minutes_check" CHECK ((("buffer_minutes" >= 0) AND ("buffer_minutes" <= 240))),
    CONSTRAINT "sports_venue_profiles_hourly_rate_check" CHECK (("hourly_rate" >= (0)::numeric)),
    CONSTRAINT "sports_venue_profiles_min_duration_minutes_check" CHECK (("min_duration_minutes" >= 30)),
    CONSTRAINT "sports_venue_profiles_session_minutes_check" CHECK (("session_minutes" >= 30)),
    CONSTRAINT "sports_venue_profiles_session_rate_check" CHECK (("session_rate" >= (0)::numeric)),
    CONSTRAINT "sports_venue_profiles_sport_type_check" CHECK (("sport_type" = ANY (ARRAY['cricket'::"text", 'football'::"text", 'badminton'::"text", 'tennis'::"text", 'turf'::"text", 'indoor'::"text"])))
);


ALTER TABLE "public"."sports_venue_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stay_blocks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "physical_room_id" "uuid" NOT NULL,
    "stay_dates" "daterange" NOT NULL,
    "reason" "text" DEFAULT ''::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stay_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stay_booking_rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stay_booking_id" "uuid" NOT NULL,
    "physical_room_id" "uuid" NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "nightly_rate" numeric(12,2) NOT NULL,
    "stay_dates" "daterange" NOT NULL,
    "active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."stay_booking_rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stay_bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_ref" "text" DEFAULT ('STY-'::"text" || "upper"("substr"("replace"(("gen_random_uuid"())::"text", '-'::"text", ''::"text"), 1, 10))) NOT NULL,
    "idempotency_key" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "property_id" "uuid" NOT NULL,
    "check_in" "date" NOT NULL,
    "check_out" "date" NOT NULL,
    "adults" integer NOT NULL,
    "children" integer DEFAULT 0 NOT NULL,
    "status" "text" NOT NULL,
    "currency" "text" DEFAULT 'INR'::"text" NOT NULL,
    "subtotal" numeric(12,2) NOT NULL,
    "discount" numeric(12,2) DEFAULT 0 NOT NULL,
    "tax_total" numeric(12,2) DEFAULT 0 NOT NULL,
    "fee_total" numeric(12,2) DEFAULT 0 NOT NULL,
    "total" numeric(12,2) NOT NULL,
    "payment_status" "text" DEFAULT 'unpaid'::"text" NOT NULL,
    "registration_submission_id" "uuid",
    "is_offline" boolean DEFAULT false NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stay_bookings_adults_check" CHECK (("adults" > 0)),
    CONSTRAINT "stay_bookings_check" CHECK (("check_out" > "check_in")),
    CONSTRAINT "stay_bookings_children_check" CHECK (("children" >= 0)),
    CONSTRAINT "stay_bookings_status_check" CHECK (("status" = ANY (ARRAY['requested'::"text", 'payment_pending'::"text", 'confirmed'::"text", 'rejected'::"text", 'cancelled'::"text", 'completed'::"text", 'no_show'::"text", 'refunded'::"text", 'partially_refunded'::"text"])))
);


ALTER TABLE "public"."stay_bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stay_physical_rooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "room_code" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stay_physical_rooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stay_rates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "nightly_rate" numeric(12,2) NOT NULL,
    "taxes" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "fees" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "discount" numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT "stay_rates_check" CHECK (("end_date" >= "start_date")),
    CONSTRAINT "stay_rates_discount_check" CHECK (("discount" >= (0)::numeric)),
    CONSTRAINT "stay_rates_nightly_rate_check" CHECK (("nightly_rate" >= (0)::numeric))
);


ALTER TABLE "public"."stay_rates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_ticket_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ticket_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."support_ticket_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "subject" "text" NOT NULL,
    "category" "text",
    "description" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "priority" "text" DEFAULT 'medium'::"text" NOT NULL,
    "assigned_to" "uuid",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "admin_reply" "text",
    "admin_id" "uuid",
    CONSTRAINT "support_tickets_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "support_tickets_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."support_tickets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."time_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "price_amount" numeric(12,2) NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "time_slots_price_amount_check" CHECK (("price_amount" >= (0)::numeric))
);


ALTER TABLE "public"."time_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."user_role" DEFAULT 'customer'::"public"."user_role" NOT NULL,
    "granted_by" "uuid",
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_blocked_dates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "blocked_date" "date" NOT NULL,
    "reason" "text"
);


ALTER TABLE "public"."venue_blocked_dates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "name" "text" NOT NULL,
    "icon" "text"
);


ALTER TABLE "public"."venue_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_facilities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "facility" "text" NOT NULL,
    "is_available" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."venue_facilities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "thumbnail_url" "text",
    "alt_text" "text",
    "is_cover" boolean DEFAULT false NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."venue_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_operating_hours" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "venue_id" "uuid" NOT NULL,
    "day_of_week" smallint NOT NULL,
    "opens_at" time without time zone NOT NULL,
    "closes_at" time without time zone NOT NULL,
    "is_closed" boolean DEFAULT false NOT NULL,
    CONSTRAINT "venue_operating_hours_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6)))
);


ALTER TABLE "public"."venue_operating_hours" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_slot_blocks" (
    "venue_id" "uuid" NOT NULL,
    "slot_id" "uuid" NOT NULL,
    "blocked_date" "date" NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."venue_slot_blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."webhook_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "provider" "text" NOT NULL,
    "event_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "processed" boolean DEFAULT false NOT NULL,
    "processed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "last_error" "text",
    "processing_started_at" timestamp with time zone
);


ALTER TABLE "public"."webhook_events" OWNER TO "postgres";


ALTER TABLE ONLY "public"."accommodation_properties"
    ADD CONSTRAINT "accommodation_properties_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_reservations"
    ADD CONSTRAINT "accommodation_reservations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_units"
    ADD CONSTRAINT "accommodation_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."accommodation_visits"
    ADD CONSTRAINT "accommodation_visits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."analytics_events"
    ADD CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs_archive"
    ADD CONSTRAINT "audit_logs_archive_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."booking_coupons"
    ADD CONSTRAINT "booking_coupons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."booking_holds"
    ADD CONSTRAINT "booking_holds_idempotency_key_key" UNIQUE ("idempotency_key");



ALTER TABLE ONLY "public"."booking_holds"
    ADD CONSTRAINT "booking_holds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_booking_ref_key" UNIQUE ("booking_ref");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_no_overlap" EXCLUDE USING "gist" ("venue_id" WITH =, "book_date" WITH =, "tsrange"(("book_date" + "start_time"), ("book_date" + "end_time"), '[)'::"text") WITH &&) WHERE (("status" = ANY (ARRAY['held'::"public"."booking_status", 'pending'::"public"."booking_status", 'confirmed'::"public"."booking_status", 'completed'::"public"."booking_status"])));



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_receipt_number_key" UNIQUE ("receipt_number");



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_legacy_booking_id_key" UNIQUE ("legacy_booking_id");



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_module_reservation_id_key" UNIQUE ("module", "reservation_id");



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."coupons"
    ADD CONSTRAINT "coupons_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."coupons"
    ADD CONSTRAINT "coupons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."course_batches"
    ADD CONSTRAINT "course_batches_course_id_label_starts_on_key" UNIQUE ("course_id", "label", "starts_on");



ALTER TABLE ONLY "public"."course_batches"
    ADD CONSTRAINT "course_batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_batch_id_user_id_key" UNIQUE ("batch_id", "user_id");



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."crash_reports"
    ADD CONSTRAINT "crash_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_user_id_venue_id_key" UNIQUE ("user_id", "venue_id");



ALTER TABLE ONLY "public"."hall_booking_settings"
    ADD CONSTRAINT "hall_booking_settings_pkey" PRIMARY KEY ("venue_id");



ALTER TABLE ONLY "public"."institutes"
    ADD CONSTRAINT "institutes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoice_configs"
    ADD CONSTRAINT "invoice_configs_pkey" PRIMARY KEY ("owner_user_id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_owner_user_id_invoice_number_key" UNIQUE ("owner_user_id", "invoice_number");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_owner_user_id_sequence_number_key" UNIQUE ("owner_user_id", "sequence_number");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meeting_booking_idempotency"
    ADD CONSTRAINT "meeting_booking_idempotency_pkey" PRIMARY KEY ("user_id", "idempotency_key", "occurrence_date");



ALTER TABLE ONLY "public"."meeting_room_breaks"
    ADD CONSTRAINT "meeting_room_breaks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meeting_room_profiles"
    ADD CONSTRAINT "meeting_room_profiles_pkey" PRIMARY KEY ("venue_id");



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_notification_id_channel_key" UNIQUE ("notification_id", "channel");



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notifications_archive"
    ADD CONSTRAINT "notifications_archive_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."owner_bank_accounts"
    ADD CONSTRAINT "owner_bank_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."owner_profiles"
    ADD CONSTRAINT "owner_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."owner_profiles"
    ADD CONSTRAINT "owner_profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."payment_attempts"
    ADD CONSTRAINT "payment_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_provider_provider_order_id_key" UNIQUE ("provider", "provider_order_id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."platform_commissions"
    ADD CONSTRAINT "platform_commissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pricing_rules"
    ADD CONSTRAINT "pricing_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_phone_key" UNIQUE ("phone");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."refunds"
    ADD CONSTRAINT "refunds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registration_form_bindings"
    ADD CONSTRAINT "registration_form_bindings_module_key_resource_id_collectio_key" UNIQUE NULLS NOT DISTINCT ("module_key", "resource_id", "collection_stage");



ALTER TABLE ONLY "public"."registration_form_bindings"
    ADD CONSTRAINT "registration_form_bindings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registration_form_templates"
    ADD CONSTRAINT "registration_form_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registration_form_versions"
    ADD CONSTRAINT "registration_form_versions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registration_form_versions"
    ADD CONSTRAINT "registration_form_versions_template_id_version_key" UNIQUE ("template_id", "version");



ALTER TABLE ONLY "public"."registration_submission_files"
    ADD CONSTRAINT "registration_submission_files_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registration_submission_files"
    ADD CONSTRAINT "registration_submission_files_storage_path_key" UNIQUE ("storage_path");



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_booking_id_key" UNIQUE ("booking_id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sports_booking_idempotency"
    ADD CONSTRAINT "sports_booking_idempotency_pkey" PRIMARY KEY ("user_id", "idempotency_key", "occurrence_date");



ALTER TABLE ONLY "public"."sports_venue_breaks"
    ADD CONSTRAINT "sports_venue_breaks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sports_venue_profiles"
    ADD CONSTRAINT "sports_venue_profiles_pkey" PRIMARY KEY ("venue_id");



ALTER TABLE ONLY "public"."stay_blocks"
    ADD CONSTRAINT "stay_blocks_physical_room_id_stay_dates_excl" EXCLUDE USING "gist" ("physical_room_id" WITH =, "stay_dates" WITH &&);



ALTER TABLE ONLY "public"."stay_blocks"
    ADD CONSTRAINT "stay_blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stay_booking_rooms"
    ADD CONSTRAINT "stay_booking_rooms_physical_room_id_stay_dates_excl" EXCLUDE USING "gist" ("physical_room_id" WITH =, "stay_dates" WITH &&) WHERE ("active");



ALTER TABLE ONLY "public"."stay_booking_rooms"
    ADD CONSTRAINT "stay_booking_rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_booking_ref_key" UNIQUE ("booking_ref");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_user_id_idempotency_key_key" UNIQUE ("user_id", "idempotency_key");



ALTER TABLE ONLY "public"."stay_physical_rooms"
    ADD CONSTRAINT "stay_physical_rooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stay_physical_rooms"
    ADD CONSTRAINT "stay_physical_rooms_unit_id_room_code_key" UNIQUE ("unit_id", "room_code");



ALTER TABLE ONLY "public"."stay_rates"
    ADD CONSTRAINT "stay_rates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stay_rates"
    ADD CONSTRAINT "stay_rates_unit_id_start_date_end_date_key" UNIQUE ("unit_id", "start_date", "end_date");



ALTER TABLE ONLY "public"."support_ticket_messages"
    ADD CONSTRAINT "support_ticket_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."time_slots"
    ADD CONSTRAINT "time_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."time_slots"
    ADD CONSTRAINT "time_slots_venue_id_start_time_end_time_key" UNIQUE ("venue_id", "start_time", "end_time");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_role_key" UNIQUE ("user_id", "role");



ALTER TABLE ONLY "public"."venue_blocked_dates"
    ADD CONSTRAINT "venue_blocked_dates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_blocked_dates"
    ADD CONSTRAINT "venue_blocked_dates_venue_id_blocked_date_key" UNIQUE ("venue_id", "blocked_date");



ALTER TABLE ONLY "public"."venue_categories"
    ADD CONSTRAINT "venue_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_categories"
    ADD CONSTRAINT "venue_categories_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."venue_facilities"
    ADD CONSTRAINT "venue_facilities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_facilities"
    ADD CONSTRAINT "venue_facilities_venue_id_facility_key" UNIQUE ("venue_id", "facility");



ALTER TABLE ONLY "public"."venue_images"
    ADD CONSTRAINT "venue_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_operating_hours"
    ADD CONSTRAINT "venue_operating_hours_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_operating_hours"
    ADD CONSTRAINT "venue_operating_hours_venue_id_day_of_week_key" UNIQUE ("venue_id", "day_of_week");



ALTER TABLE ONLY "public"."venue_slot_blocks"
    ADD CONSTRAINT "venue_slot_blocks_pkey" PRIMARY KEY ("slot_id", "blocked_date");



ALTER TABLE ONLY "public"."venues"
    ADD CONSTRAINT "venues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_events"
    ADD CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."webhook_events"
    ADD CONSTRAINT "webhook_events_provider_event_id_key" UNIQUE ("provider", "event_id");



CREATE INDEX "accommodation_properties_module_city_idx" ON "public"."accommodation_properties" USING "btree" ("module", "city") WHERE "is_active";



CREATE INDEX "accommodation_reservations_inventory_idx" ON "public"."accommodation_reservations" USING "btree" ("unit_id", "status", "check_in", "check_out");



CREATE INDEX "accommodation_units_property_idx" ON "public"."accommodation_units" USING "btree" ("property_id") WHERE "is_active";



CREATE INDEX "audit_logs_archive_entity_type_entity_id_idx" ON "public"."audit_logs_archive" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "audit_logs_archive_user_id_created_at_idx" ON "public"."audit_logs_archive" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "commerce_customer_idx" ON "public"."commerce_references" USING "btree" ("customer_user_id", "created_at" DESC);



CREATE INDEX "commerce_owner_idx" ON "public"."commerce_references" USING "btree" ("owner_user_id", "created_at" DESC);



CREATE INDEX "idx_analytics_event_type" ON "public"."analytics_events" USING "btree" ("event_type", "created_at");



CREATE INDEX "idx_analytics_user" ON "public"."analytics_events" USING "btree" ("user_id", "created_at");



CREATE INDEX "idx_attempts_payment" ON "public"."payment_attempts" USING "btree" ("payment_id");



CREATE INDEX "idx_audit_entity" ON "public"."audit_logs" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_audit_logs_action" ON "public"."audit_logs" USING "btree" ("action", "created_at");



CREATE INDEX "idx_audit_logs_actor" ON "public"."audit_logs" USING "btree" ("actor_id", "created_at");



CREATE INDEX "idx_batches_course" ON "public"."course_batches" USING "btree" ("course_id") WHERE "is_active";



CREATE INDEX "idx_bookings_status" ON "public"."bookings" USING "btree" ("status");



CREATE INDEX "idx_bookings_user" ON "public"."bookings" USING "btree" ("user_id");



CREATE INDEX "idx_bookings_venue_date" ON "public"."bookings" USING "btree" ("venue_id", "book_date");



CREATE INDEX "idx_bookings_workflow" ON "public"."bookings" USING "btree" ("workflow_status", "approval_deadline");



CREATE INDEX "idx_courses_institute" ON "public"."courses" USING "btree" ("institute_id");



CREATE INDEX "idx_crash_reports_created" ON "public"."crash_reports" USING "btree" ("created_at");



CREATE INDEX "idx_device_tokens_user" ON "public"."device_tokens" USING "btree" ("user_id") WHERE "is_active";



CREATE INDEX "idx_disputes_booking" ON "public"."disputes" USING "btree" ("booking_id");



CREATE INDEX "idx_event_regs_event" ON "public"."event_registrations" USING "btree" ("event_id", "status");



CREATE INDEX "idx_event_regs_user" ON "public"."event_registrations" USING "btree" ("user_id");



CREATE INDEX "idx_events_org" ON "public"."events" USING "btree" ("org_id");



CREATE INDEX "idx_events_starts" ON "public"."events" USING "btree" ("starts_at");



CREATE INDEX "idx_holds_expiry" ON "public"."booking_holds" USING "btree" ("expires_at") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_holds_venue_slot" ON "public"."booking_holds" USING "btree" ("venue_id", "slot_id", "book_date");



CREATE INDEX "idx_notification_delivery_retry" ON "public"."notification_deliveries" USING "btree" ("status", "next_attempt_at") WHERE ("status" = ANY (ARRAY['pending'::"text", 'failed'::"text"]));



CREATE INDEX "idx_notifications_unread" ON "public"."notifications" USING "btree" ("user_id") WHERE ("read" = false);



CREATE INDEX "idx_notifications_user" ON "public"."notifications" USING "btree" ("user_id", "read", "created_at");



CREATE INDEX "idx_orgs_owner" ON "public"."organizations" USING "btree" ("owner_user_id");



CREATE INDEX "idx_orgs_type" ON "public"."organizations" USING "btree" ("org_type");



CREATE INDEX "idx_payments_booking" ON "public"."payments" USING "btree" ("booking_id");



CREATE INDEX "idx_payments_user" ON "public"."payments" USING "btree" ("user_id");



CREATE INDEX "idx_payouts_org" ON "public"."payouts" USING "btree" ("org_id");



CREATE INDEX "idx_profiles_phone" ON "public"."profiles" USING "btree" ("phone") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_refunds_payment" ON "public"."refunds" USING "btree" ("payment_id");



CREATE INDEX "idx_registration_bindings_resource" ON "public"."registration_form_bindings" USING "btree" ("module_key", "resource_id") WHERE "is_active";



CREATE INDEX "idx_registration_submissions_booking" ON "public"."registration_submissions" USING "btree" ("booking_id");



CREATE INDEX "idx_reviews_user" ON "public"."reviews" USING "btree" ("user_id");



CREATE INDEX "idx_reviews_user_id" ON "public"."reviews" USING "btree" ("user_id");



CREATE INDEX "idx_reviews_venue" ON "public"."reviews" USING "btree" ("venue_id");



CREATE INDEX "idx_reviews_venue_id" ON "public"."reviews" USING "btree" ("venue_id");



CREATE INDEX "idx_support_tickets_status" ON "public"."support_tickets" USING "btree" ("status", "created_at");



CREATE INDEX "idx_support_tickets_user" ON "public"."support_tickets" USING "btree" ("user_id", "status");



CREATE INDEX "idx_tickets_user" ON "public"."support_tickets" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_user_roles_user" ON "public"."user_roles" USING "btree" ("user_id");



CREATE INDEX "idx_venue_images_cover" ON "public"."venue_images" USING "btree" ("venue_id", "is_cover");



CREATE INDEX "idx_venues_active" ON "public"."venues" USING "btree" ("latitude", "longitude") WHERE (("deleted_at" IS NULL) AND "is_active");



CREATE INDEX "idx_venues_category" ON "public"."venues" USING "btree" ("category_id");



CREATE INDEX "idx_venues_city" ON "public"."venues" USING "btree" ("city") WHERE (("deleted_at" IS NULL) AND "is_active");



CREATE INDEX "idx_venues_fts" ON "public"."venues" USING "gin" ("search_document");



CREATE INDEX "idx_venues_geog" ON "public"."venues" USING "gist" ("geog");



CREATE INDEX "idx_venues_org" ON "public"."venues" USING "btree" ("org_id");



CREATE INDEX "idx_webhook_processed" ON "public"."webhook_events" USING "btree" ("provider", "processed") WHERE ("processed" = false);



CREATE INDEX "invoices_booking_idx" ON "public"."invoices" USING "btree" ("booking_id");



CREATE INDEX "invoices_commerce_idx" ON "public"."invoices" USING "btree" ("commerce_reference_id");



CREATE INDEX "invoices_customer_idx" ON "public"."invoices" USING "btree" ("customer_user_id", "issued_at" DESC);



CREATE INDEX "notifications_archive_user_id_created_at_idx" ON "public"."notifications_archive" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "notifications_archive_user_id_idx" ON "public"."notifications_archive" USING "btree" ("user_id") WHERE ("is_read" = false);



CREATE INDEX "payments_commerce_idx" ON "public"."payments" USING "btree" ("commerce_reference_id", "created_at" DESC);



CREATE UNIQUE INDEX "reviews_venue_user_unique" ON "public"."reviews" USING "btree" ("venue_id", "user_id");



CREATE UNIQUE INDEX "uq_notifications_dedupe" ON "public"."notifications" USING "btree" ("user_id", "dedupe_key") WHERE ("dedupe_key" IS NOT NULL);



CREATE OR REPLACE TRIGGER "invoices_immutable" BEFORE DELETE OR UPDATE ON "public"."invoices" FOR EACH ROW EXECUTE FUNCTION "public"."invoice_immutable"();



CREATE OR REPLACE TRIGGER "registration_files_immutable" BEFORE DELETE OR UPDATE ON "public"."registration_submission_files" FOR EACH ROW EXECUTE FUNCTION "public"."registration_immutable"();



CREATE OR REPLACE TRIGGER "registration_submissions_immutable" BEFORE DELETE OR UPDATE ON "public"."registration_submissions" FOR EACH ROW EXECUTE FUNCTION "public"."registration_immutable"();



CREATE OR REPLACE TRIGGER "registration_versions_immutable" BEFORE DELETE OR UPDATE ON "public"."registration_form_versions" FOR EACH ROW EXECUTE FUNCTION "public"."registration_version_immutable"();



CREATE OR REPLACE TRIGGER "reviews_rating_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."reviews_rating_trigger"();



CREATE OR REPLACE TRIGGER "sync_booking_commerce" AFTER INSERT OR UPDATE OF "total_amount", "workflow_status" ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."sync_booking_commerce_reference"();



CREATE OR REPLACE TRIGGER "sync_stay_commerce" AFTER INSERT OR UPDATE OF "total", "status", "payment_status" ON "public"."stay_bookings" FOR EACH ROW EXECUTE FUNCTION "public"."sync_stay_commerce_reference"();



CREATE OR REPLACE TRIGGER "trg_bookings_updated_at" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_event_registrations_updated_at" BEFORE UPDATE ON "public"."event_registrations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_hall_booking_notifications" BEFORE INSERT OR UPDATE OF "workflow_status", "status" ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."notify_hall_booking_change"();



CREATE OR REPLACE TRIGGER "trg_hall_payment_notifications" AFTER INSERT OR UPDATE OF "status" ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."notify_hall_payment_change"();



CREATE OR REPLACE TRIGGER "trg_notifications_updated_at" BEFORE UPDATE ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_organizations_updated_at" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_owner_profiles_updated_at" BEFORE UPDATE ON "public"."owner_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_payments_updated_at" BEFORE UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_refunds_updated_at" BEFORE UPDATE ON "public"."refunds" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_reject_blocked_hall_hold" BEFORE INSERT ON "public"."booking_holds" FOR EACH ROW EXECUTE FUNCTION "public"."reject_blocked_hall_hold"();



CREATE OR REPLACE TRIGGER "trg_venues_updated_at" BEFORE UPDATE ON "public"."venues" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."accommodation_properties"
    ADD CONSTRAINT "accommodation_properties_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_properties"
    ADD CONSTRAINT "accommodation_properties_registration_form_id_fkey" FOREIGN KEY ("registration_form_id") REFERENCES "public"."registration_form_templates"("id");



ALTER TABLE ONLY "public"."accommodation_reservations"
    ADD CONSTRAINT "accommodation_reservations_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."accommodation_properties"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."accommodation_reservations"
    ADD CONSTRAINT "accommodation_reservations_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."accommodation_units"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."accommodation_reservations"
    ADD CONSTRAINT "accommodation_reservations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_units"
    ADD CONSTRAINT "accommodation_units_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."accommodation_properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_visits"
    ADD CONSTRAINT "accommodation_visits_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."accommodation_properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accommodation_visits"
    ADD CONSTRAINT "accommodation_visits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."analytics_events"
    ADD CONSTRAINT "analytics_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."booking_coupons"
    ADD CONSTRAINT "booking_coupons_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."booking_coupons"
    ADD CONSTRAINT "booking_coupons_coupon_id_fkey" FOREIGN KEY ("coupon_id") REFERENCES "public"."coupons"("id");



ALTER TABLE ONLY "public"."booking_holds"
    ADD CONSTRAINT "booking_holds_slot_id_fkey" FOREIGN KEY ("slot_id") REFERENCES "public"."time_slots"("id");



ALTER TABLE ONLY "public"."booking_holds"
    ADD CONSTRAINT "booking_holds_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."booking_holds"
    ADD CONSTRAINT "booking_holds_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_hold_id_fkey" FOREIGN KEY ("hold_id") REFERENCES "public"."booking_holds"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_slot_id_fkey" FOREIGN KEY ("slot_id") REFERENCES "public"."time_slots"("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_customer_user_id_fkey" FOREIGN KEY ("customer_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_legacy_booking_id_fkey" FOREIGN KEY ("legacy_booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."commerce_references"
    ADD CONSTRAINT "commerce_references_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."course_batches"
    ADD CONSTRAINT "course_batches_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "public"."courses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "public"."course_batches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."course_enrollments"
    ADD CONSTRAINT "course_enrollments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_institute_id_fkey" FOREIGN KEY ("institute_id") REFERENCES "public"."institutes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."courses"
    ADD CONSTRAINT "courses_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."crash_reports"
    ADD CONSTRAINT "crash_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."disputes"
    ADD CONSTRAINT "disputes_opened_by_fkey" FOREIGN KEY ("opened_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hall_booking_settings"
    ADD CONSTRAINT "hall_booking_settings_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."institutes"
    ADD CONSTRAINT "institutes_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invoice_configs"
    ADD CONSTRAINT "invoice_configs_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_commerce_reference_id_fkey" FOREIGN KEY ("commerce_reference_id") REFERENCES "public"."commerce_references"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_customer_user_id_fkey" FOREIGN KEY ("customer_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_parent_invoice_id_fkey" FOREIGN KEY ("parent_invoice_id") REFERENCES "public"."invoices"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."meeting_booking_idempotency"
    ADD CONSTRAINT "meeting_booking_idempotency_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meeting_booking_idempotency"
    ADD CONSTRAINT "meeting_booking_idempotency_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meeting_room_breaks"
    ADD CONSTRAINT "meeting_room_breaks_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."meeting_room_profiles"("venue_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meeting_room_profiles"
    ADD CONSTRAINT "meeting_room_profiles_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_deliveries"
    ADD CONSTRAINT "notification_deliveries_notification_id_fkey" FOREIGN KEY ("notification_id") REFERENCES "public"."notifications"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."owner_bank_accounts"
    ADD CONSTRAINT "owner_bank_accounts_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."owner_profiles"
    ADD CONSTRAINT "owner_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_attempts"
    ADD CONSTRAINT "payment_attempts_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_commerce_reference_id_fkey" FOREIGN KEY ("commerce_reference_id") REFERENCES "public"."commerce_references"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."payouts"
    ADD CONSTRAINT "payouts_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."platform_commissions"
    ADD CONSTRAINT "platform_commissions_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."platform_commissions"
    ADD CONSTRAINT "platform_commissions_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."pricing_rules"
    ADD CONSTRAINT "pricing_rules_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_default_org_id_fkey" FOREIGN KEY ("default_org_id") REFERENCES "public"."organizations"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."refunds"
    ADD CONSTRAINT "refunds_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."refunds"
    ADD CONSTRAINT "refunds_commerce_reference_id_fkey" FOREIGN KEY ("commerce_reference_id") REFERENCES "public"."commerce_references"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."refunds"
    ADD CONSTRAINT "refunds_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registration_form_bindings"
    ADD CONSTRAINT "registration_form_bindings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."registration_form_bindings"
    ADD CONSTRAINT "registration_form_bindings_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."registration_form_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registration_form_templates"
    ADD CONSTRAINT "registration_form_templates_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registration_form_versions"
    ADD CONSTRAINT "registration_form_versions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."registration_form_versions"
    ADD CONSTRAINT "registration_form_versions_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."registration_form_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registration_submission_files"
    ADD CONSTRAINT "registration_submission_files_submission_id_fkey" FOREIGN KEY ("submission_id") REFERENCES "public"."registration_submissions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_form_version_id_fkey" FOREIGN KEY ("form_version_id") REFERENCES "public"."registration_form_versions"("id");



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_subject_user_id_fkey" FOREIGN KEY ("subject_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_submitted_by_fkey" FOREIGN KEY ("submitted_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."registration_submissions"
    ADD CONSTRAINT "registration_submissions_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."registration_form_templates"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sports_booking_idempotency"
    ADD CONSTRAINT "sports_booking_idempotency_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sports_booking_idempotency"
    ADD CONSTRAINT "sports_booking_idempotency_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sports_venue_breaks"
    ADD CONSTRAINT "sports_venue_breaks_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."sports_venue_profiles"("venue_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sports_venue_profiles"
    ADD CONSTRAINT "sports_venue_profiles_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stay_blocks"
    ADD CONSTRAINT "stay_blocks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."stay_blocks"
    ADD CONSTRAINT "stay_blocks_physical_room_id_fkey" FOREIGN KEY ("physical_room_id") REFERENCES "public"."stay_physical_rooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stay_booking_rooms"
    ADD CONSTRAINT "stay_booking_rooms_physical_room_id_fkey" FOREIGN KEY ("physical_room_id") REFERENCES "public"."stay_physical_rooms"("id");



ALTER TABLE ONLY "public"."stay_booking_rooms"
    ADD CONSTRAINT "stay_booking_rooms_stay_booking_id_fkey" FOREIGN KEY ("stay_booking_id") REFERENCES "public"."stay_bookings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stay_booking_rooms"
    ADD CONSTRAINT "stay_booking_rooms_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."accommodation_units"("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."accommodation_properties"("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_registration_submission_id_fkey" FOREIGN KEY ("registration_submission_id") REFERENCES "public"."registration_submissions"("id");



ALTER TABLE ONLY "public"."stay_bookings"
    ADD CONSTRAINT "stay_bookings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."stay_physical_rooms"
    ADD CONSTRAINT "stay_physical_rooms_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."accommodation_units"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stay_rates"
    ADD CONSTRAINT "stay_rates_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."accommodation_units"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_ticket_messages"
    ADD CONSTRAINT "support_ticket_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."support_ticket_messages"
    ADD CONSTRAINT "support_ticket_messages_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "public"."support_tickets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_assigned_to_fkey" FOREIGN KEY ("assigned_to") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."support_tickets"
    ADD CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."time_slots"
    ADD CONSTRAINT "time_slots_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_granted_by_fkey" FOREIGN KEY ("granted_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_blocked_dates"
    ADD CONSTRAINT "venue_blocked_dates_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_facilities"
    ADD CONSTRAINT "venue_facilities_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_images"
    ADD CONSTRAINT "venue_images_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_operating_hours"
    ADD CONSTRAINT "venue_operating_hours_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_slot_blocks"
    ADD CONSTRAINT "venue_slot_blocks_slot_id_fkey" FOREIGN KEY ("slot_id") REFERENCES "public"."time_slots"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_slot_blocks"
    ADD CONSTRAINT "venue_slot_blocks_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venues"
    ADD CONSTRAINT "venues_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."venue_categories"("id");



ALTER TABLE ONLY "public"."venues"
    ADD CONSTRAINT "venues_org_id_fkey" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated users can insert reviews" ON "public"."reviews" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Reviews are publicly readable" ON "public"."reviews" FOR SELECT USING (true);



CREATE POLICY "Users can delete their own reviews" ON "public"."reviews" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own reviews" ON "public"."reviews" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."accommodation_properties" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_properties_owner_delete" ON "public"."accommodation_properties" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "accommodation_properties"."org_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_properties_owner_insert" ON "public"."accommodation_properties" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "accommodation_properties"."org_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_properties_owner_update" ON "public"."accommodation_properties" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "accommodation_properties"."org_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "accommodation_properties"."org_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_properties_public_read" ON "public"."accommodation_properties" FOR SELECT TO "authenticated", "anon" USING ("is_active");



ALTER TABLE "public"."accommodation_reservations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_reservations_own_read" ON "public"."accommodation_reservations" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."accommodation_units" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_units_owner_delete" ON "public"."accommodation_units" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_properties" "p"
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("p"."id" = "accommodation_units"."property_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_units_owner_insert" ON "public"."accommodation_units" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_properties" "p"
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("p"."id" = "accommodation_units"."property_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_units_owner_update" ON "public"."accommodation_units" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_properties" "p"
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("p"."id" = "accommodation_units"."property_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_properties" "p"
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("p"."id" = "accommodation_units"."property_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "accommodation_units_public_read" ON "public"."accommodation_units" FOR SELECT TO "authenticated", "anon" USING (("is_active" AND (EXISTS ( SELECT 1
   FROM "public"."accommodation_properties" "p"
  WHERE (("p"."id" = "accommodation_units"."property_id") AND "p"."is_active")))));



ALTER TABLE "public"."accommodation_visits" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accommodation_visits_own" ON "public"."accommodation_visits" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "analytics_admin_read" ON "public"."analytics_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."analytics_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "analytics_insert_own" ON "public"."analytics_events" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("auth"."uid"() IS NULL)));



CREATE POLICY "attempts_user_read" ON "public"."payment_attempts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."payments" "p"
  WHERE (("p"."id" = "payment_attempts"."payment_id") AND ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "audit_admin_insert" ON "public"."audit_logs" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



CREATE POLICY "audit_admin_read" ON "public"."audit_logs" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



CREATE POLICY "audit_insert_any_auth" ON "public"."audit_logs" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_logs_archive" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit_read_admin" ON "public"."audit_logs" FOR SELECT USING (("public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



CREATE POLICY "bank_accounts_owner_write" ON "public"."owner_bank_accounts" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "owner_bank_accounts"."org_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "owner_bank_accounts"."org_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "batches_public_read" ON "public"."course_batches" FOR SELECT USING ("is_active");



CREATE POLICY "blocked_dates_owner_write" ON "public"."venue_blocked_dates" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_blocked_dates"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_blocked_dates"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "blocked_dates_public_read" ON "public"."venue_blocked_dates" FOR SELECT USING (true);



ALTER TABLE "public"."booking_coupons" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."booking_holds" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bookings_user_insert" ON "public"."bookings" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "bookings_user_read" ON "public"."bookings" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "bookings"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))));



CREATE POLICY "bookings_user_update_own" ON "public"."bookings" FOR UPDATE USING ((("auth"."uid"() = "user_id") AND ("status" = 'pending'::"public"."booking_status"))) WITH CHECK ((("auth"."uid"() = "user_id") AND ("status" = ANY (ARRAY['cancelled'::"public"."booking_status", 'pending'::"public"."booking_status"]))));



CREATE POLICY "categories_public_read" ON "public"."venue_categories" FOR SELECT USING (true);



CREATE POLICY "commerce_reference_read" ON "public"."commerce_references" FOR SELECT TO "authenticated" USING ((("customer_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



ALTER TABLE "public"."commerce_references" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commissions_admin_read" ON "public"."platform_commissions" FOR SELECT USING (("public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



ALTER TABLE "public"."coupons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "coupons_admin_write" ON "public"."coupons" USING (("public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



CREATE POLICY "coupons_public_read" ON "public"."coupons" FOR SELECT USING (("is_active" AND (("ends_at" IS NULL) OR ("ends_at" > "now"()))));



ALTER TABLE "public"."course_batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."course_enrollments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."courses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "courses_org_write" ON "public"."courses" USING ((EXISTS ( SELECT 1
   FROM ("public"."institutes" "i"
     JOIN "public"."organizations" "o" ON (("o"."id" = "i"."org_id")))
  WHERE (("i"."id" = "courses"."institute_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."institutes" "i"
     JOIN "public"."organizations" "o" ON (("o"."id" = "i"."org_id")))
  WHERE (("i"."id" = "courses"."institute_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "courses_public_read" ON "public"."courses" FOR SELECT USING (("status" = 'published'::"text"));



ALTER TABLE "public"."crash_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "crash_reports_admin_read" ON "public"."crash_reports" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



CREATE POLICY "crash_reports_insert" ON "public"."crash_reports" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("auth"."uid"() IS NULL)));



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_tokens_own" ON "public"."device_tokens" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."disputes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "disputes_own" ON "public"."disputes" USING (("auth"."uid"() = "opened_by")) WITH CHECK (("auth"."uid"() = "opened_by"));



CREATE POLICY "enrollments_own" ON "public"."course_enrollments" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."event_registrations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "event_registrations_org_read" ON "public"."event_registrations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."events" "e"
     JOIN "public"."organizations" "o" ON (("o"."id" = "e"."org_id")))
  WHERE (("e"."id" = "event_registrations"."event_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "event_registrations_own" ON "public"."event_registrations" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "events_org_write" ON "public"."events" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "events"."org_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "events"."org_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "events_public_read" ON "public"."events" FOR SELECT USING (("status" = 'published'::"text"));



ALTER TABLE "public"."favorites" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "favorites_own" ON "public"."favorites" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "form_bindings_owner" ON "public"."registration_form_bindings" TO "authenticated" USING ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))) WITH CHECK ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



CREATE POLICY "form_bindings_read" ON "public"."registration_form_bindings" FOR SELECT TO "authenticated" USING (("is_active" OR ("created_by" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



CREATE POLICY "form_templates_owner" ON "public"."registration_form_templates" TO "authenticated" USING ((("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))) WITH CHECK ((("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



CREATE POLICY "form_templates_read" ON "public"."registration_form_templates" FOR SELECT TO "authenticated" USING ((("status" = 'published'::"text") OR ("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



CREATE POLICY "form_versions_read" ON "public"."registration_form_versions" FOR SELECT TO "authenticated" USING ((("published_at" IS NOT NULL) OR (EXISTS ( SELECT 1
   FROM "public"."registration_form_templates" "t"
  WHERE (("t"."id" = "registration_form_versions"."template_id") AND (("t"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))));



ALTER TABLE "public"."hall_booking_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "hall_settings_owner_insert" ON "public"."hall_booking_settings" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "hall_booking_settings"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "hall_settings_owner_update" ON "public"."hall_booking_settings" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "hall_booking_settings"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "hall_booking_settings"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "hall_settings_public_read" ON "public"."hall_booking_settings" FOR SELECT USING (true);



CREATE POLICY "holds_owner_read" ON "public"."booking_holds" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."institutes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "institutes_org_write" ON "public"."institutes" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "institutes"."org_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "institutes"."org_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "institutes_public_read" ON "public"."institutes" FOR SELECT USING (true);



ALTER TABLE "public"."invoice_configs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "invoice_configs_owner_read" ON "public"."invoice_configs" FOR SELECT TO "authenticated" USING ((("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "invoices_authorized_read" ON "public"."invoices" FOR SELECT TO "authenticated" USING ((("owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("customer_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")));



ALTER TABLE "public"."meeting_booking_idempotency" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "meeting_breaks_owner_write" ON "public"."meeting_room_breaks" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "meeting_room_breaks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "meeting_room_breaks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "meeting_breaks_public_read" ON "public"."meeting_room_breaks" FOR SELECT USING (true);



CREATE POLICY "meeting_idempotency_own_read" ON "public"."meeting_booking_idempotency" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "meeting_profiles_owner_write" ON "public"."meeting_room_profiles" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "meeting_room_profiles"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "meeting_room_profiles"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "meeting_profiles_public_read" ON "public"."meeting_room_profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."venues" "v"
  WHERE (("v"."id" = "meeting_room_profiles"."venue_id") AND "v"."is_active" AND ("v"."deleted_at" IS NULL)))));



ALTER TABLE "public"."meeting_room_breaks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meeting_room_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_own_or_support" ON "public"."support_ticket_messages" USING ((("auth"."uid"() = "sender_id") OR "public"."has_role"("auth"."uid"(), 'support_agent'::"public"."user_role"))) WITH CHECK (("auth"."uid"() = "sender_id"));



ALTER TABLE "public"."notification_deliveries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notification_preferences_own" ON "public"."notification_preferences" TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications_archive" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND COALESCE((("data" ->> 'in_app'::"text"))::boolean, true)));



CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND COALESCE((("data" ->> 'in_app'::"text"))::boolean, true))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND COALESCE((("data" ->> 'in_app'::"text"))::boolean, true)));



ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "organizations_insert_owner" ON "public"."organizations" FOR INSERT WITH CHECK (("auth"."uid"() = "owner_user_id"));



CREATE POLICY "organizations_select_owner_or_admin" ON "public"."organizations" FOR SELECT USING ((("auth"."uid"() = "owner_user_id") OR "public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



CREATE POLICY "organizations_update_owner" ON "public"."organizations" FOR UPDATE USING (("auth"."uid"() = "owner_user_id")) WITH CHECK (("auth"."uid"() = "owner_user_id"));



ALTER TABLE "public"."owner_bank_accounts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."owner_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "owner_profiles_select_own" ON "public"."owner_profiles" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "owner_profiles_update_own" ON "public"."owner_profiles" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."payment_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_user_read" ON "public"."payments" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (EXISTS ( SELECT 1
   FROM (("public"."bookings" "b"
     JOIN "public"."venues" "v" ON (("v"."id" = "b"."venue_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("b"."id" = "payments"."booking_id") AND ("o"."owner_user_id" = "auth"."uid"()))))));



ALTER TABLE "public"."payouts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payouts_owner_read" ON "public"."payouts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "payouts"."org_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



ALTER TABLE "public"."platform_commissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pricing_owner_write" ON "public"."pricing_rules" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "pricing_rules"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "pricing_rules"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "pricing_public_read" ON "public"."pricing_rules" FOR SELECT USING (true);



ALTER TABLE "public"."pricing_rules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select_own_or_admin" ON "public"."profiles" FOR SELECT USING ((("auth"."uid"() = "id") OR "public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'support_agent'::"public"."user_role")));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



ALTER TABLE "public"."refunds" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "refunds_user_read" ON "public"."refunds" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."bookings" "b"
  WHERE (("b"."id" = "refunds"."booking_id") AND ("b"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."registration_form_bindings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."registration_form_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."registration_form_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."registration_submission_files" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."registration_submissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reviews_insert_own" ON "public"."reviews" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "reviews_public_read" ON "public"."reviews" FOR SELECT USING (true);



CREATE POLICY "reviews_update_own" ON "public"."reviews" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "slots_owner_write" ON "public"."time_slots" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "time_slots"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "time_slots"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "slots_public_read" ON "public"."time_slots" FOR SELECT USING ("is_active");



ALTER TABLE "public"."sports_booking_idempotency" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sports_breaks_owner" ON "public"."sports_venue_breaks" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "sports_venue_breaks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "sports_venue_breaks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "sports_breaks_read" ON "public"."sports_venue_breaks" FOR SELECT USING (true);



CREATE POLICY "sports_idempotency_own" ON "public"."sports_booking_idempotency" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "sports_profiles_owner" ON "public"."sports_venue_profiles" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "sports_venue_profiles"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "sports_venue_profiles"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "sports_profiles_read" ON "public"."sports_venue_profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."venues" "v"
  WHERE (("v"."id" = "sports_venue_profiles"."venue_id") AND "v"."is_active" AND ("v"."deleted_at" IS NULL)))));



ALTER TABLE "public"."sports_venue_breaks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sports_venue_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stay_blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stay_blocks_owner_read" ON "public"."stay_blocks" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ((("public"."stay_physical_rooms" "r"
     JOIN "public"."accommodation_units" "u" ON (("u"."id" = "r"."unit_id")))
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("r"."id" = "stay_blocks"."physical_room_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



CREATE POLICY "stay_blocks_owner_write" ON "public"."stay_blocks" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ((("public"."stay_physical_rooms" "r"
     JOIN "public"."accommodation_units" "u" ON (("u"."id" = "r"."unit_id")))
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("r"."id" = "stay_blocks"."physical_room_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((("public"."stay_physical_rooms" "r"
     JOIN "public"."accommodation_units" "u" ON (("u"."id" = "r"."unit_id")))
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("r"."id" = "stay_blocks"."physical_room_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



ALTER TABLE "public"."stay_booking_rooms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stay_booking_rooms_read" ON "public"."stay_booking_rooms" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."stay_bookings" "b"
  WHERE (("b"."id" = "stay_booking_rooms"."stay_booking_id") AND (("b"."user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
           FROM ("public"."accommodation_properties" "p"
             JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
          WHERE (("p"."id" = "b"."property_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))))))));



ALTER TABLE "public"."stay_bookings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stay_bookings_read" ON "public"."stay_bookings" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM ("public"."accommodation_properties" "p"
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("p"."id" = "stay_bookings"."property_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))));



ALTER TABLE "public"."stay_physical_rooms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stay_rates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stay_rates_owner_write" ON "public"."stay_rates" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("u"."id" = "stay_rates"."unit_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("u"."id" = "stay_rates"."unit_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



CREATE POLICY "stay_rates_public_read" ON "public"."stay_rates" FOR SELECT TO "authenticated", "anon" USING ((EXISTS ( SELECT 1
   FROM ("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
  WHERE (("u"."id" = "stay_rates"."unit_id") AND "p"."is_active"))));



CREATE POLICY "stay_rooms_owner_read" ON "public"."stay_physical_rooms" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("u"."id" = "stay_physical_rooms"."unit_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



CREATE POLICY "stay_rooms_owner_write" ON "public"."stay_physical_rooms" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("u"."id" = "stay_physical_rooms"."unit_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (("public"."accommodation_units" "u"
     JOIN "public"."accommodation_properties" "p" ON (("p"."id" = "u"."property_id")))
     JOIN "public"."organizations" "o" ON (("o"."id" = "p"."org_id")))
  WHERE (("u"."id" = "stay_physical_rooms"."unit_id") AND (("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



CREATE POLICY "submission_files_read" ON "public"."registration_submission_files" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."registration_submissions" "s"
     JOIN "public"."registration_form_templates" "t" ON (("t"."id" = "s"."template_id")))
  WHERE (("s"."id" = "registration_submission_files"."submission_id") AND (("s"."submitted_by" = ( SELECT "auth"."uid"() AS "uid")) OR ("s"."subject_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("t"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role"))))));



CREATE POLICY "submissions_read" ON "public"."registration_submissions" FOR SELECT TO "authenticated" USING ((("submitted_by" = ( SELECT "auth"."uid"() AS "uid")) OR ("subject_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM "public"."registration_form_templates" "t"
  WHERE (("t"."id" = "registration_submissions"."template_id") AND (("t"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."has_role"(( SELECT "auth"."uid"() AS "uid"), 'administrator'::"public"."user_role")))))));



ALTER TABLE "public"."support_ticket_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."support_tickets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tickets_admin_read" ON "public"."support_tickets" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



CREATE POLICY "tickets_admin_write" ON "public"."support_tickets" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"())))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."owner_profiles" "op"
  WHERE ("op"."user_id" = "auth"."uid"()))));



CREATE POLICY "tickets_own" ON "public"."support_tickets" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "tickets_own_or_support" ON "public"."support_tickets" USING ((("auth"."uid"() = "user_id") OR "public"."has_role"("auth"."uid"(), 'support_agent'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role"))) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."time_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_roles_admin_write" ON "public"."user_roles" USING (("public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



CREATE POLICY "user_roles_read_own_or_admin" ON "public"."user_roles" FOR SELECT USING ((("auth"."uid"() = "user_id") OR "public"."has_role"("auth"."uid"(), 'administrator'::"public"."user_role") OR "public"."has_role"("auth"."uid"(), 'super_administrator'::"public"."user_role")));



ALTER TABLE "public"."venue_blocked_dates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."venue_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."venue_facilities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "venue_facilities_owner_write" ON "public"."venue_facilities" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_facilities"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_facilities"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "venue_facilities_public_read" ON "public"."venue_facilities" FOR SELECT USING (true);



CREATE POLICY "venue_hours_owner_write" ON "public"."venue_operating_hours" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_operating_hours"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_operating_hours"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "venue_hours_public_read" ON "public"."venue_operating_hours" FOR SELECT USING (true);



ALTER TABLE "public"."venue_images" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "venue_images_owner_write" ON "public"."venue_images" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_images"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_images"."venue_id") AND ("o"."owner_user_id" = "auth"."uid"())))));



CREATE POLICY "venue_images_public_read" ON "public"."venue_images" FOR SELECT USING (true);



ALTER TABLE "public"."venue_operating_hours" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."venue_slot_blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "venue_slot_blocks_owner_all" ON "public"."venue_slot_blocks" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_slot_blocks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."venues" "v"
     JOIN "public"."organizations" "o" ON (("o"."id" = "v"."org_id")))
  WHERE (("v"."id" = "venue_slot_blocks"."venue_id") AND ("o"."owner_user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."venues" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "venues_owner_write" ON "public"."venues" USING ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "venues"."org_id") AND ("o"."owner_user_id" = "auth"."uid"()) AND ("o"."deleted_at" IS NULL))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."organizations" "o"
  WHERE (("o"."id" = "venues"."org_id") AND ("o"."owner_user_id" = "auth"."uid"()) AND ("o"."deleted_at" IS NULL)))));



CREATE POLICY "venues_public_read" ON "public"."venues" FOR SELECT USING (("is_active" AND ("deleted_at" IS NULL)));



ALTER TABLE "public"."webhook_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "webhook_events_no_client_access" ON "public"."webhook_events" USING (false);



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."acquire_booking_hold_for_current_user"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_idempotency_key" "uuid", "p_hold_minutes" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."acquire_booking_hold_for_current_user"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_idempotency_key" "uuid", "p_hold_minutes" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."apply_commerce_payment"("p_reference_id" "uuid", "p_payment_ref" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."apply_commerce_payment"("p_reference_id" "uuid", "p_payment_ref" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."apply_commerce_refund"("p_reference_id" "uuid", "p_partial" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."apply_commerce_refund"("p_reference_id" "uuid", "p_partial" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."attach_registration_file"("p_submission_id" "uuid", "p_field_key" "text", "p_storage_path" "text", "p_original_name" "text", "p_mime_type" "text", "p_size_bytes" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."attach_registration_file"("p_submission_id" "uuid", "p_field_key" "text", "p_storage_path" "text", "p_original_name" "text", "p_mime_type" "text", "p_size_bytes" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."available_stay_units"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."available_stay_units"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."available_stay_units"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."begin_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."begin_webhook_event"("p_provider" "text", "p_event_id" "text", "p_event_type" "text", "p_payload" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."bind_registration_form"("p_template_id" "uuid", "p_module_key" "text", "p_resource_id" "uuid", "p_collection_stage" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."bind_registration_form"("p_template_id" "uuid", "p_module_key" "text", "p_resource_id" "uuid", "p_collection_stage" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notification_deliveries" TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_notification_deliveries"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_notification_deliveries"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."commerce_receipt"("p_reference_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."commerce_receipt"("p_reference_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."commerce_reference_for_booking"("p_booking_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."commerce_reference_for_booking"("p_booking_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."commerce_reference_for_reservation"("p_module" "text", "p_reservation_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."commerce_reference_for_reservation"("p_module" "text", "p_reservation_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."commerce_status"("p_reference_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."commerce_status"("p_reference_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."commerce_status_for_booking"("p_booking_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."commerce_status_for_booking"("p_booking_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."complete_notification_delivery"("p_delivery_id" "uuid", "p_success" boolean, "p_error" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_notification_delivery"("p_delivery_id" "uuid", "p_success" boolean, "p_error" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."complete_webhook_event"("p_provider" "text", "p_event_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_webhook_event"("p_provider" "text", "p_event_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."confirm_booking"("p_booking_id" "uuid", "p_payment_ref" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."confirm_booking"("p_booking_id" "uuid", "p_payment_ref" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_booking_from_hold"("p_hold_id" "uuid", "p_user_id" "uuid", "p_booking_ref" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_booking_from_hold"("p_hold_id" "uuid", "p_user_id" "uuid", "p_booking_ref" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_booking_from_hold_for_current_user"("p_hold_id" "uuid", "p_booking_ref" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_booking_from_hold_for_current_user"("p_hold_id" "uuid", "p_booking_ref" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_meeting_room"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_room_type" "text", "p_hourly_rate" numeric, "p_half_day_rate" numeric, "p_full_day_rate" numeric, "p_buffer_minutes" integer, "p_amenities" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_meeting_room"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_room_type" "text", "p_hourly_rate" numeric, "p_half_day_rate" numeric, "p_full_day_rate" numeric, "p_buffer_minutes" integer, "p_amenities" "text"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_offline_booking"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_customer_name" "text", "p_customer_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_offline_booking"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_book_date" "date", "p_customer_name" "text", "p_customer_phone" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_offline_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_offline_meeting_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_offline_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_offline_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_customer_name" "text", "p_customer_phone" "text") TO "authenticated";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venues" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venues" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venues" TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_owner_venue"("p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_owner_venue"("p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_registration_form"("p_name" "text", "p_module_key" "text", "p_schema" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_registration_form"("p_name" "text", "p_module_key" "text", "p_schema" "jsonb") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_sports_booking"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer, "p_idempotency_key" "uuid", "p_recurrence_dates" "date"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_sports_venue"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_capacity" integer, "p_sport_type" "text", "p_hourly_rate" numeric, "p_session_minutes" integer, "p_session_rate" numeric, "p_buffer_minutes" integer, "p_equipment" "text"[], "p_amenities" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_sports_venue"("p_name" "text", "p_description" "text", "p_city" "text", "p_state" "text", "p_capacity" integer, "p_sport_type" "text", "p_hourly_rate" numeric, "p_session_minutes" integer, "p_session_rate" numeric, "p_buffer_minutes" integer, "p_equipment" "text"[], "p_amenities" "text"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."create_stay_booking"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer, "p_rooms" "jsonb", "p_idempotency_key" "uuid", "p_registration_submission_id" "uuid", "p_offline_customer" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_stay_booking"("p_property_id" "uuid", "p_check_in" "date", "p_check_out" "date", "p_adults" integer, "p_children" integer, "p_rooms" "jsonb", "p_idempotency_key" "uuid", "p_registration_submission_id" "uuid", "p_offline_customer" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."current_app_role"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_app_role"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."customer_booking_receipt"("p_booking_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."customer_booking_receipt"("p_booking_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."delete_owner_account"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_owner_account"("p_user_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."delete_owner_venue"("p_venue_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_owner_venue"("p_venue_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."enqueue_booking_notification"("p_user_id" "uuid", "p_booking_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_category" "text", "p_dedupe_key" "text", "p_target_route" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."enqueue_upcoming_booking_reminders"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enqueue_upcoming_booking_reminders"() TO "service_role";



GRANT ALL ON FUNCTION "public"."event_detail"("p_event_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."event_detail"("p_event_id" "uuid", "p_user_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."event_summaries"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."event_summaries"("p_user_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."expire_hall_workflows"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."expire_hall_workflows"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."fail_webhook_event"("p_provider" "text", "p_event_id" "text", "p_error" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fail_webhook_event"("p_provider" "text", "p_event_id" "text", "p_error" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_owner_profile"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_owner_profile"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_owner_user_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_owner_user_id"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_owner_venues"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_owner_venues"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."issue_commerce_invoice"("p_reference_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."issue_commerce_invoice"("p_reference_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."issue_invoice"("p_booking_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."issue_invoice"("p_booking_id" "uuid", "p_document_type" "text", "p_invoice" "jsonb", "p_parent_invoice_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."mark_ticket_resolved"("p_ticket_id" "uuid") TO "authenticated";



GRANT ALL ON FUNCTION "public"."meeting_room_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."meeting_room_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."my_enrolled_batches"("p_user_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."notify_hall_booking_change"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."notify_hall_payment_change"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."owner_booking_requests"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_booking_requests"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_copy_day_availability"("p_venue_id" "uuid", "p_source" "date", "p_targets" "date"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_copy_day_availability"("p_venue_id" "uuid", "p_source" "date", "p_targets" "date"[]) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_day_slots"("p_venue_id" "uuid", "p_book_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_day_slots"("p_venue_id" "uuid", "p_book_date" "date") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean, "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_decide_booking"("p_booking_id" "uuid", "p_accept" boolean, "p_reason" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_set_date_block"("p_venue_id" "uuid", "p_date" "date", "p_blocked" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_set_date_block"("p_venue_id" "uuid", "p_date" "date", "p_blocked" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."owner_set_slot_block"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_date" "date", "p_blocked" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."owner_set_slot_block"("p_venue_id" "uuid", "p_slot_id" "uuid", "p_date" "date", "p_blocked" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."publish_registration_form"("p_template_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."publish_registration_form"("p_template_id" "uuid") TO "authenticated";






REVOKE ALL ON FUNCTION "public"."reserve_accommodation"("p_property_id" "uuid", "p_unit_id" "uuid", "p_move_in" "date", "p_check_in" "date", "p_check_out" "date", "p_guests" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."reserve_accommodation"("p_property_id" "uuid", "p_unit_id" "uuid", "p_move_in" "date", "p_check_in" "date", "p_check_out" "date", "p_guests" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."save_invoice_config"("p_config" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_invoice_config"("p_config" "jsonb") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."save_owner_profile"("p_name" "text", "p_phone" "text", "p_whatsapp" "text", "p_business_name" "text", "p_address" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_photo_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_owner_profile"("p_name" "text", "p_phone" "text", "p_whatsapp" "text", "p_business_name" "text", "p_address" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_photo_url" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."save_registration_form_version"("p_template_id" "uuid", "p_schema" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_registration_form_version"("p_template_id" "uuid", "p_schema" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."sports_venue_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."sports_venue_quote"("p_venue_id" "uuid", "p_book_date" "date", "p_start_time" time without time zone, "p_duration_minutes" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."submit_registration_form"("p_template_id" "uuid", "p_booking_id" "uuid", "p_payload" "jsonb", "p_participant_index" integer, "p_participant_scope" "text", "p_collection_stage" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_registration_form"("p_template_id" "uuid", "p_booking_id" "uuid", "p_payload" "jsonb", "p_participant_index" integer, "p_participant_scope" "text", "p_collection_stage" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."sync_booking_commerce_reference"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."sync_stay_commerce_reference"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."update_owner_venue"("p_venue_id" "uuid", "p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric, "p_is_active" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_owner_venue"("p_venue_id" "uuid", "p_name" "text", "p_category_id" "uuid", "p_description" "text", "p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision, "p_capacity" integer, "p_pricing_base_amount" numeric, "p_is_active" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."update_stay_booking_status"("p_booking_id" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_stay_booking_status"("p_booking_id" "uuid", "p_status" "text") TO "authenticated";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_properties" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."accommodation_properties" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_properties" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_reservations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."accommodation_reservations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_reservations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_units" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."accommodation_units" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_units" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_visits" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."accommodation_visits" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."accommodation_visits" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."analytics_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."analytics_events" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."analytics_events" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."audit_logs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."audit_logs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."audit_logs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."audit_logs_archive" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."audit_logs_archive" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."audit_logs_archive" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."booking_coupons" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."booking_coupons" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."booking_coupons" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."booking_holds" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."booking_holds" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."booking_holds" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."bookings" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."bookings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."bookings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."commerce_references" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."commerce_references" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."commerce_references" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."coupons" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."coupons" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."coupons" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."course_batches" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."course_batches" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."course_batches" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."course_enrollments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."course_enrollments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."course_enrollments" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."courses" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."courses" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."courses" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."crash_reports" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."crash_reports" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."crash_reports" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."device_tokens" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."device_tokens" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."device_tokens" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."disputes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."disputes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."disputes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."event_registrations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_registrations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."event_registrations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."events" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."favorites" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."favorites" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."favorites" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."hall_booking_settings" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."hall_booking_settings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."hall_booking_settings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."institutes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."institutes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."institutes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoice_configs" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoice_configs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoice_configs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoices" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."invoices" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."meeting_booking_idempotency" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."meeting_room_breaks" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."meeting_room_breaks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."meeting_room_breaks" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."meeting_room_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."meeting_room_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."meeting_room_profiles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notification_preferences" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notification_preferences" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notifications" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE ON TABLE "public"."notifications" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notifications" TO "service_role";



GRANT UPDATE("read") ON TABLE "public"."notifications" TO "authenticated";



GRANT UPDATE("read_at") ON TABLE "public"."notifications" TO "authenticated";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notifications_archive" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notifications_archive" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."notifications_archive" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."organizations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."organizations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."organizations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."owner_bank_accounts" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."owner_bank_accounts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."owner_bank_accounts" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."owner_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."owner_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."owner_profiles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payment_attempts" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."payment_attempts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payment_attempts" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payments" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."payments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payments" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payouts" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."payouts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."payouts" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."platform_commissions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."platform_commissions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."platform_commissions" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."pricing_rules" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."pricing_rules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."pricing_rules" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."refunds" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."refunds" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."refunds" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_bindings" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."registration_form_bindings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_bindings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_templates" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."registration_form_templates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_templates" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_versions" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_versions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_form_versions" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submission_files" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submission_files" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submission_files" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submissions" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submissions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."registration_submissions" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."reviews" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."reviews" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."reviews" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."sports_booking_idempotency" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."sports_venue_breaks" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sports_venue_breaks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."sports_venue_breaks" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."sports_venue_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."sports_venue_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."sports_venue_profiles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_blocks" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."stay_blocks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_blocks" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_booking_rooms" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."stay_booking_rooms" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_booking_rooms" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_bookings" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."stay_bookings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_bookings" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_physical_rooms" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."stay_physical_rooms" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_physical_rooms" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_rates" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."stay_rates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."stay_rates" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."support_ticket_messages" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."support_ticket_messages" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."support_ticket_messages" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."support_tickets" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."support_tickets" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."support_tickets" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."time_slots" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."time_slots" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."time_slots" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."user_roles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_roles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."user_roles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_blocked_dates" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_blocked_dates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_blocked_dates" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_categories" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_categories" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_categories" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_facilities" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_facilities" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_facilities" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_images" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_images" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_images" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_operating_hours" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_operating_hours" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_operating_hours" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_slot_blocks" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."venue_slot_blocks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."venue_slot_blocks" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."webhook_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."webhook_events" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."webhook_events" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLES TO "service_role";

COMMIT;


