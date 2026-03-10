-- Fix RLS: allow trigger to update analytics_daily (fixes 42501 on reservation delete)
-- and allow users to insert their own profile on signup.

-- refresh_daily_analytics is called by trigger on reservations INSERT/UPDATE/DELETE.
-- It writes to analytics_daily; without SECURITY DEFINER the invoker (e.g. player) hits RLS.
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

-- Allow authenticated user to insert their own profile row (signup flow).
drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users for insert
with check (id = public.current_user_id());
