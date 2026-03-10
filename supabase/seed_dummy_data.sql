-- CourtSide dummy data for PostgreSQL/Supabase
-- Run after schema.sql. Order respects foreign keys.

-- ─── Users (1 admin, 3 players) ─────────────────────────────────────────────
insert into public.users (id, name, email, contact_number, role)
values
  ('a0000001-0001-4000-8000-000000000001', 'Admin User', 'admin@courtside.app', '+639171234567', 'admin'),
  ('a0000002-0002-4000-8000-000000000002', 'Juan Dela Cruz', 'juan@example.com', '+639181234567', 'player'),
  ('a0000003-0003-4000-8000-000000000003', 'Maria Santos', 'maria@example.com', '+639191234567', 'player'),
  ('a0000004-0004-4000-8000-000000000004', 'Pedro Reyes', 'pedro@example.com', '+639201234567', 'player')
on conflict (email) do nothing;

-- ─── Courts ─────────────────────────────────────────────────────────────────
insert into public.courts (id, name, sport_type, description)
values
  ('b0000001-0001-4000-8000-000000000001', 'Main Basketball Court', 'Basketball', 'Indoor court with wooden floor, FIBA standard.'),
  ('b0000002-0002-4000-8000-000000000002', 'Outdoor Court A', 'Basketball', 'Outdoor concrete, 3x3 and 5x5.'),
  ('b0000003-0003-4000-8000-000000000003', 'Volleyball Court 1', 'Volleyball', 'Indoor, net and lines.'),
  ('b0000004-0004-4000-8000-000000000004', 'Multi-Purpose Court', 'Basketball', 'Can be set for basketball or volleyball.')
on conflict (id) do nothing;

-- ─── Reservations (varied statuses and dates) ─────────────────────────────────
insert into public.reservations (user_id, court_id, event_type, players_count, date, start_time, end_time, status, price)
values
  -- Juan
  ('a0000002-0002-4000-8000-000000000002', 'b0000001-0001-4000-8000-000000000001', 'Pickup game', 10, current_date + 1, '09:00', '11:00', 'APPROVED', 300.00),
  ('a0000002-0002-4000-8000-000000000002', 'b0000002-0002-4000-8000-000000000002', 'Practice', 6, current_date + 2, '14:00', '15:00', 'PENDING', 150.00),
  ('a0000002-0002-4000-8000-000000000002', 'b0000001-0001-4000-8000-000000000001', 'League', 12, current_date - 2, '18:00', '20:00', 'APPROVED', 200.00),
  -- Maria
  ('a0000003-0003-4000-8000-000000000003', 'b0000003-0003-4000-8000-000000000003', 'Volleyball training', 12, current_date, '08:00', '10:00', 'APPROVED', 300.00),
  ('a0000003-0003-4000-8000-000000000003', 'b0000004-0004-4000-8000-000000000004', 'Mixed sports', 8, current_date + 3, '16:00', '18:00', 'PENDING', 300.00),
  ('a0000003-0003-4000-8000-000000000003', 'b0000003-0003-4000-8000-000000000003', 'Beach volley style', 10, current_date - 5, '10:00', '12:00', 'REJECTED', 300.00),
  -- Pedro
  ('a0000004-0004-4000-8000-000000000004', 'b0000002-0002-4000-8000-000000000002', '3x3 Tournament', 6, current_date + 1, '13:00', '15:00', 'APPROVED', 150.00),
  ('a0000004-0004-4000-8000-000000000004', 'b0000001-0001-4000-8000-000000000001', 'Casual play', 4, current_date - 1, '19:00', '20:00', 'CANCELLED', 100.00);

-- ─── Notifications ─────────────────────────────────────────────────────────
insert into public.notifications (user_id, title, message, is_read)
values
  ('a0000002-0002-4000-8000-000000000002', 'Reservation approved', 'Your booking for Main Basketball Court on ' || to_char(current_date + 1, 'FMDD Mon') || ' 09:00–11:00 has been approved.', false),
  ('a0000002-0002-4000-8000-000000000002', 'Reminder', 'Upcoming: Main Basketball Court tomorrow 09:00.', false),
  ('a0000003-0003-4000-8000-000000000003', 'Reservation approved', 'Volleyball Court 1 – ' || to_char(current_date, 'FMDD Mon') || ' 08:00–10:00 approved.', true),
  ('a0000004-0004-4000-8000-000000000004', 'Reservation approved', 'Outdoor Court A – 3x3 Tournament approved.', false);

-- ─── Analytics (optional; trigger also updates from reservations) ─────────────
insert into public.analytics_daily (date, total_bookings, busiest_hour, most_booked_sport)
values
  (current_date, 2, 8, 'Volleyball'),
  (current_date - 1, 1, 19, 'Basketball'),
  (current_date - 2, 1, 18, 'Basketball'),
  (current_date - 7, 3, 14, 'Basketball')
on conflict (date) do update set
  total_bookings = excluded.total_bookings,
  busiest_hour = excluded.busiest_hour,
  most_booked_sport = excluded.most_booked_sport;
