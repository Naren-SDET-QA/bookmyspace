-- Deterministic DEV-only display promotions. No pricing or booking mutation.
insert into public.promotions (title, short_description, description, active, priority, sort_order, cta_text, cta_action, offer_type, discount_type, discount_value, badge, background_color, text_color)
select 'E2E-PROMO-001', '20% Hotel weekend special', 'Display-only promotion for DEV acceptance.', true, 100, 0, 'Explore hotels', 'category:hotel', 'percentage_discount', 'percentage', 20, 'WEEKEND', '#7C3AED', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-001');
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-002', 'PG admission offer', true, 90, 1, 'View PGs', 'category:gents_pg', 'promotional_text', 'PG', '#0F766E', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-002');
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-003', 'Function Hall celebration package', true, 80, 2, 'View halls', 'category:function_hall', 'promotional_text', 'EVENT', '#B45309', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-003');
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-004', 'Global BookMySpace welcome', true, 70, 3, 'Browse spaces', 'home', 'promotional_text', 'WELCOME', '#1D4ED8', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-004');
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-005', 'Future dated promotion', true, 60, 4, 'Coming soon', 'home', 'promotional_text', 'SOON', '#475569', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-005');
update public.promotions set start_at = now() + interval '30 days' where title='E2E-PROMO-005';
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-006', 'Expired promotion', true, 50, 5, 'Expired', 'home', 'promotional_text', 'ENDED', '#64748B', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-006');
update public.promotions set end_at = now() - interval '1 day' where title='E2E-PROMO-006';
insert into public.promotions (title, short_description, active, priority, sort_order, cta_text, cta_action, offer_type, badge, background_color, text_color)
select 'E2E-PROMO-007', 'Inactive promotion', false, 40, 6, 'Disabled', 'home', 'promotional_text', 'OFF', '#334155', '#FFFFFF'
where not exists (select 1 from public.promotions where title='E2E-PROMO-007');

insert into public.promotion_categories (promotion_id, category_id)
select p.id, c.id from public.promotions p cross join public.venue_categories c
where p.title='E2E-PROMO-001' and lower(c.slug)='hotel'
and not exists (select 1 from public.promotion_categories x where x.promotion_id=p.id and x.category_id=c.id);
insert into public.promotion_categories (promotion_id, category_id)
select p.id, c.id from public.promotions p cross join public.venue_categories c
where p.title='E2E-PROMO-002' and lower(c.slug)='gents_pg'
and not exists (select 1 from public.promotion_categories x where x.promotion_id=p.id and x.category_id=c.id);
insert into public.promotion_categories (promotion_id, category_id)
select p.id, c.id from public.promotions p cross join public.venue_categories c
where p.title='E2E-PROMO-003' and lower(c.slug)='function_hall'
and not exists (select 1 from public.promotion_categories x where x.promotion_id=p.id and x.category_id=c.id);
