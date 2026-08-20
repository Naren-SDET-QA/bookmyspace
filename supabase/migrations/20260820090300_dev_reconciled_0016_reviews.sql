-- DEV reconciliation for 0016. Reviews already exist from 0006.

alter table public.reviews alter column booking_id drop not null;
alter table public.reviews drop constraint if exists reviews_booking_id_fkey;
alter table public.reviews drop constraint if exists reviews_booking_id_key;
alter table public.reviews add constraint reviews_booking_id_fkey
  foreign key (booking_id) references public.bookings(id) on delete set null;
alter table public.reviews add constraint reviews_venue_user_key unique (venue_id, user_id);

alter table public.reviews add column if not exists owner_reply text;
alter table public.reviews add column if not exists owner_replied_at timestamptz;

create index if not exists idx_reviews_venue_id on public.reviews(venue_id);
create index if not exists idx_reviews_user_id on public.reviews(user_id);

drop policy if exists reviews_public_read on public.reviews;
drop policy if exists reviews_insert_own on public.reviews;
drop policy if exists reviews_update_own on public.reviews;
drop policy if exists "Reviews are publicly readable" on public.reviews;
drop policy if exists "Authenticated users can insert reviews" on public.reviews;
drop policy if exists "Users can update their own reviews" on public.reviews;
drop policy if exists "Users can delete their own reviews" on public.reviews;
create policy dev_reviews_public_read on public.reviews for select using (true);
create policy dev_reviews_insert_own on public.reviews for insert
  with check (auth.uid() = user_id);
create policy dev_reviews_update_own on public.reviews for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy dev_reviews_delete_own on public.reviews for delete
  using (auth.uid() = user_id);

create or replace function public.update_venue_rating(p_venue_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update public.venues set
    avg_rating = coalesce((select avg(r.rating)::numeric(3,2) from public.reviews r where r.venue_id = p_venue_id), 0),
    rating_count = (select count(*)::integer from public.reviews r where r.venue_id = p_venue_id),
    updated_at = now()
  where id = p_venue_id;
end $$;

create or replace function public.reviews_rating_trigger()
returns trigger language plpgsql
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then perform public.update_venue_rating(new.venue_id); end if;
  if tg_op = 'DELETE' then perform public.update_venue_rating(old.venue_id); end if;
  return null;
end $$;

drop trigger if exists reviews_rating_changes on public.reviews;
create trigger reviews_rating_changes after insert or update or delete on public.reviews
  for each row execute function public.reviews_rating_trigger();
