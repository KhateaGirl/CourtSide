-- Allow reservation owner to reschedule an APPROVED booking: update details and set status back to PENDING for new admin approval.

-- Player can update their own reservation when it is APPROVED (e.g. to reschedule).
-- The app will set status = 'PENDING' so admin must re-approve.
create policy "reservations_player_update_own_approved"
on public.reservations for update
using (
  user_id = public.current_user_id()
  and status = 'APPROVED'
)
with check (
  user_id = public.current_user_id()
);
