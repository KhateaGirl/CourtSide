-- Remove 4-param overload so PostgREST has a single check_reservation_overlap candidate (fix PGRST203).

drop function if exists public.check_reservation_overlap(uuid, date, time, time);
