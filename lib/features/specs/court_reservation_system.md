# Court Reservation System — Feature Spec

## Objective

Refine and stabilize the existing Court Reservation App codebase.

The AI must refactor existing code to ensure:

* correct booking validation
* dynamic pricing
* clean architecture
* reliable notifications
* proper role access control

The system must not break existing functionality.

---

# User Roles

player
admin

Default role for new users: player

---

# Core Features

Authentication
Court Listing
Reservation Engine
Dynamic Pricing
Reservation Lifecycle
Notifications
Admin Dashboard
Realtime Updates

---

# Reservation Status

PENDING
APPROVED
REJECTED
CANCELLED

---

# Booking Rules

Reservations must not overlap.

Overlap condition:

start_time < existing_end_time
AND
end_time > existing_start_time

If overlap exists → reject booking.

---

# Pricing Rules

Day Rate
06:00 – 18:00 = 150 per hour

Night Rate
18:00 – 24:00 = 100 per hour

Example:

Booking 17:00–19:00

17–18 = 150
18–19 = 100

Total = 250

Price must be computed dynamically.

---

# Reservation Lifecycle

Players can:

edit pending reservation
cancel pending reservation

Players cannot modify:

approved reservations
cancelled reservations

Admins can:

approve reservations
reject reservations

---

# Notifications

Events generating notifications:

reservation_created
reservation_approved
reservation_rejected
reservation_reminder

Reminder schedule:

24 hours before reservation
1 hour before reservation

Notifications must be stored in database.

---

# Admin Dashboard

Admins can:

view pending reservations
approve or reject bookings
view court schedules
manage courts
view users
view analytics

Dashboard metrics:

reservations_today
pending_reservations
busiest_hour
top_sport

---

# Realtime Behavior

Reservation updates should propagate instantly.

Example:

Admin approves reservation → player UI updates immediately.

Possible implementations:

Supabase Realtime
WebSocket streams

---

# Error Handling

Missing fields → show validation error.

Invalid time range → show:

Start time must be before end time.

Offline mode must show network error and prevent crashes.

---

# Access Control

Players must not access admin routes.

Database must enforce role-based access control.

Use Row Level Security where applicable.

---

# Implementation Strategy

When modifying code:

1. Inspect existing implementation.
2. Refactor services instead of rewriting.
3. Move business logic into service classes.
4. Keep UI components thin.
5. Enforce validation at backend level.
