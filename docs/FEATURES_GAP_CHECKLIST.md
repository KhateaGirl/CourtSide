# CourtSide — Features / Functionality Gap Checklist

Cross-check of the app against your user stories. **Done** = implemented; **Missing** or **Partial** = not done or only partly done.

---

## I. CUSTOMER / PLAYER

### 1. User Registration & Login
| Criterion | Status | Notes |
|----------|--------|-------|
| Register with name, email, contact number, password | **Done** | `register_screen.dart` + `auth_repository.signUp` |
| System rejects duplicate emails | **Done** | DB unique on `users.email`; UI shows "This email is already registered" |
| Users receive confirmation that account is created | **Done** | SnackBar "Account created successfully. You can now sign in." + redirect to home |

### 2. View Real-Time Court Availability
| Criterion | Status | Notes |
|----------|--------|-------|
| Calendar shows only available time slots | **Done** | Calendar + time dropdowns built from `get_occupied_slots` (only free slots) |
| Occupied slots marked as unavailable | **Done** | Availability chips + dropdowns exclude occupied slots |
| System updates instantly after a booking | **Done** | Realtime subscription invalidates `occupiedSlotsProvider` |

### 3. Make a Court Reservation
| Criterion | Status | Notes |
|----------|--------|-------|
| Form: date, time slot, event type, number of players | **Done** | Category, date, time (start/end), event type, players |
| System prevents double booking | **Done** | `check_reservation_overlap` before insert + validation in UI |
| User receives confirmation notification after submission | **Done** | In-app notification "Your reservation is pending approval" (or admin message for ADMIN) |

### 4. Modify/Cancel a Reservation
| Criterion | Status | Notes |
|----------|--------|-------|
| Users can edit reservation details **before** admin approval | **Done** | Edit button for PENDING; `updateReservation` in repo |
| **After approval, changes require new approval** | **Missing** | Currently no way to “request changes” on an APPROVED booking (e.g. reschedule and send back to PENDING). Only cancel or new booking. |
| Users receive updated confirmation | **Partial** | In-app notification on approve/reject; no in-app “reservation updated” when user edits (could add). |

### 5. Booking Status Tracking
| Criterion | Status | Notes |
|----------|--------|-------|
| Status changes appear in real time | **Done** | Realtime on `reservations` + provider invalidation |
| **Users receive email notification when status updates** | **Missing** | Only in-app notifications; no email sent on approve/reject. |

### 6. Receive Reminders
| Criterion | Status | Notes |
|----------|--------|-------|
| Reminders sent **24 hours** and **1 hour** before the session | **Partial** | `send_reminder` Edge Function exists and creates in-app notifications for 1h and 24h before; **no cron/scheduler** to run it automatically. |
| Includes date, time, and booking notes | **Partial** | Message includes time; could add date and event type/notes. |

### 7. View Booking History
| Criterion | Status | Notes |
|----------|--------|-------|
| User can see past reservations | **Done** | “My Reservations” lists all (order by date desc); filter by status (All, Pending, Approved, Rejected, Cancelled, Admin). |

---

## II. GYM ADMIN / STAFF

### 8. Approve or Reject Bookings
| Criterion | Status | Notes |
|----------|--------|-------|
| Admin sees list of Pending bookings | **Done** | Admin → Pending reservations |
| Admin can approve or reject | **Done** | Approve / Reject buttons; no edit for player PENDING. |
| **Admin can … request changes** | **Missing** | No “request changes” flow (e.g. message to user or send back to draft). |
| Users receive notifications instantly | **Done** | In-app notification on approve/reject. |

### 9. View Daily/Weekly Court Schedule
| Criterion | Status | Notes |
|----------|--------|-------|
| **Calendar view** shows all reservations | **Partial** | Schedule is **list by date** (date picker + event type filter), not a full calendar grid. |
| Different colors for Pending, Approved, Cancelled | **Done** | Schedule list uses `_statusColor` (PENDING, APPROVED, CANCELLED/REJECTED, ADMIN). |
| Filters by date and event type | **Done** | Date picker + event type dropdown. |

### 10. Edit Reservation Details
| Criterion | Status | Notes |
|----------|--------|-------|
| Admin can adjust times / move reservations | **Partial** | Admin can edit **only ADMIN-status** reservations (Admin → Admin reservations). Cannot edit player PENDING/APPROVED from admin. |

### 11. Manage User Information
| Criterion | Status | Notes |
|----------|--------|-------|
| Admin can view and update user account details | **Done** | Admin → Users; edit name/contact (and role if needed). |

### 12. View Usage Reports (Basic Analytics)
| Criterion | Status | Notes |
|----------|--------|-------|
| Most booked hours, busiest days | **Done** | Dashboard: busiest hour, most booked sport, busiest days (from `analytics_daily`). |

---

## III. SYSTEM / AUTOMATION

### 17. Prevent Double Booking
| Criterion | Status | Notes |
|----------|--------|-------|
| Lock timeslot when a booking is made | **Done** | `check_reservation_overlap` + `get_occupied_slots` include PENDING, APPROVED, ADMIN; UI blocks double booking. |

---

## PRICING & CATEGORIES

| Item | Status | Notes |
|------|--------|-------|
| **100 – night, 150 – day** | **Done** | `calculate_booking_price`: night 100, day 150 (schema/migration). |
| **Categorized sports (e.g. Volleyball, Basketball, Rent)** | **Done** | Categories table + Admin → Categories; player picks category; “Rent” can be added as a category. |

---

## SUMMARY — NOT DONE / PARTIAL

1. **Email notification when status updates (approve/reject)** — not implemented; in-app only.
2. **Reminders 24h / 1h** — logic exists in `send_reminder`; **no cron/scheduler** to run it (e.g. Supabase cron or external cron hitting the function).
3. **“After approval, changes require new approval”** — no flow to reschedule an approved booking and send it back to PENDING for re-approval.
4. **Admin “request changes”** — no request-changes action for pending bookings.
5. **Admin schedule: full calendar view** — currently list-by-date with filters; not a calendar grid showing all reservations.
6. **Admin edit any reservation** — admin can only edit ADMIN-status reservations; cannot edit player PENDING/APPROVED from admin UI (by design from earlier story).
7. **Reminder content** — could add date and booking notes to the reminder message.

---

## SUGGESTED NEXT STEPS (PRIORITY)

1. **Cron for reminders** — e.g. Supabase cron or Vercel cron to call `send_reminder` every hour (or every 15 min) so 1h and 24h reminders run automatically.
2. **Email on status change** — use Supabase Auth (if using email) or a small Edge Function that sends email (e.g. Resend/SendGrid) when a notification is inserted for approve/reject.
3. **“Request changes” (admin)** — e.g. button that keeps status PENDING and sends an in-app (and optionally email) message to the user.
4. **Reschedule approved booking** — e.g. “Request change” that sets booking back to PENDING and notifies admin for re-approval.
5. **Schedule calendar view** — optional: add a calendar widget for admin that shows all reservations by day with status colors.
