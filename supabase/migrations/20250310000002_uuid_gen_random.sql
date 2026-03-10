-- Fix 42883: uuid_generate_v4() does not exist.
-- Use gen_random_uuid() (built-in in Postgres 13+) so no extension needed.

-- Update refresh_daily_analytics to use gen_random_uuid() (already in 20250310000001 if re-run).
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
  values (gen_random_uuid(), p_date, coalesce(v_total,0), v_busiest_hour, v_most_sport)
  on conflict (date) do update
    set total_bookings = excluded.total_bookings,
        busiest_hour = excluded.busiest_hour,
        most_booked_sport = excluded.most_booked_sport;
end;
$$;

-- Fix table defaults so future inserts don't need uuid-ossp.
alter table public.users   alter column id set default gen_random_uuid();
alter table public.courts  alter column id set default gen_random_uuid();
alter table public.reservations alter column id set default gen_random_uuid();
alter table public.notifications alter column id set default gen_random_uuid();
alter table public.analytics_daily alter column id set default gen_random_uuid();
