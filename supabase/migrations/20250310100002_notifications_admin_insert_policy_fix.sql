-- Fix notifications admin insert: allow when current user is admin (role case-insensitive).
-- Ensures notification inserts work when admin approves/rejects or creates change requests.

drop policy if exists "notifications_admin_insert" on public.notifications;

create policy "notifications_admin_insert"
on public.notifications for insert
with check (
  exists (
    select 1 from public.users u
    where u.id = auth.uid()
      and lower(trim(u.role)) = 'admin'
  )
);
