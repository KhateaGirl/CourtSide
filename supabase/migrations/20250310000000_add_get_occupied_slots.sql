-- Ensure get_occupied_slots exists for RPC (availability display).
-- Run this in Supabase SQL Editor if you get PGRST202 for get_occupied_slots.

create or replace function public.get_occupied_slots(p_court_id uuid, p_date date)
returns table (start_time time, end_time time)
language sql
stable
security definer
set search_path = public
as $$
  select r.start_time, r.end_time
  from public.reservations r
  where r.court_id = p_court_id
    and r.date = p_date
    and r.status in ('PENDING', 'APPROVED');
$$;

-- Grant execute so PostgREST can call it (anon/authenticated use RPC).
grant execute on function public.get_occupied_slots(uuid, date) to anon;
grant execute on function public.get_occupied_slots(uuid, date) to authenticated;
grant execute on function public.get_occupied_slots(uuid, date) to service_role;
