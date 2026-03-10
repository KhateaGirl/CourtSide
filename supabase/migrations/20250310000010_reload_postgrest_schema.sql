-- Reload PostgREST schema cache so it picks up check_reservation_overlap(p_court_id, p_date, p_start, p_end, p_exclude_reservation_id).
-- Run this after 20250310000007 and 20250310000008 so RPC calls stop returning 400.

notify pgrst, 'reload schema';
