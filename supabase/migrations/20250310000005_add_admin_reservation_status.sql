-- Admin-created reservations use status 'ADMIN'; they block the slot and admin can edit them.

-- 1) Allow status 'ADMIN' in reservations
alter table public.reservations
  drop constraint if exists reservations_status_check;

alter table public.reservations
  add constraint reservations_status_check
  check (status in ('PENDING','APPROVED','REJECTED','CANCELLED','ADMIN'));

-- 2) Overlap and occupied slots include ADMIN (admin reservations block the slot)
create or replace function public.check_reservation_overlap(
  p_court_id uuid,
  p_date date,
  p_start time,
  p_end time
) returns boolean
language plpgsql
security definer
set search_path = public
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
      and r.status in ('PENDING','APPROVED','ADMIN')
      and (p_start < r.end_time and p_end > r.start_time)
  ) into v_exists;

  return not v_exists;
end;
$$;

create or replace function public.get_occupied_slots(p_court_id uuid, p_date date)
returns table (start_time time, end_time time)
language sql stable security definer
set search_path = public
as $$
  select r.start_time, r.end_time
  from public.reservations r
  where r.court_id = p_court_id and r.date = p_date
    and r.status in ('PENDING','APPROVED','ADMIN');
$$;

-- 3) Analytics count ADMIN as a booking
create or replace function public.refresh_daily_analytics(p_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total integer;
  v_busiest_hour integer;
  v_most_sport text;
begin
  select count(*) into v_total
  from public.reservations
  where date = p_date
    and status in ('APPROVED','PENDING','ADMIN');

  select extract(hour from start_time)::integer
  from public.reservations
  where date = p_date
    and status in ('APPROVED','PENDING','ADMIN')
  group by 1
  order by count(*) desc
  limit 1
  into v_busiest_hour;

  select c.sport_type
  from public.reservations r
  join public.courts c on c.id = r.court_id
  where r.date = p_date
    and r.status in ('APPROVED','PENDING','ADMIN')
  group by c.sport_type
  order by count(*) desc
  limit 1
  into v_most_sport;

  insert into public.analytics_daily (id, date, total_bookings, busiest_hour, most_booked_sport)
  values (gen_random_uuid(), p_date, coalesce(v_total,0), v_busiest_hour, v_most_sport)
  on conflict (date) do update
    set total_bookings = excluded.total_bookings,
        busiest_hour = excluded.busiest_hour,
        most_booked_sport = excluded.most_booked_sport;
end;
$$;

-- 4) RLS: allow admin to update reservations with status ADMIN (for editing admin-created ones)
-- reservations_admin_manage already grants admin "for all", so admin can already update any row.
-- No change needed for RLS.
