-- Overlap check for reschedule: exclude current reservation so editing doesn't conflict with self.
-- Drop the 4-param version so PostgREST has a single candidate (no overloading).

drop function if exists public.check_reservation_overlap(uuid, date, time, time);

create or replace function public.check_reservation_overlap(
  p_court_id uuid,
  p_date date,
  p_start time,
  p_end time,
  p_exclude_reservation_id uuid default null
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
      and (p_exclude_reservation_id is null or r.id != p_exclude_reservation_id)
  ) into v_exists;

  return not v_exists;
end;
$$;
