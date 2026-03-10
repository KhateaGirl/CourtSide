-- Extend notifications with metadata for reservation-related actions (e.g. admin-edited reservation requiring player decision).

alter table public.notifications
  add column if not exists type text,
  add column if not exists reservation_id uuid references public.reservations(id) on delete cascade;

