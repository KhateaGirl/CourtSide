-- Allow admin to insert into notifications (e.g. when admin edits a user's reservation).
-- Without this, only the player can insert their own row (notifications_player_insert_own).

drop policy if exists "notifications_admin_insert" on public.notifications;

create policy "notifications_admin_insert"
on public.notifications for insert
with check (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and u.role = 'admin'
  )
);
