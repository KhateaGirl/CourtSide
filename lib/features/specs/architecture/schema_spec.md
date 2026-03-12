# Database Schema Specification

---

# Users Table

users

id
name
email
contact
password_hash
role
created_at

role values:

player
admin

---

# Courts Table

courts

court_id
name
sport_type
hourly_rate_day
hourly_rate_night
created_at

---

# Reservations Table

reservations

reservation_id
court_id
user_id
start_time
end_time
players_count
event_name
price_total
status
created_at

status values:

PENDING
APPROVED
REJECTED
CANCELLED

---

# Notifications Table

notifications

notification_id
user_id
title
message
is_read
created_at

---

# Booking Validation Rule

Reservations must not overlap.

Rule:

start_time < existing_end_time
AND
end_time > existing_start_time

---

# Pricing Rules

Day Rate:

06:00 – 18:00

Night Rate:

18:00 – 24:00

Price must be calculated based on time segments.
