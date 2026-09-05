-- Android ReviewEntity stores selected quick-feedback tags as CSV text.
alter table public.reviews
  add column if not exists tags text not null default '';
