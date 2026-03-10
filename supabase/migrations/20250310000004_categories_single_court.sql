-- Categories: one court, bookings per category; when a category books a slot, that date/time is blocked for all categories.

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamp with time zone default timezone('utc', now())
);

alter table public.reservations
  add column if not exists category_id uuid references public.categories(id) on delete set null;

create index if not exists idx_reservations_category_id on public.reservations (category_id);

-- RLS: anyone authenticated can read categories
alter table public.categories enable row level security;

create policy "categories_select_authenticated"
on public.categories for select
using (auth.role() = 'authenticated');

-- Only admin can manage categories (insert/update/delete)
create policy "categories_admin_all"
on public.categories for all
using (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id() and u.role = 'admin'
  )
);

-- Seed default categories (idempotent)
insert into public.categories (id, name)
values
  ('c0000001-0001-4000-8000-000000000001', 'Basketball'),
  ('c0000002-0002-4000-8000-000000000002', 'Volleyball'),
  ('c0000003-0003-4000-8000-000000000003', 'Badminton'),
  ('c0000004-0004-4000-8000-000000000004', 'Multi-purpose')
on conflict (name) do nothing;
