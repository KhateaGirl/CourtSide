-- Allow create_reservation to be done from the app (no Edge Function).
-- 1) check_reservation_overlap must see all reservations for the court/date → SECURITY DEFINER
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
      and r.status in ('PENDING','APPROVED')
      and (p_start < r.end_time and p_end > r.start_time)
  ) into v_exists;

  return not v_exists;
end;
$$;

-- 2) calculate_booking_price: set search_path for consistency (no sensitive data)
create or replace function public.calculate_booking_price(
  p_date date,
  p_start time,
  p_end time
) returns numeric
language plpgsql
security definer
set search_path = public
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

-- 3) Let players insert their own notification (e.g. "Reservation created")
create policy "notifications_player_insert_own"
on public.notifications for insert
with check (user_id = public.current_user_id());
