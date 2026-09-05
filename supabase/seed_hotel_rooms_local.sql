-- Local-only hotel room fixtures. Requires hotel venues and existing venue images.
-- Safe to rerun: deterministic room slugs and upserts only.
do $$
declare
  v record;
  r_id uuid;
  d date;
begin
  for v in
    select v.id, v.name
    from public.venues v
    join public.venue_categories c on c.id = v.category_id
    where v.is_active and c.slug in ('hotel', 'hotel_stay', 'lodge_rooms')
  loop
    insert into public.hotel_room_types
      (venue_id, name, slug, description, capacity, bed_type, quantity, amenities)
    values
      (v.id, 'Deluxe Room', 'deluxe-room', 'Locally seeded room inventory for E2E testing.',
       2, 'King', 1, '["Wi-Fi", "Attached bathroom", "Air conditioning"]'::jsonb)
    on conflict (venue_id, slug) do update set
      name = excluded.name,
      capacity = excluded.capacity,
      bed_type = excluded.bed_type,
      quantity = excluded.quantity,
      amenities = excluded.amenities,
      updated_at = now()
    returning id into r_id;

    if r_id is null then
      select id into r_id from public.hotel_room_types where venue_id = v.id and slug = 'deluxe-room';
    end if;

    insert into public.hotel_room_images (room_type_id, url, alt_text, sort_order)
    select r_id, vi.url, v.name || ' room', 0
    from public.venue_images vi
    where vi.venue_id = v.id and vi.is_cover
      and not exists (select 1 from public.hotel_room_images ri where ri.room_type_id = r_id);

    d := current_date;
    while d < current_date + 90 loop
      insert into public.hotel_room_availability
        (room_type_id, stay_date, available_quantity, price_amount, currency)
      values (r_id, d, 1, 3500, 'INR')
      on conflict (room_type_id, stay_date) do update set
        price_amount = excluded.price_amount,
        currency = excluded.currency,
        updated_at = now();
      d := d + 1;
    end loop;
  end loop;
end $$;
