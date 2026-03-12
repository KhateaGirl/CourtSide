-- Reservation Change Request System
-- Admin proposes time change; player must Accept or Reject. No direct reservation update.

create table if not exists public.reservation_change_requests (
  id uuid not null default gen_random_uuid(),
  reservation_id uuid not null,
  player_id uuid not null,
  admin_id uuid not null,
  old_start_time time without time zone not null,
  old_end_time time without time zone not null,
  new_start_time time without time zone not null,
  new_end_time time without time zone not null,
  message text,
  status text not null check (status in ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED')),
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  constraint reservation_change_requests_pkey primary key (id),
  constraint reservation_change_requests_reservation_id_fkey foreign key (reservation_id) references public.reservations(id) on delete cascade,
  constraint reservation_change_requests_player_id_fkey foreign key (player_id) references public.users(id),
  constraint reservation_change_requests_admin_id_fkey foreign key (admin_id) references public.users(id)
);

-- Only one PENDING change request per reservation (lock rule).
create unique index reservation_change_requests_one_pending_per_reservation
  on public.reservation_change_requests (reservation_id)
  where (status = 'PENDING');

create index reservation_change_requests_reservation_status on public.reservation_change_requests (reservation_id, status);
create index reservation_change_requests_player_id on public.reservation_change_requests (player_id);
create index reservation_change_requests_expires_at on public.reservation_change_requests (expires_at) where (status = 'PENDING');

-- Link notifications to change request for Accept/Reject UI.
alter table public.notifications
  add column if not exists change_request_id uuid references public.reservation_change_requests(id) on delete set null;

-- Court name for change-request notifications (avoid extra join when displaying).
alter table public.notifications
  add column if not exists court_name text;

-- RLS
alter table public.reservation_change_requests enable row level security;

-- Admin can insert (create change request).
create policy "reservation_change_requests_admin_insert"
  on public.reservation_change_requests for insert
  with check (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- Player sees own requests; admin sees all.
create policy "reservation_change_requests_select"
  on public.reservation_change_requests for select
  using (
    player_id = auth.uid()
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );

-- Player can update only own PENDING (to ACCEPTED/REJECTED).
create policy "reservation_change_requests_player_update"
  on public.reservation_change_requests for update
  using (player_id = auth.uid() and status = 'PENDING')
  with check (player_id = auth.uid());

-- Admin can update (e.g. for manual expire or support).
create policy "reservation_change_requests_admin_update"
  on public.reservation_change_requests for update
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );
