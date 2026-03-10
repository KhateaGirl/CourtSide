create extension if not exists "uuid-ossp";

create table if not exists public.users (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  email text unique not null,
  contact_number text,
  role text not null check (role in ('player','admin')),
  fcm_token text,
  created_at timestamp with time zone default timezone('utc', now())
);

create table if not exists public.courts (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  sport_type text not null,
  description text,
  created_at timestamp with time zone default timezone('utc', now())
);

create table if not exists public.reservations (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  court_id uuid not null references public.courts(id) on delete cascade,
  event_type text not null,
  players_count integer not null check (players_count > 0),
  date date not null,
  start_time time not null,
  end_time time not null,
  status text not null check (status in ('PENDING','APPROVED','REJECTED','CANCELLED')),
  price numeric(10,2) not null default 0,
  created_at timestamp with time zone default timezone('utc', now())
);

create index if not exists idx_reservations_court_date
  on public.reservations (court_id, date, start_time, end_time);

create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamp with time zone default timezone('utc', now())
);

create table if not exists public.analytics_daily (
  id uuid primary key default uuid_generate_v4(),
  date date not null unique,
  total_bookings integer not null default 0,
  busiest_hour integer,
  most_booked_sport text
);

create or replace function public.check_reservation_overlap(
  p_court_id uuid,
  p_date date,
  p_start time,
  p_end time
) returns boolean
language plpgsql
as $$
declare
  v_exists boolean;
begin
  if p_start >= p_end then
    raise exception 'Start time must be before end time';
  end if;

  select exists (
    select 1
    from public.reservations r
    where r.court_id = p_court_id
      and r.date = p_date
      and r.status in ('PENDING','APPROVED')
      and (p_start < r.end_time and p_end > r.start_time)
  ) into v_exists;

  return not v_exists;
end;
$$;

-- Returns occupied time ranges for a court/date (for availability display). Security definer so players can see slots without seeing who booked.
create or replace function public.get_occupied_slots(p_court_id uuid, p_date date)
returns table (start_time time, end_time time)
language sql stable security definer
set search_path = public
as $$
  select r.start_time, r.end_time
  from public.reservations r
  where r.court_id = p_court_id and r.date = p_date
    and r.status in ('PENDING','APPROVED');
$$;

create or replace function public.calculate_booking_price(
  p_date date,
  p_start time,
  p_end time
) returns numeric
language plpgsql
as $$
declare
  v_total_minutes integer;
  v_day_minutes integer := 0;
  v_night_minutes integer := 0;
  v_cursor timestamp;
  v_end_ts timestamp;
  v_day_rate numeric := 150;
  v_night_rate numeric := 100;
  v_price numeric;
begin
  if p_start >= p_end then
    raise exception 'Start time must be before end time';
  end if;

  v_cursor := (p_date::timestamp + p_start);
  v_end_ts := (p_date::timestamp + p_end);
  v_total_minutes := extract(epoch from (v_end_ts - v_cursor)) / 60;

  while v_cursor < v_end_ts loop
    if (extract(hour from v_cursor) >= 6 and extract(hour from v_cursor) < 18) then
      v_day_minutes := v_day_minutes + 1;
    else
      v_night_minutes := v_night_minutes + 1;
    end if;
    v_cursor := v_cursor + interval '1 minute';
  end loop;

  if v_total_minutes = 0 then
    return 0;
  end if;

  v_price :=
    (v_day_minutes::numeric / 60.0) * v_day_rate +
    (v_night_minutes::numeric / 60.0) * v_night_rate;

  return round(v_price::numeric, 2);
end;
$$;

create or replace function public.refresh_daily_analytics(p_date date)
returns void
language plpgsql
as $$
declare
  v_total integer;
  v_busiest_hour integer;
  v_most_sport text;
begin
  select count(*) into v_total
  from public.reservations
  where date = p_date
    and status in ('APPROVED','PENDING');

  select extract(hour from start_time)::integer
  from public.reservations
  where date = p_date
    and status in ('APPROVED','PENDING')
  group by 1
  order by count(*) desc
  limit 1
  into v_busiest_hour;

  select c.sport_type
  from public.reservations r
  join public.courts c on c.id = r.court_id
  where r.date = p_date
    and r.status in ('APPROVED','PENDING')
  group by c.sport_type
  order by count(*) desc
  limit 1
  into v_most_sport;

  insert into public.analytics_daily (id, date, total_bookings, busiest_hour, most_booked_sport)
  values (uuid_generate_v4(), p_date, coalesce(v_total,0), v_busiest_hour, v_most_sport)
  on conflict (date) do update
    set total_bookings = excluded.total_bookings,
        busiest_hour = excluded.busiest_hour,
        most_booked_sport = excluded.most_booked_sport;
end;
$$;

create or replace function public.trg_reservations_analytics()
returns trigger
language plpgsql
as $$
begin
  perform public.refresh_daily_analytics(coalesce(NEW.date, OLD.date));
  return NEW;
end;
$$;

drop trigger if exists reservations_analytics_trg on public.reservations;

create trigger reservations_analytics_trg
after insert or update or delete on public.reservations
for each row execute function public.trg_reservations_analytics();

alter table public.users enable row level security;
alter table public.courts enable row level security;
alter table public.reservations enable row level security;
alter table public.notifications enable row level security;
alter table public.analytics_daily enable row level security;

create or replace function public.current_user_id()
returns uuid
language sql stable
as $$
  select auth.uid();
$$;

create policy "users_select_own_or_admin"
on public.users for select
using (
  id = public.current_user_id()
  or exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

create policy "users_update_self"
on public.users for update
using (id = public.current_user_id());

create policy "courts_select_all"
on public.courts for select
using (true);

create policy "courts_admin_manage"
on public.courts for all
using (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

create policy "reservations_player_select_own"
on public.reservations for select
using (
  user_id = public.current_user_id()
  or exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

create policy "reservations_player_insert"
on public.reservations for insert
with check (user_id = public.current_user_id());

create policy "reservations_player_update_own_pending"
on public.reservations for update
using (
  user_id = public.current_user_id()
  and status = 'PENDING'
)
with check (
  user_id = public.current_user_id()
);

create policy "reservations_admin_manage"
on public.reservations for all
using (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

create policy "notifications_player_select_own"
on public.notifications for select
using (user_id = public.current_user_id());

create policy "notifications_player_update_own"
on public.notifications for update
using (user_id = public.current_user_id());

create policy "notifications_admin_insert"
on public.notifications for insert
with check (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

create policy "analytics_admin_read"
on public.analytics_daily for select
using (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);

